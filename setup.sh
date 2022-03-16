#!/bin/sh -e

## Quick-start to chain other scripts and get connected.

# required vars
PIA_USER="${PIA_USER:?missing required var}"
PIA_PASS="${PIA_PASS:?missing required var}"
export PIA_USER PIA_PASS

env_vars=/tmp/pia.env

check_tool() {
	if ! type $1 > /dev/null; then
		>&2 echo "Error: required command '$1' not installed"
		exit 1
	fi
}

if [[ $(id -u) -ne 0 ]]; then
	>&2 echo 'Error: must be run as root'
	exit 1
fi

for i in wg wg-quick curl jq; do
	check_tool $i
done

cd "$(dirname "$0")"
source funcs

find "$env_vars" -mmin +1440 -delete &> /dev/null || true

if [[ -f "$env_vars" ]]; then
	echo "${GREEN}Loading existing variables...${RESET}"
	source "$env_vars"
fi

if [[ -z "$WG_SERVER_IP" || -z "$WG_HOSTNAME" ]]; then
	echo "${GREEN}Getting region details...${RESET}"
	./get_region.sh | tee -a "$env_vars"
	source "$env_vars"
fi
export WG_SERVER_IP WG_HOSTNAME

if [[ -z "$PIA_TOKEN" ]]; then
	echo "${GREEN}Getting API token...${RESET}"
	./get_token.sh >> "$env_vars"
	source "$env_vars"
fi
export PIA_TOKEN

./connect_wireguard.sh
