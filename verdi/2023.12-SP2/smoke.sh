#!/bin/sh
# Start probe for Verdi, packaged at /opt/eda-smoke/smoke.sh.
#
# The Containerfile runs it as the last build step, so a tree that cannot
# start never reaches the registry.  Re-run it against a finished image:
#
#   nerdctl run --rm --entrypoint /opt/eda-smoke/smoke.sh \
#       local.io/synopsys/verdi:2023.12-SP2
#
# Verdi has no Tcl command shell; verdi -id loads the same wrapper,
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
HOME=$work TMPDIR=$work timeout -k 30 300 verdi -id >"$log" 2>&1 || rc=$?
cat "$log"

[ "$rc" -eq 0 ] || {
    echo "EDA_SMOKE_FAIL: verdi exited ${rc}" >&2
    exit 1
}
grep -qi 'verdi' "$log" || {
    echo "EDA_SMOKE_FAIL: verdi printed no startup banner" >&2
    exit 1
}
echo "EDA_SMOKE_OK: verdi"
