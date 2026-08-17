{{ config(materialized='table') }}

-- Product category dimension. Surrogate key from a deterministic window
-- function, so a rebuild always produces the same keys.

select
    row_number() over (order by product_category)  as category_key,
    product_category                               as category_name
from (select distinct product_category from {{ ref('stg_sales_orders') }})
