#!/bin/sh -e

## Quick-start to chain other scripts and get connected.

# required vars
PIA_USER="${PIA_USER:?missing required var}"
PIA_PASS="${PIA_PASS:?missing required var}"

check_tool() {
	if ! type $1 > /dev/null; then
		>&2 echo "required command '$1' not installed"
		exit 1
	fi
}

if [[ $(id -u) -ne 0 ]]; then
	>&2 echo 'must be run as root'
	exit 1
fi

for i in wg wg-quick curl jq; do
	check_tool $i
done

export PIA_USER PIA_PASS

env_vars=/tmp/pia.env
rm "$env_vars"

echo 'Getting region details...'
./get_region.sh | tee -a "$env_vars"
source "$env_vars"
export WG_SERVER_IP WG_HOSTNAME

echo 'Getting API token...'
./get_token.sh | tee -a "$env_vars"
source "$env_vars"
export PIA_TOKEN

echo 'Connecting VPN...'
./connect_wireguard.sh
