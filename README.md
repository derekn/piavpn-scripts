PIA Wireguard VPN Command Line Scripts
======================================

Linux/macOS command line scripts for connecting to [Private Internet Access](https://www.privateinternetaccess.com/) next-gen [Wireguard](https://www.wireguard.com/) servers.  
Based on the [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections) reference scripts, but built for use.

_Note: these are unofficial scripts, not affiliated with Private Internet Access®, created for personal use without warranty or guarantee._

### Requirements

- [wireguard-tools](https://github.com/WireGuard/wireguard-tools)
- curl
- [jq](https://stedolan.github.io/jq/)
- xargs _(busybox version won't work)_
- awk

### Installation/Quick-Start

```sh
git pull https://github.com/derekn/piavpn-scripts.git
cd piavpn-scripts

PIA_USER=user PIA_PASS=pass ./setup.sh
```

### Manual Usage

For advanced usage, see [setup.sh](setup.sh) for an example of manually running scripts.  
Scripts should be run in the following order, exporting the output environment variables to pass to the next script.

1. get_region - _outputs `WG_SERVER_IP` and `WG_HOSTNAME`_
1. get_token - _outputs `PIA_TOKEN`_
1. connect_wireguard

### Included Scripts

| Script | Required Variables | Purpose |
| :--- | :--- | :--- |
| [setup.sh](setup.sh) | `PIA_USER`<br>`PIA_PASS` | Quick-start script for running all below scripts and getting connected. All optional variables from other scripts are supported. |
| [get_region.sh](get_region.sh) | | Get region details.<br>Optional, `PREFERRED_REGION` to set specific region by id (ex. ca_toronto). `PIA_PF=true` to only select regions supporting port-forwarding. |
| [get_token.sh](get_token.sh) | `PIA_USER`<br>`PIA_PASS` | Get token for API operations. |
| [connect_wireguard.sh](connect_wireguard.sh) | `PIA_TOKEN`<br>`WG_SERVER_IP`<br>`WG_HOSTNAME` | Connect to Wireguard server obtained from get_region.sh. |
