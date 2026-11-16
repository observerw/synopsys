#!/bin/bash
# Fetch the official KasmVNC RHEL 8-compatible RPM into kasmvnc/ for the
# synopsys/2025.06/ build.
#
# This is the only file the image needs from outside an image: every tool tree,
# VIP and the PDK trees are copied out of the product images.  The build pods
# have no GitHub egress, so the RPM is fetched here and its sha256 is pinned.
#
#   ./fetch-kasmvnc.sh
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DIR="$HERE/kasmvnc"

KASMVNC_VERSION=1.5.2
KASMVNC_RPM="kasmvncserver_oracle_8_${KASMVNC_VERSION}_x86_64.rpm"
KASMVNC_URL="https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VERSION}/${KASMVNC_RPM}"
KASMVNC_SHA=8f37a5e75c09420228108e665f6e40e90d83ee767c1874c4c9eee04fcc853df2

rpm="$DIR/$KASMVNC_RPM"
mkdir -p "$DIR"
if [ -f "$rpm" ] \
   && printf '%s  %s\n' "$KASMVNC_SHA" "$rpm" | sha256sum -c - >/dev/null 2>&1; then
    echo "$rpm"
    exit 0
fi

rm -f "$rpm" "$rpm.part"
echo "downloading $KASMVNC_RPM"
if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --connect-timeout 20 -o "$rpm.part" "$KASMVNC_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -O "$rpm.part" "$KASMVNC_URL"
else
    echo "curl or wget is required to fetch $KASMVNC_URL" >&2
    exit 1
fi
printf '%s  %s\n' "$KASMVNC_SHA" "$rpm.part" | sha256sum -c -
mv -f "$rpm.part" "$rpm"
echo "$rpm"
