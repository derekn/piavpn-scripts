PIA Wireguard VPN Command Line Scripts
======================================

Linux/macOS command line scripts for connecting to [Private Internet Access](https://www.privateinternetaccess.com/) next-gen [Wireguard](https://www.wireguard.com/) servers.  
Based on the [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections) reference scripts, but built for use.

_Note: these are unofficial scripts, not affiliated with Private Internet Access®, created for personal use without warranty or guarantee._

### Requirements

- [wireguard-tools](https://github.com/WireGuard/wireguard-tools)
- [jq](https://stedolan.github.io/jq/)
- curl
- xargs _(Note: busybox version doesn't work)_
- awk

### Installation/Quick-Start

The quick-start scripts runs the other scripts in order to connect to the Wireguard VPN server.  
To enable port-forwarding, you must run the `port_forwarding.sh` script manually after connecting.

```sh
git pull https://github.com/derekn/piavpn-scripts.git
cd piavpn-scripts

PIA_USER=user PIA_PASS=pass ./setup.sh

# VPN should now be connecting, if there were no errors.
# interface name is "pia", and can be checked using `wg show pia`

# optionally enable port-forwarding
./port_forwarding.sh

# disconnect
wg-quick down pia
```

### Manual Usage

For advanced usage, see [setup.sh](setup.sh) for an example of manually running scripts.  
Scripts should be run in the following order, exporting the output environment variables to pass to the next script.

1. get_region - _outputs `REGION_ID`, `WG_SERVER_IP`, `WG_HOSTNAME`, `META_SERVER_IP` and `META_HOSTNAME`_
1. get_token - _outputs `PIA_TOKEN`_
1. connect_wireguard
1. port_forwarding - _optional, outputs `PAYLOAD_AND_SIGNATURE`, `PORT_FORWARD_PORT` and `PORT_EXPIRES_AT`_

### Included Scripts

| Script | Required Variables | Purpose |
| :--- | :--- | :--- |
| [setup.sh](setup.sh) | `PIA_USER`<br>`PIA_PASS` | Quick-start script for running all below scripts and getting connected. All optional variables from other scripts are supported. |
| [get_region.sh](get_region.sh) | | Get region details.<br>Optional, `PREFERRED_REGION` to set specific region by id (ex. ca_toronto). `PIA_PF=true` to only select regions supporting port-forwarding. |
| [get_token.sh](get_token.sh) | `PIA_USER`<br>`PIA_PASS` | Get token for API operations. |
| [connect_wireguard.sh](connect_wireguard.sh) | `PIA_TOKEN`<br>`WG_SERVER_IP`<br>`WG_HOSTNAME` | Connect to Wireguard server obtained from get_region.sh. Optional, `PIA_DNS=false` to use host DNS servers, default true. `SYNOLOGY_FIX=true` to apply fix for legacy iptables version on Synology NAS devices, see [description](#synology-fix). |
| [port_forwarding.sh](port_forwarding.sh) | `WG_SERVER_IP`<br>`WG_HOSTNAME`<br>`PIA_TOKEN` | Enable port forwarding and bind port. Optional, `PAYLOAD_AND_SIGNATURE` to reuse existing port for keep-alive loop. |
| [refresh_cacert.sh](refresh_cacert.sh) | | Download the latest CA certificate for PIA servers. |
| [latency_test.sh](latency_test.sh) | | Show lowest latency regions. `PIA_PF=true` to only select regions supporting port-forwarding. |

### Firewall/Kill-switch

The scripts do not do any additional modifications to the system other than creating the Wireguard interface and disabling IPv6.
It's recommended to setup iptables/ufw firewall rules to prevent non-VPN traffic from leaking.  
Below is an example using iptables.

```sh
iptables -I OUTPUT ! -o pia -m mark ! --mark $(wg show pia fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
```

### Synology Fix

[Synology](https://www.synology.com) NAS devices have a legacy version of `iptables` without support for the `raw` table, which `wg-quick` command uses internally when setting `AllowedIPs = 0.0.0.0/0`.  
As a workaround, without needing to change `AllowedIPs`, adding `Table = 51820` to the interface config section prevents `wg-quick` from applying the default setup rules.
The `SYNOLOGY_FIX=true` option effectively sets the `Table` option and applies the corresponding `fwmark` and `iptables` rules in the `PostUp`/`PostDown` hooks replicating
the default behavior of `wg-quick`, sans the use of the `raw` table.

The resulting Wireguard config will look like this...

```ini
[Interface]
Address = ...
PrivateKey = ...
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

[Peer]
PublicKey = ...
AllowedIPs = 0.0.0.0/0
Endpoint = ...
PersistentKeepalive = 25
```
