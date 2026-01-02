#!/bin/ksh
#
# uacme challenge hook - supports dns-01 and http-01
#
# Expects from environment:
#   dns-01:  ACME_ZONE, KNOT_SERVER, TSIG_KEY, TSIG_SECRET
#   http-01: ACME_WEBROOT
#
set -eu

_log() {
    echo "uacme-hook: $*"
    logger -t uacme-hook "$*"
}

_err() {
    _log "ERROR: $*"
    exit 1
}

METHOD="$1"
TYPE="$2"
IDENT="$3"
TOKEN="$4"
AUTH="$5"

case "$TYPE" in
dns-01)
    [ -z "${ACME_ZONE:-}" ] && _err "ACME_ZONE not set"
    [ -z "${KNOT_SERVER:-}" ] && _err "KNOT_SERVER not set"
    [ -z "${TSIG_KEY:-}" ] && _err "TSIG_KEY not set"
    [ -z "${TSIG_SECRET:-}" ] && _err "TSIG_SECRET not set"
    FQDN="_acme-challenge.${IDENT}"

    case "$METHOD" in
    begin)
        _log "dns-01: deploying challenge for $IDENT in zone $ACME_ZONE"
        knsupdate -y "hmac-sha256:${TSIG_KEY}:${TSIG_SECRET}" <<-EOF
		server ${KNOT_SERVER}
		zone ${ACME_ZONE}
		update add ${FQDN}. 300 TXT "${AUTH}"
		send
		EOF
        sleep 3
        ;;
    done|failed)
        _log "dns-01: cleaning challenge for $IDENT"
        knsupdate -y "hmac-sha256:${TSIG_KEY}:${TSIG_SECRET}" <<-EOF
		server ${KNOT_SERVER}
		zone ${ACME_ZONE}
		update delete ${FQDN}. TXT
		send
		EOF
        ;;
    esac
    ;;

http-01)
    [ -z "${ACME_WEBROOT:-}" ] && _err "ACME_WEBROOT not set"
    CHALLENGE_DIR="${ACME_WEBROOT}/.well-known/acme-challenge"
    CHALLENGE_FILE="${CHALLENGE_DIR}/${TOKEN}"

    case "$METHOD" in
    begin)
        _log "http-01: deploying challenge for $IDENT in $ACME_WEBROOT"
        mkdir -p "$CHALLENGE_DIR"
        printf '%s' "$AUTH" > "$CHALLENGE_FILE"
        chmod 644 "$CHALLENGE_FILE"
        ;;
    done|failed)
        _log "http-01: cleaning challenge for $IDENT"
        rm -f "$CHALLENGE_FILE"
        ;;
    esac
    ;;

*)
    _err "unsupported challenge type: $TYPE"
    ;;
esac

exit 0
