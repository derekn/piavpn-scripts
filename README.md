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
| [connect_wireguard.sh](connect_wireguard.sh) | `PIA_TOKEN`<br>`WG_SERVER_IP`<br>`WG_HOSTNAME` | Connect to Wireguard server obtained from get_region.sh. Optional, `PIA_DNS=true` to use PIA's DNS servers. |
| [port_forwarding.sh](port_forwarding.sh) | `WG_SERVER_IP`<br>`WG_HOSTNAME`<br>`PIA_TOKEN` | Enable port forwarding and bind port. Optional, `PAYLOAD_AND_SIGNATURE` to reuse existing port for keep-alive loop. |
| [refresh_cacert.sh](refresh_cacert.sh) | | Download the latest CA certificate for PIA servers. |

### Firewall/Kill-switch

The scripts do not do any additional modifications to the system other than creating the Wireguard interface and disabling IPv6.
It's recommended to setup iptables/ufw firewall rules to prevent non-VPN traffic from leaking.  
Below is an example using iptables.

```sh
iptables -I OUTPUT ! -o pia -m mark ! --mark $(wg show pia fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
```
