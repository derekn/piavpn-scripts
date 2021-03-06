#!/bin/sh -e

## Port forwarding setup and keep-alive loop.

# required vars
WG_SERVER_IP="${WG_SERVER_IP:?missing required var}"
WG_HOSTNAME="${WG_HOSTNAME:?missing required var}"
PIA_TOKEN="${PIA_TOKEN:?missing required var}"

# optional vars
PAYLOAD_AND_SIGNATURE="${PAYLOAD_AND_SIGNATURE:-}"
KEEPALIVE="${KEEPALIVE:-false}"

bind_port() {
	local response="$(curl -sS -m 5 --retry 3 --get \
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

cd "$(dirname "$0")"
source funcs

if [[ -z "$PAYLOAD_AND_SIGNATURE" ]]; then
	PAYLOAD_AND_SIGNATURE="$(curl -sS -m 5 --retry 3 --get \
		--connect-to "$WG_HOSTNAME::$WG_SERVER_IP:" \
		--cacert ca.rsa.4096.crt \
		--data-urlencode "token=$PIA_TOKEN" \
		"https://${WG_HOSTNAME}:19999/getSignature")"
	is_new_signature=true
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
	if [[ "$is_new_signature" == true ]]; then
		cat <<-EOF
			PAYLOAD_AND_SIGNATURE='$PAYLOAD_AND_SIGNATURE'
			PORT_FORWARD_PORT=$port
			PORT_EXPIRES_AT=$expires_at
		EOF
	else
		echo "${YELLOW}Rebinding port forwarding...${RESET}"
	fi
	bind_port
else
	while true; do
		echo "${GREEN}Binding port forwarding port...${RESET}"
		bind_port || true
		sleep 15m
	done
fi
