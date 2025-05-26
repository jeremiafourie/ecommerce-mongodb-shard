#!/bin/sh
# Install required tools
apk add --no-cache iproute2 mongodb-tools

while true; do
  # Wait 2–5 minutes
  sleep $((120 + RANDOM % 180))

  # 1) Step down the primary to test replica failover
  echo 'rs.stepDown(60)' | mongosh --host mongos:27017

  # 2) Inject 100ms latency for 30s
  tc qdisc add dev eth0 root netem delay 100ms
  sleep 30
  tc qdisc del dev eth0 root
done
