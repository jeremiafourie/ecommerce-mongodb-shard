#!/usr/bin/env bash
set -euo pipefail

# Wait until a replica set primary is elected
wait_for_primary() {
  local svc=$1 port=$2 repl=$3
  local cid; cid=$(docker-compose ps -q "$svc")
  echo "⏳ Waiting for primary in ${repl}..."
  until docker exec -i "$cid" mongosh --quiet --port "$port" \
      --eval 'rs.isMaster().ismaster' | grep true >/dev/null; do
    sleep 2
  done
  echo "✅ ${repl} primary is elected."
}

# 1) Config server RS
echo "⏳ Initiating configReplSet..."
docker exec -i "$(docker-compose ps -q configsvr1)" mongosh --port 27019 <<'EOF'
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
wait_for_primary configsvr1 27019 configReplSet

# 2) Shard1 RS
echo "⏳ Initiating shard1ReplSet..."
docker exec -i "$(docker-compose ps -q shard1_primary)" mongosh --port 27018 <<'EOF'
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1_primary:27018" },
    { _id: 1, host: "shard1_secondary1:27018" },
    { _id: 2, host: "shard1_secondary2:27018" }
  ]
});
EOF
wait_for_primary shard1_primary 27018 shard1ReplSet

# 3) Shard2 RS
echo "⏳ Initiating shard2ReplSet..."
docker exec -i "$(docker-compose ps -q shard2_primary)" mongosh --port 27018 <<'EOF'
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2_primary:27018" },
    { _id: 1, host: "shard2_secondary1:27018" },
    { _id: 2, host: "shard2_secondary2:27018" }
  ]
});
EOF
wait_for_primary shard2_primary 27018 shard2ReplSet

# 4) Wait for mongos
echo "⏳ Waiting for mongos..."
until docker exec -i "$(docker-compose ps -q mongos)" mongosh --quiet \
    --eval 'db.adminCommand({ ping: 1 })' >/dev/null 2>&1; do
  sleep 2
done
echo "✅ Mongos is up."

# 5) Add shards & enable sharding
echo "⏳ Adding shards & enabling sharding..."
docker exec -i "$(docker-compose ps -q mongos)" mongosh <<'EOF'
sh.addShard("shard1ReplSet/shard1_primary:27018,shard1_secondary1:27018,shard1_secondary2:27018");
sh.addShard("shard2ReplSet/shard2_primary:27018,shard2_secondary1:27018,shard2_secondary2:27018");
sh.enableSharding("ecommerce");
sh.shardCollection("ecommerce.orders", { order_id: "hashed" });
EOF

echo "🎉 Replica sets initiated and sharding configured successfully."
