# Distributed MongoDB E-Commerce Demo

A fully containerized, sharded MongoDB cluster for an e-commerce use case. This repo demonstrates:

* ⚙️ **Sharded Replica Sets** via Docker Compose
* 🔧 **Bootstrap Script** (`init-replica.sh`) to initiate replica sets and enable sharding
* 📦 **Data Loader** (`data_loader.py`) to seed sample products, users & orders
* 🐢 **Chaos Engine** (`chaos_engine.sh`) to inject network latency for resilience testing

---

## 📖 Overview

This project spins up:

1. **Config Servers** (3 nodes)
2. **Shard 1** (primary + 2 secondaries)
3. **Shard 2** (primary + 2 secondaries)
4. A **mongos** query router

Once the cluster is up, you’ll run a script to wire up replica sets & shards, then load fake e-commerce data. An optional chaos script can introduce latency to test fault tolerance.

---

## 🚀 Quick Start

### Prerequisites

* Docker & Docker Compose
* Bash shell
* Python 3.8+ & pip

### 1. Clone & Launch Containers

```bash
git clone https://github.com/your-org/your-repo.git
cd your-repo
docker compose up -d
```

This will start all MongoDB nodes plus the `mongos` router.

### 2. Bootstrap Replica Sets & Sharding

Make the initializer executable and run it:

```bash
chmod +x init-replica.sh
./init-replica.sh
```

**What it does:**

1. Waits for config servers & shard nodes to be reachable
2. Initiates each replica set (`configReplSet`, `shard1ReplSet`, `shard2ReplSet`)
3. Adds shards to the cluster and enables sharding on the `ecommerce.orders` collection

### 3. Install Dependencies & Seed Data

```bash
pip install -r requirements.txt
python3 data_loader.py
```

* **`data_loader.py`** connects to `mongodb://mongos:27017` and populates the `ecommerce` database with:

  * 20 fake **products**
  * 10 fake **users**
  * 3 **orders** per user

### 4. (Optional) Run Chaos Testing

```bash
chmod +x chaos_engine.sh
./chaos_engine.sh
```

* **`chaos_engine.sh`** randomly injects 100 ms network delay on the `mongos` interface every 2–5 minutes to simulate latency.

---

## 📂 Repo Structure



* **Config Servers** (`configsvr1/2/3`): store metadata for sharding
* **Shard Servers** (`shardX_primary`, `shardX_secondary[1|2]`): hold actual data
* **Mongos**: single entry-point for all reads/writes
* **init-replica.sh**: runs MongoDB shell commands in each container
* **data\_loader.py**: uses Faker to generate realistic demo data
* **chaos\_engine.sh**: uses `tc qdisc` to add/remove latency

---

## 📝 License

This demo is released under the MIT License—see [LICENSE](LICENSE) for details.
