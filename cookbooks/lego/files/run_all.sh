#!/bin/sh

set -u

_log() {
    echo "lego-wrapper: $*"
    logger -t lego-wrapper "$*"
}

_err() {
    _log "ERROR: $*"
    exit 1
}

case "${1-run}" in
renew)
    cmd=renew
    ;;
*)
    cmd=run
    ;;
esac

for scriptfile in /var/lego/scripts/*; do
    basename="${scriptfile##*/}"
    basename="${basename%.*}"
    
    $scriptfile $cmd
    run_result=$?
    
    if [ "$run_result" -eq 0 ]; then
        _log "Ran lego script ${basename} successfully"
    else
        _log "Script ${basename} failed!"
    fi
done

if [ -f /etc/ssl/.needs_restart ]; then
    rm -f /etc/ssl/.needs_restart
    for svc in relayd smtpd dovecot; do
        rcctl restart $svc;
    done
fi

# vim: sts=4 ts=4 sw=4 et
