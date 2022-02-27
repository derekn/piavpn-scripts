#!/bin/sh -e

## Download latest CA certificate for PIA servers.

cd "$(dirname "$0")"
curl -fsS 'https://raw.githubusercontent.com/pia-foss/manual-connections/master/ca.rsa.4096.crt' -o ca.rsa.4096.crt
