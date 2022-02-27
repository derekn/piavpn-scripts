#!/bin/sh -e

## Get authentication token for PIA API, outputs in bash variable format.
## PIA_USER=required
## PIA_PASS=required

if [[ -z "$PIA_USER" || -z "$PIA_PASS" ]]; then
	>&2 echo 'missing PIA_USER / PIA_PASS variables'
	exit 1
fi

token=$(curl -sS -u "$PIA_USER:$PIA_PASS" 'https://www.privateinternetaccess.com/gtoken/generateToken')
if [[ $(echo "$token" | jq -r '.status') != OK ]]; then
	>&2 echo "$token"
	exit 1
fi

token=$(echo "$token" | jq -r '.token')
echo "PIA_TOKEN=$token"
