# DAX Measures

Paste each of these into the `_Measures` table in Power BI Desktop
(**Modeling -> New measure**). They assume the CSV-import model where the fact
table is `order_items`, with related `orders`, `products`, `customers`, and a
`dim_date` date table. Adjust table/column names if you used the SQL views.

> "Delivered only" measures filter out Returned / Cancelled orders so KPIs
> reflect realised net sales, matching the SQL views.

```DAX
-- Core revenue / profit -------------------------------------------------------

Total Revenue =
CALCULATE ( SUM ( order_items[line_revenue] ), orders[status] = "Delivered" )

Total Cost =
CALCULATE (
    SUMX ( order_items, order_items[quantity] * RELATED ( products[unit_cost] ) ),
    orders[status] = "Delivered"
)

Total Profit = [Total Revenue] - [Total Cost]

Profit Margin % =
DIVIDE ( [Total Profit], [Total Revenue] )

-- Volume ----------------------------------------------------------------------

Total Orders =
CALCULATE ( DISTINCTCOUNT ( orders[order_id] ), orders[status] = "Delivered" )

Units Sold =
CALCULATE ( SUM ( order_items[quantity] ), orders[status] = "Delivered" )

Active Customers =
CALCULATE ( DISTINCTCOUNT ( orders[customer_id] ), orders[status] = "Delivered" )

Avg Order Value =
DIVIDE ( [Total Revenue], [Total Orders] )

-- Time intelligence -----------------------------------------------------------

Revenue Prev Month =
CALCULATE ( [Total Revenue], DATEADD ( dim_date[Date], -1, MONTH ) )

MoM Growth % =
DIVIDE ( [Total Revenue] - [Revenue Prev Month], [Revenue Prev Month] )

Revenue YTD =
TOTALYTD ( [Total Revenue], dim_date[Date] )

Revenue Running Total =
CALCULATE (
    [Total Revenue],
    FILTER ( ALLSELECTED ( dim_date[Date] ), dim_date[Date] <= MAX ( dim_date[Date] ) )
)

-- Returns ---------------------------------------------------------------------

Returned Orders =
CALCULATE ( DISTINCTCOUNT ( orders[order_id] ), orders[status] = "Returned" )

All Orders =
DISTINCTCOUNT ( orders[order_id] )

Return Rate % =
DIVIDE ( [Returned Orders], [All Orders] )

-- Customer mix ----------------------------------------------------------------

Revenue per Customer =
DIVIDE ( [Total Revenue], [Active Customers] )
```

### Formatting tips
- Set `Total Revenue`, `Total Profit`, `Total Cost`, `Avg Order Value`,
  `Revenue per Customer` to **Currency**.
- Set `Profit Margin %`, `MoM Growth %`, `Return Rate %` to **Percentage**
  (1 decimal).
- Use `MoM Growth %` as a line on the combo chart against `Total Revenue`.
