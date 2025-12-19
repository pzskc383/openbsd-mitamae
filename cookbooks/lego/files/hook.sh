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
    _log "Deploying cert ${CERT_NAME}"
    
    rm -f "/etc/ssl/${CERT_NAME}.crt" "/etc/ssl/private/${CERT_NAME}.key"
    rm -f "/etc/ssl/${LEGO_CERT_DOMAIN}.crt" "/etc/ssl/private/${LEGO_CERT_DOMAIN}.key"
    
    install -o root -g _cert -m 0444 "${LEGO_CERT_PATH}" "/etc/ssl/${CERT_NAME}.crt" || \
        _err "Failed to copy cert for ${CERT_NAME}"
    ln -sf "/etc/ssl/${CERT_NAME}.crt" "/etc/ssl/${LEGO_CERT_DOMAIN}.crt" 
    ln -sf "/etc/ssl/private/${CERT_NAME}.key" "/etc/ssl/private/${LEGO_CERT_DOMAIN}.key" 

    install -o root -g _cert -m 0440 "${LEGO_CERT_KEY_PATH}" "/etc/ssl/private/${CERT_NAME}.key" || \
        _err "Failed to copy key for ${CERT_NAME}"
}

deploy_cert

# vim: sts=4 ts=4 sw=4 et
