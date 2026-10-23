"""
generate_data.py
---------------------------------
Generates a realistic synthetic e-commerce dataset for the
Sales & Customer Analytics project (SQL + Power BI).

Outputs four CSV files into ../data:
    customers.csv      one row per customer
    products.csv       one row per product
    orders.csv         one row per order (order header)
    order_items.csv    one row per product line within an order

The data is fully synthetic and reproducible (fixed random seed),
so anyone cloning the repo can regenerate the exact same dataset:

    python scripts/generate_data.py

No external services or API keys are required. Only the Python
standard library plus numpy are used.
"""

import csv
import os
import random
from datetime import date, datetime, timedelta

import numpy as np

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
SEED = 42
N_CUSTOMERS = 2_000
N_PRODUCTS = 220
N_ORDERS = 24_000
START_DATE = date(2023, 1, 1)
END_DATE = date(2024, 12, 31)

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data")

random.seed(SEED)
np.random.seed(SEED)

# --------------------------------------------------------------------------
# Reference / lookup data
# --------------------------------------------------------------------------
COUNTRIES = [
    ("United States", 0.45), ("United Kingdom", 0.12), ("Germany", 0.09),
    ("France", 0.07), ("Canada", 0.07), ("Australia", 0.05),
    ("India", 0.05), ("Netherlands", 0.04), ("Spain", 0.03), ("Brazil", 0.03),
]

CATEGORIES = {
    "Electronics":   (80, 1200, ["Headphones", "Smartphone", "Laptop", "Tablet",
                                 "Smartwatch", "Camera", "Speaker", "Monitor"]),
    "Home & Kitchen":(15, 400,  ["Blender", "Coffee Maker", "Cookware Set",
                                 "Vacuum", "Air Fryer", "Toaster", "Lamp"]),
    "Apparel":       (12, 180,  ["T-Shirt", "Jeans", "Jacket", "Sneakers",
                                 "Dress", "Hoodie", "Cap"]),
    "Beauty":        (8, 120,   ["Serum", "Lipstick", "Perfume", "Moisturizer",
                                 "Shampoo", "Sunscreen"]),
    "Sports":        (20, 500,  ["Yoga Mat", "Dumbbell Set", "Bicycle",
                                 "Running Shoes", "Tent", "Backpack"]),
    "Books":         (6, 45,    ["Novel", "Cookbook", "Biography",
                                 "Textbook", "Comic", "Journal"]),
}

MARKETING_CHANNELS = [
    ("Organic Search", 0.28), ("Paid Search", 0.20), ("Social", 0.18),
    ("Email", 0.14), ("Direct", 0.12), ("Referral", 0.08),
]

ORDER_STATUSES = [("Delivered", 0.86), ("Returned", 0.07), ("Cancelled", 0.07)]

FIRST_NAMES = ["James","Mary","John","Patricia","Robert","Jennifer","Michael",
    "Linda","David","Elizabeth","Aarav","Priya","Wei","Mei","Luca","Sofia",
    "Noah","Emma","Liam","Olivia","Carlos","Ana","Yuki","Hana","Omar","Fatima"]
LAST_NAMES = ["Smith","Johnson","Williams","Brown","Jones","Garcia","Miller",
    "Davis","Rodriguez","Martinez","Patel","Shah","Chen","Wang","Rossi","Dubois",
    "Mueller","Nguyen","Kim","Silva","Santos","Khan","Tanaka","Ali","Lopez"]


def weighted_choice(pairs):
    """pairs = list of (value, weight); weights need not sum to 1."""
    values = [p[0] for p in pairs]
    weights = np.array([p[1] for p in pairs], dtype=float)
    weights /= weights.sum()
    return values[np.random.choice(len(values), p=weights)]


def random_date(start, end):
    delta_days = (end - start).days
    return start + timedelta(days=int(np.random.randint(0, delta_days + 1)))


# --------------------------------------------------------------------------
# Generate customers
# --------------------------------------------------------------------------
def make_customers():
    rows = []
    for cid in range(1, N_CUSTOMERS + 1):
        signup = random_date(START_DATE, END_DATE - timedelta(days=30))
        rows.append({
            "customer_id": cid,
            "first_name": random.choice(FIRST_NAMES),
            "last_name": random.choice(LAST_NAMES),
            "email": f"customer{cid}@example.com",
            "country": weighted_choice(COUNTRIES),
            "signup_date": signup.isoformat(),
            "acquisition_channel": weighted_choice(MARKETING_CHANNELS),
        })
    return rows


