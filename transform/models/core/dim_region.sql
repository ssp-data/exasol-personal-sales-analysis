{{ config(materialized='table') }}

-- Region dimension. Same deterministic surrogate-key pattern as dim_category.

select
    row_number() over (order by region)  as region_key,
    region                               as region_name
from (select distinct region from {{ ref('stg_sales_orders') }})
