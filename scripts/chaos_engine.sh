#!/usr/bin/env bash
set -euo pipefail

# Install iproute2 only (mongosh is built-in)
apt-get update && apt-get install -y iproute2

# 1) Wait for mongos readiness
echo "⏳ Waiting for mongos..."
until mongosh --quiet --host mongos --eval 'db.adminCommand({ ping:1 })' >/dev/null 2>&1; do
  sleep 2
done
echo "✅ Mongos available. Starting chaos-engine..."

# 2) Continuous fault injection
while true; do
  sleep $((120 + RANDOM % 180))
  echo "🔀 Stepping down current primary..."
  echo 'rs.stepDown(60)' | mongosh --host mongos

  echo "🐢 Injecting 100ms latency..."
  tc qdisc add dev eth0 root netem delay 100ms
  sleep 30
  echo "🏁 Removing latency..."
  tc qdisc del dev eth0 root
done
