#!/bin/sh -e

## Show lowest latency regions

# optional vars
PIA_PF="${PIA_PF:-false}"

best_latency() {
	local max_latency="${1:-0.05}"
	cat | xargs -l sh -c 'time=$(curl -s -o /dev/null --connect-timeout '"$max_latency"' -w "%{time_connect}" "http://$0:443"); test $? -eq 0 && echo "$time $@"' | sort
}

all_regions="$(curl -fsS 'https://serverlist.piaservers.net/vpninfo/servers/v6' | head -1)"
if [[ ${#all_regions} -lt 1000 ]]; then
	>&2 echo 'Error: failed to get region list from api'
	exit 1
fi

if [[ "$PIA_PF" == true ]]; then
	echo "$all_regions" | \
		jq -r '.regions[] | select(.offline != true) | select(.port_forward == true) | .servers.meta[0].ip+" "+.id+" "+.name' | \
		best_latency
else
	echo "$all_regions" | \
		jq -r '.regions[] | select(.offline != true) | .servers.meta[0].ip+" "+.id+" "+.name' | \
		best_latency
fi
