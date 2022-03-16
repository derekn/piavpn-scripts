#!/bin/sh -e

## Connect to PIA via Wireguard.

# required vars
PIA_TOKEN="${PIA_TOKEN:?missing required var}"
WG_SERVER_IP="${WG_SERVER_IP:?missing required var}"
WG_HOSTNAME="${WG_HOSTNAME:?missing required var}"

# optional vars
PIA_DNS="${PIA_DNS:-true}"
DISABLE_IPV6="${DISABLE_IPV6:-true}"
SYNOLOGY_FIX="${SYNOLOGY_FIX:-false}"

cd "$(dirname "$0")"
source funcs

if [[ $(id -u) -ne 0 ]]; then
	>&2 echo 'Error: must be run as root'
	exit 1
fi

if [[ ! -f ca.rsa.4096.crt ]]; then
	./refresh_cacert.sh
fi

# PIA doesnt support IPv6, so disable to prevent leaking
if [[ "$DISABLE_IPV6" == true ]]; then
	echo "${GREEN}Disabling IPv6...${RESET}"
	sysctl -q net.ipv6.conf.all.disable_ipv6=1
	sysctl -q net.ipv6.conf.default.disable_ipv6=1
	if [[ $(sysctl -n net.ipv6.conf.all.disable_ipv6) -ne 1 ]]; then
		>&2 echo 'Error: could not disable IPv6'
		exit 1
	fi
fi

echo "${GREEN}Generating private/public keys...${RESET}"
pvtkey=$(wg genkey)
pubkey=$(echo "$pvtkey" | wg pubkey)
if [[ -z "$pvtkey" || -z "$pubkey" ]]; then
	>&2 echo 'Error: could not generate keys'
	exit 1
fi

echo "${GREEN}Adding key to wireguard server...${RESET}"
wireguard_json="$(curl -sS --get \
	--connect-to "$WG_HOSTNAME::$WG_SERVER_IP:" \
	--cacert ca.rsa.4096.crt \
	--data-urlencode "pt=$PIA_TOKEN" \
	--data-urlencode "pubkey=$pubkey" \
	"https://${WG_HOSTNAME}:1337/addKey")"

if [[ "$(echo "$wireguard_json" | jq -r '.status')" != OK ]]; then
	>&2 echo "$wireguard_json"
	exit 1
fi

echo "${GREEN}Writing VPN config...${RESET}"
server_key=$(echo "$wireguard_json" | jq -r '.server_key')
server_port=$(echo "$wireguard_json" | jq -r '.server_port')
peer_ip=$(echo "$wireguard_json" | jq -r '.peer_ip')
dns_servers=$(echo "$wireguard_json" | jq -r '.dns_servers | join(", ")')

# optionally use PIA DNS servers
if [[ "$PIA_DNS" == true ]]; then
	interface_opts="${interface_opts}DNS = $dns_servers"$'\n'
fi

# fix for Synology NAS devices
if [[ "$SYNOLOGY_FIX" == true ]]; then
	interface_opts="${interface_opts}$(cat <<-EOF
		Table = 51820
		PostUp = wg set pia fwmark 51820
		PostUp = ip -4 rule add not fwmark 51820 table 51820
		PostUp = ip -4 rule add table main suppress_prefixlength 0
		PostUp = sysctl -q net.ipv4.conf.all.src_valid_mark=1
		PostUp = iptables -t mangle -A PREROUTING -p udp -j CONNMARK --restore-mark --nfmask 0xffffffff --ctmask 0xffffffff
		PostUp = iptables -t mangle -A POSTROUTING -p udp -m mark --mark 0xca6c -j CONNMARK --save-mark --nfmask 0xffffffff --ctmask 0xffffffff
		PostDown = ip -4 rule delete table 51820
		PostDown = ip -4 rule delete table main suppress_prefixlength 0
		PostDown = iptables -t mangle -D PREROUTING -p udp -j CONNMARK --restore-mark --nfmask 0xffffffff --ctmask 0xffffffff
		PostDown = iptables -t mangle -D POSTROUTING -p udp -m mark --mark 0xca6c -j CONNMARK --save-mark --nfmask 0xffffffff --ctmask 0xffffffff
	EOF
	)"
fi

cat <<-EOF > /etc/wireguard/pia.conf
	[Interface]
	Address = $peer_ip
	PrivateKey = $pvtkey
	$interface_opts
	[Peer]
	PublicKey = $server_key
	AllowedIPs = 0.0.0.0/0
	Endpoint = ${WG_SERVER_IP}:${server_port}
	PersistentKeepalive = 25
EOF

echo "${GREEN}Connecting VPN...${RESET}"
wg-quick up pia
if ! wg show pia > /dev/null; then
	>&2 echo 'Error: pia interface not created'
	exit 1
fi
