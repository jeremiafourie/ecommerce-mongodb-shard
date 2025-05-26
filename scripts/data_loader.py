# scripts/data_loader.py
#!/usr/bin/env python3
from faker import Faker
from pymongo import MongoClient
import os

fake = Faker()
client = MongoClient(os.getenv("MONGO_URI", "mongodb://mongos:27017"))
db = client.ecommerce

# Clear existing data
db.products.delete_many({})
db.users.delete_many({})
db.orders.delete_many({})

# Seed products
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

# Seed users
users = []
for _ in range(10):
    user = {
        "email": fake.unique.email(),
        "name": fake.name(),
        "addresses": [fake.address()],
    }
    users.append(user)
db.users.insert_many(users)

# Seed orders
orders = []
for user in db.users.find():
    for _ in range(3):
        orders.append({
            "user_id": user["_id"],
            "order_date": fake.date_time_this_year(),
            "items": [
                {
                    "product_id": fake.random_element(products)["_id"],
                    "quantity": fake.random_int(1, 5),
                    "unit_price": fake.random_element(products)["price"]
                }
            ],
            "status": fake.random_element(["placed", "shipped", "delivered"]),
            "total": 0
        })
# Calculate totals
for o in orders:
    o["total"] = sum(item["quantity"] * item["unit_price"] for item in o["items"])
db.orders.insert_many(orders)
print("Seed data loaded.")