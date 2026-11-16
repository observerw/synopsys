#!/bin/sh
# Start probe for Library Compiler, packaged at /opt/eda-smoke/smoke.sh.
# Re-run against a finished image:
#   nerdctl run --rm --entrypoint /opt/eda-smoke/smoke.sh \
#       local.io/synopsys/lc:2025.06
set -eu

: "${SNPSLMD_LICENSE_FILE:=2700@license.synopsys.svc.cluster.local}"
: "${LM_LICENSE_FILE:=$SNPSLMD_LICENSE_FILE}"
export SNPSLMD_LICENSE_FILE LM_LICENSE_FILE EDA_SMOKE_TOOL=lc

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM

cat >"$work/smoke.tcl" <<'TCL'
set tool "(unknown)"
if {[info exists ::env(EDA_SMOKE_TOOL)]} {
    set tool $::env(EDA_SMOKE_TOOL)
}
puts "EDA_SMOKE_OK tool=$tool tcl=[info patchlevel]"
if {$tool == "spyglass"} {
    exit -force
}
exit
TCL

cd "$work"
log=$work/smoke.log
rc=0
HOME=$work TMPDIR=$work timeout -k 30 300 \
    lc_shell -f "$work/smoke.tcl" >"$log" 2>&1 || rc=$?
cat "$log"

grep -q EDA_SMOKE_OK "$log" || {
    echo "EDA_SMOKE_FAIL: lc did not reach the Tcl probe (exit ${rc})" >&2
    exit 1
}
if [ "$rc" -ne 0 ]; then
    # lc_shell X-2025.06 segfaults while exiting, after the Tcl script has
    # finished; 134/139 are acceptable only after the marker above has been
    # printed.
    case "$rc" in
    134|139)
        echo "EDA_SMOKE_OK: lc (exited ${rc} after the probe; known exit segfault)"
        exit 0
        ;;
    esac
    echo "EDA_SMOKE_FAIL: lc_shell exited ${rc} after the probe" >&2
    exit 1
fi
echo "EDA_SMOKE_OK: lc"
