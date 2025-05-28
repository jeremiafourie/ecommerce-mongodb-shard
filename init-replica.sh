#!/usr/bin/env bash
set -euo pipefail

# Wait until a replica set primary is elected
wait_for_primary() {
  local repl=$1
  shift
  local svcs=("$@")

  echo "⏳ Waiting for primary in ${repl}..."

  while true; do
    for svc_port in "${svcs[@]}"; do
      IFS=':' read -r svc port <<< "$svc_port"
      local cid; cid=$(docker compose ps -q "$svc")
      if docker exec -i "$cid" mongosh --quiet --port "$port" \
        --eval 'db.hello().isWritablePrimary' | grep -q true; then
        echo "✅ ${repl} primary is elected (on $svc:$port)."
        return 0
      fi
    done
  done
}

wait_for_host() {
  local hosts=("$@")
  for host in "${hosts[@]}"; do
    IFS=':' read -r host_name port <<< "$host"
    echo "Waiting for $host to become available..."
    local cid; cid=$(docker compose ps -q "$host_name")
    until \
      docker exec -i "$cid" mongosh --port "$port" --eval "db.adminCommand('ping')" >/dev/null; do
      echo "."
      sleep 2
    done
    echo "$host is up."
  done
}

CONFIG_HOSTS=("configsvr1:27019" "configsvr2:27019" "configsvr3:27019")

echo "Waiting for config servers to come online..."
wait_for_host "${CONFIG_HOSTS[@]}"

# 1) Config server RS
echo "⏳ Initiating configReplSet..."
docker exec -i "$(docker compose ps -q configsvr1)" mongosh --port 27019 <<'EOF'
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configsvr1:27019" },
    { _id: 1, host: "configsvr2:27019" },
    { _id: 2, host: "configsvr3:27019" }
  ]
});
EOF

wait_for_primary configReplSet "${CONFIG_HOSTS[@]}"

SHARD1_HOSTS=("shard1_primary:27018" "shard1_secondary1:27018" "shard1_secondary2:27018")

echo "Waiting for shard1's servers to come online..."
wait_for_host "${SHARD1_HOSTS[@]}"

# 2) Shard1 RS
echo "⏳ Initiating shard1ReplSet..."
docker exec -i "$(docker compose ps -q shard1_primary)" mongosh --port 27018 <<'EOF'
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1_primary:27018" },
    { _id: 1, host: "shard1_secondary1:27018" },
    { _id: 2, host: "shard1_secondary2:27018" }
  ]
});
EOF

wait_for_primary shard1ReplSet "${SHARD1_HOSTS[@]}"

SHARD2_HOSTS=("shard2_primary:27018" "shard2_secondary1:27018" "shard2_secondary2:27018")

echo "Waiting for shard2's servers to come online..."
wait_for_host "${SHARD2_HOSTS[@]}"

# 3) Shard2 RS
echo "⏳ Initiating shard2ReplSet..."
docker exec -i "$(docker compose ps -q shard2_primary)" mongosh --port 27018 <<'EOF'
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2_primary:27018" },
    { _id: 1, host: "shard2_secondary1:27018" },
    { _id: 2, host: "shard2_secondary2:27018" }
  ]
});
EOF
wait_for_primary shard2ReplSet "${SHARD2_HOSTS[@]}"

# 4) Wait for mongos
wait_for_host mongos:27017

# 5) Add shards & enable sharding
echo "⏳ Adding shards & enabling sharding..."
docker exec -i "$(docker compose ps -q mongos)" mongosh <<'EOF'
sh.addShard("shard1ReplSet/shard1_primary:27018,shard1_secondary1:27018,shard1_secondary2:27018");
sh.addShard("shard2ReplSet/shard2_primary:27018,shard2_secondary1:27018,shard2_secondary2:27018");
sh.enableSharding("ecommerce");
sh.shardCollection("ecommerce.orders", { order_id: "hashed" });
EOF

echo "🎉 Replica sets initiated and sharding configured successfully."
