#!/bin/bash
# init-replica.sh
# Initializes config servers, shard replica sets, and enables sharding

set -e

# 1) Initiate config server replica set
docker exec -i $(docker-compose ps -q configsvr1) mongosh --port 27019 <<'EOF'
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configsvr1:27019" },
    { _id: 1, host: "configsvr2:27019" },
    { _id: 2, host: "configsvr3:27019" }
  ]
})
EOF

# 2) Initiate shard1 replica set
docker exec -i $(docker-compose ps -q shard1_primary) mongosh --port 27018 <<'EOF'
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1_primary:27018" },
    { _id: 1, host: "shard1_secondary1:27018" },
    { _id: 2, host: "shard1_secondary2:27018" }
  ]
})
EOF

# 3) Initiate shard2 replica set
docker exec -i $(docker-compose ps -q shard2_primary) mongosh --port 27018 <<'EOF'
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2_primary:27018" },
    { _id: 1, host: "shard2_secondary1:27018" },
    { _id: 2, host: "shard2_secondary2:27018" }
  ]
})
EOF

# 4) Add shards to the cluster and enable sharding
docker exec -i $(docker-compose ps -q mongos) mongosh <<'EOF'
sh.addShard("shard1ReplSet/shard1_primary:27018,shard1_secondary1:27018,shard1_secondary2:27018")
sh.addShard("shard2ReplSet/shard2_primary:27018,shard2_secondary1:27018,shard2_secondary2:27018")
sh.enableSharding("ecommerce")
sh.shardCollection("ecommerce.orders", { order_id: "hashed" })
EOF

echo "✅ Replica sets initiated and sharding configured."
