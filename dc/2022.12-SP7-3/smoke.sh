#!/bin/sh
# Start probe for Design Compiler 2022.12, packaged at /opt/eda-smoke/smoke.sh.
# Re-run against a finished image:
#   nerdctl run --rm --entrypoint /opt/eda-smoke/smoke.sh \
#       local.io/synopsys/dc:2022.12-SP7-3
#
# Two stages, because this release cannot always check out a license: its SCL
# client rejects the 2025.12 feature signatures the site server serves (FlexNet
# -8,544 "invalid (inconsistent) license key"), so on that server `dc_shell`
# prints "Design Compiler is not enabled" and exits.  `dc_shell -version` needs
# no license and still loads the wrapper, the dynamic loader and every library
# of common_shell_exec, so it runs first and always has to pass; the Tcl probe
# then runs when the license does check out.
set -eu

: "${SNPSLMD_LICENSE_FILE:=2700@license.synopsys.svc.cluster.local}"
: "${LM_LICENSE_FILE:=$SNPSLMD_LICENSE_FILE}"
export SNPSLMD_LICENSE_FILE LM_LICENSE_FILE EDA_SMOKE_TOOL=dc

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
cd "$work"

# 1. The tool starts and reports its release.
rc=0
HOME=$work TMPDIR=$work timeout -k 30 300 dc_shell -version >"$work/version.log" 2>&1 || rc=$?
cat "$work/version.log"
grep -q 'U-2022.12-SP7-3' "$work/version.log" || {
    echo "EDA_SMOKE_FAIL: dc_shell did not start (exit ${rc})" >&2
    exit 1
}

# 2. The Tcl shell, when the license server authorizes this release.
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

# FLEXLM_DIAGNOSTICS makes the client say *why* a checkout failed, which is
# what tells the known site-license failure below apart from a real one.
rc=0
FLEXLM_DIAGNOSTICS=${FLEXLM_DIAGNOSTICS:-3} \
HOME=$work TMPDIR=$work timeout -k 30 300 \
    dc_shell -f "$work/smoke.tcl" >"$work/smoke.log" 2>&1 || rc=$?
cat "$work/smoke.log"

if grep -q EDA_SMOKE_OK "$work/smoke.log"; then
    if [ "$rc" -ne 0 ]; then
        echo "EDA_SMOKE_FAIL: dc exited ${rc} after the probe" >&2
        exit 1
    fi
    echo "EDA_SMOKE_OK: dc"
    exit 0
fi

if grep -q 'DCSH-1' "$work/smoke.log" && grep -q '\-8,544' "$work/smoke.log"; then
    echo "EDA_SMOKE_OK: dc (start only; the license server cannot authorize" \
         "2022.12 feature versions)"
    exit 0
fi

echo "EDA_SMOKE_FAIL: dc did not reach the Tcl probe (exit ${rc})" >&2
exit 1
