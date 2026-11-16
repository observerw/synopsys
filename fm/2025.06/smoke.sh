#!/bin/sh
# Start probe for Formality, packaged at /opt/eda-smoke/smoke.sh.
#
# The Containerfile runs it as the last build step, so a tree that cannot
# start never reaches the registry.  Re-run it against a finished image:
#
#   nerdctl run --rm --entrypoint /opt/eda-smoke/smoke.sh \
#       local.io/synopsys/fm:2025.06
#
# The shell is driven by the smoke.tcl below so the probe is the same Tcl
# script for every Synopsys Tcl shell.  The tool writes command.log, a license
# cache and GUI state into $HOME and the current directory, so it runs in a
# throwaway tree; the build mounts /tmp and /root as tmpfs, so none of that
# reaches an image layer.
set -eu

: "${SNPSLMD_LICENSE_FILE:=2700@license.synopsys.svc.cluster.local}"
: "${LM_LICENSE_FILE:=$SNPSLMD_LICENSE_FILE}"
export SNPSLMD_LICENSE_FILE LM_LICENSE_FILE EDA_SMOKE_TOOL=fm

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
    fm_shell -f "$work/smoke.tcl" >"$log" 2>&1 || rc=$?
cat "$log"

grep -q EDA_SMOKE_OK "$log" || {
    echo "EDA_SMOKE_FAIL: fm did not reach the Tcl probe (exit ${rc})" >&2
    exit 1
}
if [ "$rc" -ne 0 ]; then
    echo "EDA_SMOKE_FAIL: fm exited ${rc} after the probe" >&2
    exit 1
fi
echo "EDA_SMOKE_OK: fm"
