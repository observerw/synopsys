# Print the image MOTD for interactive shells.
#
# /etc/profile.d is read by login shells only, and XFCE terminals start a
# non-login bash that reads /etc/bashrc, so both source this file.  The
# shell-local (not exported) guard keeps a login shell from printing it twice,
# and the interactive/tty checks keep it out of scripts and job logs.
case $- in
*i*) ;;
*) return 0 ;;
esac
if [ -n "${EDA_MOTD_SHOWN:-}" ] || [ ! -t 1 ] || [ ! -r /etc/motd ]; then
    return 0
fi
EDA_MOTD_SHOWN=1
cat /etc/motd
