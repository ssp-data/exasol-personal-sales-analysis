{{ config(materialized='view') }}

-- Typed and enriched order lines. One row per order.
-- Raw stays exactly as loaded; every interpretation happens here, in the open.

select
    order_id,
    customer_id,
    product_category,
    region,
    payment_method,
    quantity,
    unit_price,
    discount,
    delivery_days,
    customer_rating,

    to_date(order_date, 'MM/DD/YYYY')                        as order_date,
    date_trunc('month', to_date(order_date, 'MM/DD/YYYY'))   as order_month,
    extract(year from to_date(order_date, 'MM/DD/YYYY'))     as order_year,

    round(quantity * unit_price, 2)                          as gross_revenue,
    revenue                                                  as net_revenue,
    round(quantity * unit_price - revenue, 2)                as discount_amount,

    -- The dataset is synthetic and runs to 2035. Flag it rather than hide it.
    case when to_date(order_date, 'MM/DD/YYYY') > current_date
         then true else false end                            as is_future_order

from {{ source('raw', 'sales_orders') }}
