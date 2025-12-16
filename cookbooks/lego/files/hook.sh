#!/bin/ksh

set -eu

_log() {
    echo "lego-hook: $*"
    logger -t lego-hook "$*"
}

_err() {
    _log "ERROR: $*"
    exit 1
}

deploy_cert() {
    _log "Deploying cert for ${LEGO_CERT_DOMAIN}"
    
    install -o root -g _cert -m 0644 "${LEGO_CERT_PATH}" "/etc/ssl/${LEGO_CERT_DOMAIN}.crt" || \
        _err "Failed to copy cert for ${LEGO_CERT_DOMAIN}"

    install -o root -g _cert -m 0640 "${LEGO_CERT_KEY_PATH}" "/etc/ssl/private/${LEGO_CERT_DOMAIN}.key" || \
        _err "Failed to copy key for ${LEGO_CERT_DOMAIN}"
}

deploy_cert

# vim: sts=4 ts=4 sw=4 et
