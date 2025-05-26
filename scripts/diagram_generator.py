#!/usr/bin/env python3
import yaml

# Load docker-compose.yml
with open("docker-compose.yml") as f:
    compose = yaml.safe_load(f)

services = compose.get("services", {})
# Map each service to a Mermaid node
mermaid = ["```mermaid", "graph LR"]
for name in services:
    mermaid.append(f"    {name}([{name}])")

# Define edges
edges = [
    ("Application↘", "mongos"),
    ("mongos", "configsvr1"),
    ("mongos", "shard1_primary"),
    ("mongos", "shard2_primary"),
]
# Insert a pseudo Application node for clarity
mermaid.insert(2, "    Application[\"Application Servers\"]")
for src, dst in edges:
    # Normalize names (no spaces)
    src_n = src.replace(" ", "_").replace("↘", "")
    dst_n = dst.replace(" ", "_")
    mermaid.append(f"    {src_n} --> {dst_n}")

mermaid.append("```")

# Write to Markdown
with open("cluster-topology.mmd", "w") as out:
    out.write("\n".join(mermaid))
print("Rendered cluster-topology.mmd")
