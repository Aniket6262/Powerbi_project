# E-Commerce Sales & Customer Analytics (SQL + Power BI)

An end-to-end analytics project that takes a raw e-commerce dataset, models it
into a SQL star-schema warehouse, answers real business questions with SQL, and
visualises the results in an interactive Power BI dashboard.

**Stack:** PostgreSQL · SQL · Power BI (DAX) · Python (data generation)

---

## Business questions answered

- How are **revenue and profit** trending month over month?
- Which **product categories** and products drive the most revenue and the best margins?
- Who are the **high-value customers** (RFM segmentation), and what share of revenue do they represent?
- How well do monthly **acquisition cohorts retain** over time?
- How does revenue split between **new vs. returning** customers and across **acquisition channels**?
- Where are **returns** concentrated?

## Headline results (from the included dataset)

| Metric | Value |
|---|---|
| Total revenue (delivered) | ~$14.2M |
| Total profit | ~$4.6M |
| Delivered orders | 20,620 |
| Active customers | 1,984 |
| Average order value | ~$690 |
| **Champions segment** | ~29% of customers → **~67% of revenue** |

*(Exact figures regenerate deterministically from the seed; confirm them in your run.)*

---

## Architecture

```
CSV data  ──►  PostgreSQL star schema  ──►  SQL views  ──►  Power BI dashboard
(Python)       (fact + dimensions)         (aggregation)    (DAX + visuals)
```

### Data model (star schema)

```
            dim_date
                │
dim_customer ─ orders ─ fact_order_items ─ dim_product
```

- `fact_order_items` — grain: one row per product line in an order
- `orders` — order header (status, customer, date)
- `dim_customer`, `dim_product`, `dim_date` — dimensions

---

## Repository structure

```
ecommerce-sales-analytics/
├── data/                     # generated CSV dataset
│   ├── customers.csv
│   ├── products.csv
│   ├── orders.csv
│   └── order_items.csv
├── scripts/
│   └── generate_data.py      # reproducible dataset generator (seed = 42)
├── sql/
│   ├── 01_schema.sql         # star-schema DDL + indexes
│   ├── 02_load_data.sql      # \copy loads + dim_date generation
│   ├── 03_views.sql          # BI-facing reporting views
│   └── 04_analysis_queries.sql  # 8 standalone analytical queries
├── powerbi/
│   ├── DASHBOARD_GUIDE.md    # step-by-step build guide (4 pages)
│   ├── MEASURES.md           # all DAX measures to paste in
│   └── ecommerce_dashboard.pbix   # (you add this after building it)
├── docs/
│   └── images/               # dashboard screenshots for this README
├── requirements.txt
├── .gitignore
└── LICENSE
```

---

## How to run it

### 1. (Optional) Regenerate the dataset
```bash
pip install -r requirements.txt
python scripts/generate_data.py
```
The CSVs are already committed, so this is only needed to recreate them.

### 2. Build the SQL warehouse (PostgreSQL)
```bash
createdb ecommerce
psql -d ecommerce -f sql/01_schema.sql
psql -d ecommerce -f sql/02_load_data.sql     # run from the repo root
psql -d ecommerce -f sql/03_views.sql
psql -d ecommerce -f sql/04_analysis_queries.sql   # see the query outputs
```

### 3. Build the dashboard
Follow `powerbi/DASHBOARD_GUIDE.md`. You can either import the CSVs directly or
connect Power BI to the PostgreSQL views. Save the result as
`powerbi/ecommerce_dashboard.pbix` and drop page screenshots into `docs/images/`.

---

## Dashboard pages

1. **Executive Overview** — KPI cards, revenue trend, MoM growth
2. **Product & Category** — category revenue, margins, product matrix
3. **Customer Segmentation** — RFM segments and their revenue share
4. **Trends & Retention** — cohort retention heatmap, new vs returning, returns

*(Add screenshots here once built:)*

<!-- ![Overview](docs/images/overview.png) -->

---

## Notes
- The dataset is **fully synthetic** and generated locally — no real customer data.
- Revenue KPIs count **Delivered** orders only; Returned/Cancelled are excluded.
- Built as a portfolio project to demonstrate SQL data modeling, analytical
  querying, and Power BI reporting.
