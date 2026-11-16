#!/bin/sh
set -e

# Docker's marker files make snpslmd exit with non-privileged domain/zone.
rm -f /.dockerenv /.dockerinit

# The license is node-locked to MAC 52:54:00:ad:a0:86 (hostid 525400ada086).
ip link set eth0 address 52:54:00:ad:a0:86
echo '127.0.0.1 lic1' >> /etc/hosts
export LD_PRELOAD=/opt/synopsys/scl/2025.03/linux64/bin/snpslmd-hack.so

# lmgrd/snpslmd run as root: the 2025.03 vendor daemon dies with
# "free(): invalid pointer" when dropped to uid 1001, unlike the 2024.06 one.
# PID 1 stays this shell so the daemons run with the container's capabilities.
lmgrd -z -c /opt/synopsys/scl/2025.03/admin/license/license.dat &
wait
