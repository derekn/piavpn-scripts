#!/bin/sh -e

## Get authentication token for PIA API, outputs in bash variable format.

# required vars
PIA_USER="${PIA_USER:?missing required var}"
PIA_PASS="${PIA_PASS:?missing required var}"

token="$(curl -sS -u "$PIA_USER:$PIA_PASS" 'https://www.privateinternetaccess.com/gtoken/generateToken')"
if [[ "$(echo "$token" | jq -r '.status')" != OK ]]; then
	>&2 echo "$token"
	exit 1
fi

token=$(echo "$token" | jq -r '.token')
echo "PIA_TOKEN=$token"
