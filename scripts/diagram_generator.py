#!/usr/bin/env python3
import yaml
import sys

# 1) Load Compose file
try:
    with open("docker-compose.yml") as f:
        compose = yaml.safe_load(f)
except FileNotFoundError:
    print("❌ docker-compose.yml not found.", file=sys.stderr)
    sys.exit(1)

services = compose.get("services", {})

# 2) Build Mermaid lines
mermaid = [
    "```mermaid",
    "graph LR",
    "    Application[\"Application Servers\"]"
]
for name in services:
    mermaid.append(f"    {name}[\"{name}\"]")

edges = [
    ("Application", "mongos"),
    ("mongos", "configsvr1"),
    ("mongos", "shard1_primary"),
    ("mongos", "shard2_primary"),
]
for src, dst in edges:
    mermaid.append(f"    {src} --> {dst}")

mermaid.append("```")

# 3) Write output
with open("cluster-topology.mmd", "w") as out:
    out.write("\n".join(mermaid))

print("🎨 Rendered cluster-topology.mmd")
