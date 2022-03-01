#!/bin/sh -e

## Connect to PIA via Wireguard.

# required vars
PIA_TOKEN="${PIA_TOKEN:?missing required var}"
WG_SERVER_IP="${WG_SERVER_IP:?missing required var}"
WG_HOSTNAME="${WG_HOSTNAME:?missing required var}"

# optional vars
PIA_DNS="${PIA_DNS:-false}"

cd "$(dirname "$0")"

if [[ $(id -u) -ne 0 ]]; then
	>&2 echo 'must be run as root'
	exit 1
fi

# PIA doesnt support IPv6, so disable to prevent leaking
echo -n 'Disabling IPv6...'
sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null
sysctl -w net.ipv6.conf.default.disable_ipv6=1 > /dev/null
if [[ $(sysctl -n net.ipv6.conf.all.disable_ipv6) -ne 1 ]]; then
	>&2 echo 'FAILED'
	exit 1
fi
echo 'done.'

echo -n 'Generating private/public keys...'
pvtkey=$(wg genkey)
pubkey=$(echo "$pvtkey" | wg pubkey)
if [[ -z "$pvtkey" || -z "$pubkey" ]]; then
	>&2 echo 'FAILED'
	exit 1
fi
echo 'done.'

echo -n 'Adding key to wireguard server...'
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
echo 'done.'

echo -n 'Writing VPN config...'
server_key=$(echo "$wireguard_json" | jq -r '.server_key')
server_port=$(echo "$wireguard_json" | jq -r '.server_port')
peer_ip=$(echo "$wireguard_json" | jq -r '.peer_ip')
dns_servers=$(echo "$wireguard_json" | jq -r '.dns_servers | join(", ")')

# optionally use PIA DNS servers
if [[ "$PIA_DNS" == true ]]; then
	use_dns_servers="DNS = ${dns_servers}\n"
fi

cat <<-EOF > /etc/wireguard/pia.conf
	[Interface]
	Address = $peer_ip
	PrivateKey = $pvtkey
	$use_dns_servers
	[Peer]
	PublicKey = $server_key
	AllowedIPs = 0.0.0.0/0
	Endpoint = ${WG_SERVER_IP}:${server_port}
	PersistentKeepalive = 25
EOF
echo 'done.'

echo 'Connecting VPN...'
wg-quick up pia
if ! wg show pia; then
	>&2 echo 'FAILED'
	exit 1
fi
