#!/bin/sh -e

## Port forwarding setup and keep-alive loop.

# required vars
WG_SERVER_IP="${WG_SERVER_IP:?missing required var}"
WG_HOSTNAME="${WG_HOSTNAME:?missing required var}"
PIA_TOKEN="${PIA_TOKEN:?missing required var}"

# optional vars
KEEPALIVE="${KEEPALIVE:-false}"
KEEPALIVE_INT="${KEEPALIVE_INT:-10m}"

bind_port() {
	local response="$(curl -sS --get \
		--connect-to "$WG_HOSTNAME::$WG_SERVER_IP:" \
		--cacert ca.rsa.4096.crt \
		--data-urlencode "payload=$payload" \
		--data-urlencode "signature=$signature" \
		"https://${WG_HOSTNAME}:19999/bindPort")"

	if [[ "$(echo "$response" | jq -r '.status')" != OK ]]; then
		>&2 echo "$response"
		exit 1
	fi
}

check_interface() {
	if ! wg show pia > /dev/null; then
		>&2 echo 'wireguard interface not up'
		exit 1
	fi
}

cd "$(dirname "$0")"

if [[ $(id -u) -ne 0 ]]; then
	>&2 echo 'must be run as root'
	exit 1
fi

check_interface

if [[ -z "$PAYLOAD_AND_SIGNATURE" ]]; then
	>&2 echo 'Getting new payload and signature...'
	PAYLOAD_AND_SIGNATURE="$(curl -sS --get \
		--connect-to "$WG_HOSTNAME::$WG_SERVER_IP:" \
		--cacert ca.rsa.4096.crt \
		--data-urlencode "token=$PIA_TOKEN"\
		"https://${WG_HOSTNAME}:19999/getSignature")"
else
	>&2 echo 'Using existing payload and signature'
fi

PAYLOAD_AND_SIGNATURE=$(echo "$PAYLOAD_AND_SIGNATURE" | jq -cr)
if [[ "$(echo "$PAYLOAD_AND_SIGNATURE" | jq -r '.status')" != OK ]]; then
	>&2 echo "$PAYLOAD_AND_SIGNATURE"
	exit 1
fi

signature=$(echo "$PAYLOAD_AND_SIGNATURE" | jq -r '.signature')
payload=$(echo "$PAYLOAD_AND_SIGNATURE" | jq -r '.payload')
port=$(echo "$payload" | base64 -d | jq -r '.port')
expires_at=$(echo "$payload" | base64 -d | jq -r '.expires_at')

if [[ "$KEEPALIVE" != true ]]; then
	bind_port
	cat <<-EOF
		PAYLOAD_AND_SIGNATURE='$PAYLOAD_AND_SIGNATURE'
		PORT_FORWARD_PORT=$port
		PORT_EXPIRES_AT=$expires_at
	EOF
else
	while true; do
		echo -n 'Binding port forwarding port...'
		bind_port
		echo 'done.'
		sleep "$KEEPALIVE_INT"
	done
fi
