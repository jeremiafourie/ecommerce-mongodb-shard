#!/usr/bin/env python3
import os
import time
from pymongo import MongoClient, errors
from faker import Faker

MONGO_URI = os.getenv("MONGO_URI", "mongodb://mongos:27017")
fake = Faker()

# 1) Wait for MongoDB availability
for attempt in range(1, 11):
    try:
        client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=2000)
        client.admin.command('ping')
        print("✅ Connected to MongoDB")
        break
    except errors.ServerSelectionTimeoutError:
        print(f"⏳ Waiting for MongoDB ({attempt}/10)...")
        time.sleep(2)
else:
    raise RuntimeError(f"❌ Failed to connect to MongoDB at {MONGO_URI}")

db = client.ecommerce

# 2) Clear existing data
db.products.delete_many({})
db.users.delete_many({})
db.orders.delete_many({})

# 3) Seed products
products = []
for _ in range(20):
    products.append({
        "sku": fake.unique.ean13(),
        "name": fake.word().title(),
        "description": fake.sentence(),
        "price": round(fake.pyfloat(left_digits=3, right_digits=2, min_value=10, max_value=500), 2),
        "categories": [fake.word() for _ in range(2)],
    })
db.products.insert_many(products)

# 4) Seed users
users = []
for _ in range(10):
    users.append({
        "email": fake.unique.email(),
        "name": fake.name(),
        "addresses": [fake.address()],
    })
db.users.insert_many(users)

# 5) Seed orders
orders = []
for user in db.users.find():
    for _ in range(3):
        item = fake.random_element(products)
        orders.append({
            "user_id": user["_id"],
            "order_date": fake.date_time_this_year(),
            "items": [{
                "product_id": item["_id"],
                "quantity": fake.random_int(1, 5),
                "unit_price": item["price"]
            }],
            "status": fake.random_element(["placed", "shipped", "delivered"]),
            "total": 0
        })
for o in orders:
    o["total"] = sum(i["quantity"] * i["unit_price"] for i in o["items"])
db.orders.insert_many(orders)

print("🎉 Seed data loaded.")
