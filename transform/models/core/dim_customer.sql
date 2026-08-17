{{ config(materialized='table') }}

-- Customer dimension with a lifetime-value segment. The segment is an
-- attribute, not a metric: it describes the customer, and marts group by it.

select
    customer_id                                             as customer_key,
    min(order_date)                                         as first_order_date,
    max(order_date)                                         as last_order_date,
    count(distinct order_id)                                as lifetime_orders,
    cast(sum(net_revenue) as decimal(18,2))                 as lifetime_revenue,
    case
        when sum(net_revenue) >= 10000 then 'High'
        when sum(net_revenue) >=  5000 then 'Medium'
        else 'Low'
    end                                                     as customer_segment
from {{ ref('stg_sales_orders') }}
group by 1
