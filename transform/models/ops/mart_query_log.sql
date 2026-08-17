{{ config(materialized='view') }}

-- Observability, for free.
--
-- The exasqllog service writes EXA_STATISTICS continuously — no agent to
-- install, no exporter, no retention config. This view just makes the last
-- day of it queryable by the AI alongside the business marts, so "what has
-- been hitting my database, and what was slow?" is the same kind of question
-- as "which category sold best?".

select
    session_id,
    stmt_id,
    command_name,
    command_class,
    start_time,
    duration                          as seconds,
    cpu                               as cpu_pct,
    round(temp_db_ram_peak, 1)        as temp_ram_mb,
    row_count                         as rows_returned,
    consumer_group,
    success
from {{ source('exa_statistics', 'exa_sql_last_day') }}
