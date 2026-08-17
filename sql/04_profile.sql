-- Per-step query profiling, straight out of the engine.
--
-- Exasol has no execution hints, no manual index types, and no statistics to
-- maintain — the optimizer tunes itself. This is how you see what it decided:
-- turn profiling on for the session, run the query, flush, and read the parts.
--
-- The rows come from EXA_STATISTICS, which the exasqllog service writes
-- continuously. Nothing here needs to be installed or configured first.

ALTER SESSION SET PROFILE = 'ON';

-- A mart-shaped query: fact joined to two dimensions, grouped.
SELECT c.CATEGORY_NAME,
       r.REGION_NAME,
       SUM(f.NET_REVENUE) AS REVENUE
  FROM SALES.FCT_ORDERS   f
  JOIN SALES.DIM_CATEGORY c ON c.CATEGORY_KEY = f.CATEGORY_KEY
  JOIN SALES.DIM_REGION   r ON r.REGION_KEY   = f.REGION_KEY
 GROUP BY 1, 2
 ORDER BY 3 DESC;

FLUSH STATISTICS;
ALTER SESSION SET PROFILE = 'OFF';

-- One row per execution step: what it scanned, how many rows came out, how long
-- it took, and how much temporary RAM it needed.
SELECT PART_ID,
       PART_NAME,
       OBJECT_NAME,
       OBJECT_ROWS,
       OUT_ROWS,
       DURATION AS SECONDS,
       ROUND(TEMP_DB_RAM_PEAK, 1) AS TEMP_RAM_MB
  FROM EXA_STATISTICS.EXA_DBA_PROFILE_LAST_DAY
 WHERE SESSION_ID = CURRENT_SESSION
 ORDER BY STMT_ID, PART_ID;
