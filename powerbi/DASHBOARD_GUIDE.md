# Power BI Dashboard — Build Guide

This guide walks you through building the dashboard in **Power BI Desktop**
(free, Windows). You will end up with a 4-page report. Save the finished file
as `powerbi/ecommerce_dashboard.pbix` and commit it.

> There are two ways to feed data into Power BI. Pick **Option A** if you have
> not set up PostgreSQL; pick **Option B** to show the "live SQL" version.

---

## 1. Load the data

### Option A — Import the CSVs (fastest, zero setup)
1. Open Power BI Desktop -> **Home -> Get data -> Text/CSV**.
2. Import all four files from the `data/` folder: `customers.csv`,
   `products.csv`, `orders.csv`, `order_items.csv`.
3. For each, click **Transform Data** and confirm column types
   (IDs = Whole Number, dates = Date, prices/revenue = Decimal Number,
   discount = Decimal Number).

### Option B — Connect to PostgreSQL (shows SQL skills end to end)
1. Run `sql/01_schema.sql`, `02_load_data.sql`, `03_views.sql` against a
   database called `ecommerce` (see the main README).
2. In Power BI: **Get data -> PostgreSQL database**, server `localhost`,
   database `ecommerce`.
3. Select the **views** (`vw_sales_detail`, `vw_monthly_revenue`,
   `vw_category_performance`, `vw_customer_rfm`, `vw_cohort_retention`).
   Letting the database do the aggregation is the "right" pattern to talk about.

---

## 2. Build the data model (relationships)

In **Model view**, create these relationships (drag field to field). If you
imported CSVs, Power BI may auto-detect some; verify they match:

| From (many side)            | To (one side)              | Cardinality |
|-----------------------------|----------------------------|-------------|
| `order_items.order_id`      | `orders.order_id`          | Many-to-one |
| `order_items.product_id`    | `products.product_id`      | Many-to-one |
| `orders.customer_id`        | `customers.customer_id`    | Many-to-one |
| `orders.order_date`         | `dim_date.date_key` *      | Many-to-one |

\* If you imported CSVs there is no `dim_date`. Create a date table instead:
**Modeling -> New table**:

```DAX
dim_date =
ADDCOLUMNS(
    CALENDAR(DATE(2023,1,1), DATE(2024,12,31)),
    "Year",        YEAR([Date]),
    "Month",       MONTH([Date]),
    "Month Name",  FORMAT([Date],"MMM"),
    "Year-Month",  FORMAT([Date],"YYYY-MM"),
    "Quarter",     "Q" & QUARTER([Date]),
    "Day of Week", FORMAT([Date],"ddd"),
    "Is Weekend",  WEEKDAY([Date],2) >= 6
)
```
Then relate `orders.order_date` -> `dim_date.Date` and mark `dim_date` as the
official date table (**Table tools -> Mark as date table**).

---

## 3. Add the DAX measures

Create a dedicated measures table (**Enter data**, name it `_Measures`, delete
the blank column) and add every measure from `MEASURES.md`. Keeping measures in
one table is a tidy convention interviewers like to see.

---

## 4. Build the four report pages

### Page 1 — Executive Overview
- **Cards** (top row): Total Revenue, Total Profit, Total Orders,
  Active Customers, Avg Order Value.
- **Line chart**: Revenue by `Year-Month` (axis = dim_date Year-Month).
- **Line/column combo**: Revenue (column) + MoM Growth % (line).
- **Slicers**: Year, Country, Category. Place them on every page or use a
  sync-slicers panel.

### Page 2 — Product & Category
- **Bar chart**: Revenue by Category (`vw_category_performance` or measure).
- **Matrix**: Category -> Product with Units Sold, Revenue, Margin %.
- **Card**: Overall Margin %.
- **Treemap** (optional): Revenue by Category.

### Page 3 — Customer Segmentation (RFM)
- **Clustered bar**: # Customers by `segment` (from `vw_customer_rfm`).
- **Stacked bar / 100% bar**: Revenue share by `segment`.
- **Table**: segment, customers, avg spend, % of revenue.
- **Insight callout** (text box): e.g. "Champions are ~29% of buyers but ~67%
  of revenue." (confirm the exact numbers from your data)

### Page 4 — Trends & Retention
- **Matrix heatmap**: rows = `cohort_month`, columns = `month_number`,
  values = active customers (conditional-format as a color scale).
- **Line chart**: New vs Returning revenue by month.
- **Column chart**: Return rate % by Category.

---

## 5. Polish and export
- Apply a consistent theme (**View -> Themes**), format currency, add titles.
- **File -> Save as** `powerbi/ecommerce_dashboard.pbix`.
- Export one screenshot of each page (**File -> Export -> PDF**, or snip each
  page) into `docs/images/` so the GitHub README can show the result.

---

## Talking points for interviews
- Star schema at **order-item grain**; `dim_date` drives time intelligence.
- Aggregation pushed into **SQL views** (Option B) vs. done in **DAX** — know
  the tradeoff (DB does heavy lifting, report stays light).
- RFM scoring with `NTILE(4)`; segment rules combine R/F/M.
- Cohort retention = first-order month vs. active month, offset in months.
- Returned/Cancelled orders excluded from revenue so KPIs = realised net sales.
