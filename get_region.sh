#!/bin/sh -e

## Get region details from PIA API, outputs in bash variable format.

# optional vars
PREFERRED_REGION="${PREFERRED_REGION:-}"
PIA_PF="${PIA_PF:-false}"

best_latency() {
	local max_latency="${1:-0.05}"
	cat | xargs -l sh -c 'time=$(curl -s -o /dev/null --connect-timeout '"$max_latency"' -w "%{time_connect}" "http://$0:443"); test $? -eq 0 && echo "$time $1"' | sort
}

get_region() {
	local region_id="${1:?}"
	echo "$all_regions" | jq -r --arg REGION_ID "$region_id" '.regions[] | select(.id == $REGION_ID)'
}

all_regions="$(curl -fsS 'https://serverlist.piaservers.net/vpninfo/servers/v6' | head -1)"
if [[ ${#all_regions} -lt 1000 ]]; then
	>&2 echo 'Error: failed to get region list from api'
	exit 1
fi

if [[ -z "$PREFERRED_REGION" ]]; then
	if [[ "$PIA_PF" == true ]]; then
		selected_region=$(echo "$all_regions" | \
			jq -r '.regions[] | select(.offline != true) | select(.port_forward == true) | .servers.meta[0].ip+" "+.id' | \
			best_latency | awk 'NR==1 {print $2}')
		selected_region=$(get_region "$selected_region")
	else
		selected_region=$(echo "$all_regions" | \
			jq -r '.regions[] | select(.offline != true) | .servers.meta[0].ip+" "+.id' | \
			best_latency | awk 'NR==1 {print $2}')
		selected_region=$(get_region "$selected_region")
	fi
else
	selected_region=$(get_region "$PREFERRED_REGION")
fi

if [[ -z "$selected_region" ]]; then
	>&2 echo 'Error: failed to get region details'
	exit 1
fi

region_name=$(echo "$selected_region" | jq -r '.id')
region_host=$(echo "$selected_region" | jq -r '.servers.wg[0].cn')
region_ip=$(echo "$selected_region" | jq -r '.servers.wg[0].ip')
meta_host=$(echo "$selected_region" | jq -r '.servers.meta[0].cn')
meta_ip=$(echo "$selected_region" | jq -r '.servers.meta[0].ip')

cat <<-EOF
	REGION_ID=$region_name
	WG_SERVER_IP=$region_ip
	WG_HOSTNAME=$region_host
	META_SERVER_IP=$meta_ip
	META_HOSTNAME=$meta_host
EOF
