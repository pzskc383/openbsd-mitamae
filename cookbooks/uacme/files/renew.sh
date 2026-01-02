#!/bin/ksh
#
# Run all uacme certificate renewals
#
set -u

CONFDIR=/etc/ssl/uacme

_log() {
    echo "uacme-renew: $*"
    logger -t uacme-renew "$*"
}

for script in ${CONFDIR}/issue-*.sh; do
    [ -f "$script" ] || continue

    name="${script##*/issue-}"
    name="${name%.sh}"

    _log "checking ${name}"
    "$script" || _log "${name}: failed"
done

# restart services if any certs were updated
if [ -f /etc/ssl/.needs_restart ]; then
    rm -f /etc/ssl/.needs_restart
    _log "restarting services"
    for svc in relayd smtpd dovecot; do
        rcctl check "$svc" >/dev/null 2>&1 && rcctl restart "$svc"
    done
fi
