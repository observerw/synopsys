#!/bin/sh
# Start probe for VCS, packaged at /opt/eda-smoke/smoke.sh.
# Re-run against a finished image:
#   nerdctl run --rm --entrypoint /opt/eda-smoke/smoke.sh \
#       local.io/synopsys/vcs:2025.06-SP1
#
# VCS has no Tcl command shell; vcs -full64 -ID loads the same wrapper,
# bundled libraries and license stack that a real run uses.
set -eu

: "${SNPSLMD_LICENSE_FILE:=2700@license.synopsys.svc.cluster.local}"
: "${LM_LICENSE_FILE:=$SNPSLMD_LICENSE_FILE}"
export SNPSLMD_LICENSE_FILE LM_LICENSE_FILE

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
cd "$work"
log=$work/smoke.log
rc=0
HOME=$work TMPDIR=$work timeout -k 30 300 vcs -full64 -ID >"$log" 2>&1 || rc=$?
cat "$log"

[ "$rc" -eq 0 ] || {
    echo "EDA_SMOKE_FAIL: vcs exited ${rc}" >&2
    exit 1
}
grep -qi 'vcs' "$log" || {
    echo "EDA_SMOKE_FAIL: vcs printed no startup banner" >&2
    exit 1
}
echo "EDA_SMOKE_OK: vcs"
