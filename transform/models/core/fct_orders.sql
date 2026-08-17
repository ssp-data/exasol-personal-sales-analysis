{{ config(
    materialized='table',
    distribute_by='customer_key'
) }}

-- Order fact. Resolves the three dimension keys and keeps the measures.
--
-- `distribute_by` is Exasol's MPP knob: it co-locates rows with the same
-- customer_key on the same node, turning global joins into local ones.
--
-- Honest caveat: it does nothing here. This is a single node, and all three
-- dimensions are far below the 100,000-row REPLICATION_BORDER, so Exasol would
-- replicate them to every node and join locally regardless. It is here because
-- it is the same DDL you would ship to a cluster with a fact table big enough
-- to care — the point is that scaling out changes no SQL, not that this
-- particular key earns its keep at 5,000 rows.

select
    f.order_id,
    d_cus.customer_key,
    d_cat.category_key,
    d_reg.region_key,

    f.order_date,
    f.order_month,
    f.order_year,
    f.payment_method,

    f.quantity,
    f.unit_price,
    f.discount,
    f.gross_revenue,
    f.net_revenue,
    f.discount_amount,
    f.delivery_days,
    f.customer_rating,
    f.is_future_order

from {{ ref('stg_sales_orders') }} f
join {{ ref('dim_customer') }} d_cus on d_cus.customer_key = f.customer_id
join {{ ref('dim_category') }} d_cat on d_cat.category_name = f.product_category
join {{ ref('dim_region') }}   d_reg on d_reg.region_name   = f.region
