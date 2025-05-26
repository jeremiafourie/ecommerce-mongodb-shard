#!/usr/bin/env bash
set -euo pipefail

# Install dependencies for Ubuntu
apt-get update && apt-get install -y iproute2 mongodb-clients

while true; do
  sleep $((120 + RANDOM % 180))
  echo 'rs.stepDown(60)' | mongosh --host mongos:27017
  tc qdisc add dev eth0 root netem delay 100ms
  sleep 30
  tc qdisc del dev eth0 root
done