# --------------------------------------------------------------------------
# Generate products
# --------------------------------------------------------------------------
def make_products():
    rows = []
    pid = 1
    cat_names = list(CATEGORIES.keys())
    for _ in range(N_PRODUCTS):
        category = random.choice(cat_names)
        low, high, names = CATEGORIES[category]
        base = round(float(np.random.uniform(low, high)), 2)
        # cost is 55-80% of list price
        cost = round(base * float(np.random.uniform(0.55, 0.80)), 2)
        rows.append({
            "product_id": pid,
            "product_name": f"{random.choice(names)} {random.randint(100, 999)}",
            "category": category,
            "unit_price": base,
            "unit_cost": cost,
        })
        pid += 1
    return rows


# --------------------------------------------------------------------------
# Generate orders + order_items
# --------------------------------------------------------------------------
def make_orders(customers, products):
    orders = []
    items = []

    # Give customers unequal activity: a small share are "loyal" repeat buyers.
    # weights drawn from a power-law-ish distribution.
    cust_ids = [c["customer_id"] for c in customers]
    cust_signup = {c["customer_id"]: date.fromisoformat(c["signup_date"])
                   for c in customers}
    activity = np.random.pareto(1.5, size=len(cust_ids)) + 1
    activity /= activity.sum()

    order_item_id = 1
    for oid in range(1, N_ORDERS + 1):
        cid = int(np.random.choice(cust_ids, p=activity))
        # order date must be on/after signup; add seasonal lift in Nov/Dec
        odate = random_date(cust_signup[cid], END_DATE)
        # seasonal boost: resample toward Q4 sometimes
        if np.random.rand() < 0.18:
            yr = np.random.choice([2023, 2024])
            odate = date(yr, np.random.choice([11, 12]),
                         int(np.random.randint(1, 28)))
            if odate < cust_signup[cid]:
                odate = cust_signup[cid]

        status = weighted_choice(ORDER_STATUSES)
        n_lines = int(np.random.choice([1, 1, 1, 2, 2, 3, 4]))
        chosen = random.sample(products, n_lines)

        order_total = 0.0
        for prod in chosen:
            qty = int(np.random.choice([1, 1, 1, 2, 2, 3]))
            # occasional discount
            disc = float(np.random.choice([0, 0, 0, 0.05, 0.10, 0.15],
                                          p=[0.55, 0.15, 0.10, 0.08, 0.07, 0.05]))
            unit_price = prod["unit_price"]
            line_revenue = round(unit_price * qty * (1 - disc), 2)
            order_total += line_revenue
            items.append({
                "order_item_id": order_item_id,
                "order_id": oid,
                "product_id": prod["product_id"],
                "quantity": qty,
                "unit_price": unit_price,
                "discount": disc,
                "line_revenue": line_revenue,
            })
            order_item_id += 1

        orders.append({
            "order_id": oid,
            "customer_id": cid,
            "order_date": odate.isoformat(),
            "status": status,
            "order_total": round(order_total, 2),
        })

    # sort orders by date for realism
    orders.sort(key=lambda r: r["order_date"])
    return orders, items


def write_csv(path, rows, fieldnames):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("Generating customers ...")
    customers = make_customers()
    print("Generating products ...")
    products = make_products()
    print("Generating orders and order items ...")
    orders, items = make_orders(customers, products)

    write_csv(os.path.join(OUT_DIR, "customers.csv"), customers,
              ["customer_id", "first_name", "last_name", "email",
               "country", "signup_date", "acquisition_channel"])
    write_csv(os.path.join(OUT_DIR, "products.csv"), products,
              ["product_id", "product_name", "category",
               "unit_price", "unit_cost"])
    write_csv(os.path.join(OUT_DIR, "orders.csv"), orders,
              ["order_id", "customer_id", "order_date",
               "status", "order_total"])
    write_csv(os.path.join(OUT_DIR, "order_items.csv"), items,
              ["order_item_id", "order_id", "product_id",
               "quantity", "unit_price", "discount", "line_revenue"])

    print("\nDone. Row counts:")
    print(f"  customers    : {len(customers):>7,}")
    print(f"  products     : {len(products):>7,}")
    print(f"  orders       : {len(orders):>7,}")
    print(f"  order_items  : {len(items):>7,}")


if __name__ == "__main__":
    main()
