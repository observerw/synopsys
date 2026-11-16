#!/usr/bin/env bash
#
# Compile Design Compiler .db views for the typical (TT) corner of every
# Liberty library in a PDK store tree, in place:
#
#   <variant>/libs.ref/<library>/lib/<name>.lib          CIEL families
#
# Kept separate from ASAP7/compile_db.sh on purpose: this script runs in the
# ciel job, which mounts only ciel/ at /work, and CIEL lays Liberty out under
# libs.ref/*/lib.  The core loop is the same, but the layout and the mounted
# context are not.
#
# The .db lands in a `db/` directory next to the `lib/` directory that holds
# the Liberty file.
#
# Run it in the lc image (it needs lc_shell and a Library-Compiler license):
#
#   compile_db.sh /pdk [jobs]
#
# lc_shell X-2025.06 writes the .db and then segfaults on exit in this image;
# that is why success is decided by the output file, not the exit status.
set -uo pipefail
ulimit -c 0

PDK_ROOT=${1:-/pdk}
JOBS=${2:-${JOBS:-8}}
WORK=${WORK:-/tmp/compile-db}
FAILURES="$WORK/failures.txt"

mkdir -p "$WORK"
: > "$FAILURES"

mapfile -t LIBS < <(
    find "$PDK_ROOT" -type f \
        \( -path '*/libs.ref/*/lib/*.lib' \
           \( -name '*tt_*' -o -name '*_typ*' -o -name '*typical*' \
              -o -path '*/fakeram45/*' \) \
           ! -path '*/lctime_templates/*' \) | sort
)
echo "compile_db: ${#LIBS[@]} typical-corner Liberty files under $PDK_ROOT, jobs=$JOBS"

compile_one() {
    local lib=$1
    local dir out base name db tmp rc
    dir=$(dirname "$lib")
    out=$(dirname "$dir")/db
    base=$(basename "$lib" .lib)
    db="$out/$base.db"

    if [ -s "$db" ]; then
        return 0
    fi
    mkdir -p "$out"

    name=$(sed -n 's/^[[:space:]]*library[[:space:]]*([[:space:]]*"\{0,1\}\([^")]*\)"\{0,1\}[[:space:]]*).*/\1/p' "$lib" | head -1)
    if [ -z "$name" ]; then
        echo "NO-LIBRARY-NAME $lib" >> "$FAILURES"
        return 1
    fi

    tmp=$(mktemp -d "$WORK/run.XXXXXX")
    (
        cd "$tmp" || exit 1
        lc_shell -x "read_lib $lib; write_lib $name -format db -output $db; exit"
    ) >"$tmp/lc.log" 2>&1
    rc=$?

    # Newer open_pdks Liberty files use constructs LC X-2025.06 rejects:
    #  - related_{ground,power}_pin on pins (LBDB-27)
    #  - related_bus_pins on internal_power, which LC only accepts as related_pin
    #  - process_corner/default_(constraint_)arc_mode in the wrong scope (LBDB-76)
    # Retry once from a sanitized copy; the original .lib stays untouched.
    if [ ! -s "$db" ]; then
        grep -v -E '^[[:space:]]*(related_(ground|power)_pin|process_corner|default_arc_mode|default_constraint_arc_mode)[[:space:]]*:' "$lib" \
            | sed -E 's/related_bus_pins([[:space:]]*):([[:space:]]*)"([^"]*)";/related_pin\1:\2"\3[0]";/' \
            > "$tmp/sanitized.lib"
        if [ -s "$tmp/sanitized.lib" ]; then
            (
                cd "$tmp" || exit 1
                lc_shell -x "read_lib $tmp/sanitized.lib; write_lib $name -format db -output $db; exit"
            ) >>"$tmp/lc.log" 2>&1
            rc=$?
            [ -s "$db" ] && echo "ok-sanitized $lib" >> "$WORK/sanitized.txt"
        fi
    fi

    # Some libraries name an `output_voltage` supply group LC does not derive
    # (LBDB-235). The pg_pin and voltage_map entries carry the same supply
    # information, so retry from a copy without that single attribute.
    if [ ! -s "$db" ]; then
        grep -v -E '^[[:space:]]*output_voltage[[:space:]]*:' "$lib" > "$tmp/no-output-voltage.lib"
        if [ -s "$tmp/no-output-voltage.lib" ]; then
            (
                cd "$tmp" || exit 1
                lc_shell -x "read_lib $tmp/no-output-voltage.lib; write_lib $name -format db -output $db; exit"
            ) >>"$tmp/lc.log" 2>&1
            rc=$?
            [ -s "$db" ] && echo "ok-no-output-voltage $lib" >> "$WORK/sanitized.txt"
        fi
    fi

    cp "$tmp/lc.log" "$WORK/$base.log"
    rm -rf "$tmp"

    if [ -s "$db" ]; then
        [ "$rc" -eq 0 ] || echo "ok-with-rc=$rc $lib" >> "$WORK/segfaults.txt"
        return 0
    fi
    rm -f "$db"
    echo "FAILED rc=$rc $lib (see $WORK/$base.log)" >> "$FAILURES"
    return 1
}
export -f compile_one
export PDK_ROOT WORK FAILURES

printf '%s\n' "${LIBS[@]}" | xargs -d '\n' -P "$JOBS" -I{} \
    bash -c 'compile_one "$1"' _ {}

fail=$(wc -l < "$FAILURES")
db=$(find "$PDK_ROOT" -path '*/db/*.db' | wc -l)
echo "compile_db: done, $db .db files in the tree, $fail failures"
[ "$fail" -eq 0 ] || cat "$FAILURES"
