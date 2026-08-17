# Sales analytics on Exasol Personal

A CSV that was lying on disk, turned into a star schema and queryable data marts
you can ask questions about in plain English. No BI tool, no cloud account, no
license key.

```bash
make all      # ~10 seconds, from nothing to a star schema and seven marts
make ask      # example questions and the mart catalogue
make profile  # what the engine actually did with your query
```

Then open your agent of choice — Claude Code, Codex, Cursor — with the `exasol`
MCP server connected, and ask:

> Which product category generated the most revenue, and how much of it was given away as discount?

```
Electronics   $1,829,899   discount given: $393,413   1,777 orders   AOV $1,029.77
Clothing      $1,531,932   discount given: $355,200   1,531 orders   AOV $1,000.61
Home            $982,084   discount given: $214,134     969 orders   AOV $1,013.50
Beauty          $765,861   discount given: $167,499     723 orders   AOV $1,059.28
```

## What this is

A minimal [declarative data stack](https://www.ssp.sh/blog/rise-of-declarative-data-stack/):
metrics and marts are declared once in `stack.yaml` and compiled into dbt models.

```
stack.yaml  ──►  engine/render.py  ──►  dbt models  ──►  Exasol  ──►  MCP  ──►  you
 metrics +          the engine          marts, joined      runtime    interface
 marts                                  against the star
```

Only the marts are generated, and deliberately so. Marts are the thing that
repeats — a grain plus a list of metrics — so a compiler earns its keep there
and nowhere else. The raw DDL, the staging view and the star schema are ordinary
hand-written SQL, because generating a file you write once costs more than it
saves. The engine is 141 lines.

If a number looks wrong you fix `stack.yaml` and re-render; you never edit a
generated model. That discipline is borrowed from data warehouse automation, and
it is what makes the stack reproducible rather than merely automated.

## Requirements

- The [Exasol Personal Local Starter Kit](https://github.com/exasol-labs/exasol-personal-local-starterkit)
  running locally (`exakit status` should say the database is up)
- [`uv`](https://docs.astral.sh/uv/)

`make all` handles the Python environment itself.

## Layout

| Path | What it is |
|---|---|
| `stack.yaml` | **The config.** The star, the metrics, the marts. |
| `engine/render.py` | **The engine.** Turns a grain + metrics into a dbt model that joins the star. |
| `sql/*.sql` | Hand-written: raw DDL, grants, verification, profiling. |
| `transform/models/staging/` | Hand-written: one typed view over the raw table. |
| `transform/models/core/` | Hand-written: `fct_orders` + three dimensions. |
| `transform/models/marts/` | **Generated** from `stack.yaml`. |
| `transform/models/ops/` | Hand-written: query log over `EXA_STATISTICS`. |
| `serve/questions.md` | The mart catalogue and questions worth asking. |
| `Makefile` | The runner. `make help` lists every step. |

## The pipeline

| Step | What happens |
|---|---|
| `make render` | `stack.yaml` → dbt mart models. Nothing touches the database. |
| `make load` | Creates `RAW_SALES.SALES_ORDERS`, strips the file's CRLF line endings, bulk-loads 5,000 rows via `exapump`. |
| `make transform` | `dbt build` — staging view, star schema, seven marts, a query log, 36 tests. ~2.5s. |
| `make grants` | `GRANT SELECT` to `mcp_readonly`. The AI reads; it can never write. |
| `make verify` | Asserts no rows lost, no orphan keys, mart totals match the fact — then lists the indexes Exasol built for itself. |
| `make profile` | Turns on session profiling, runs a mart query, prints the execution plan with real timings. |

Everything is idempotent. `make clean && make all` gets you back to the same
place — the stack is disposable, only the source CSV is precious.

## What this actually shows about Exasol

Three things you can see happening, not just read about:

**1. It tunes itself.** There is no `CREATE INDEX` anywhere in this project.
After `make all`, `make verify` prints:

```
INDEX_SCHEMA  INDEX_TABLE   INDEX_TYPE  BYTES
SALES         DIM_CATEGORY  GLOBAL       2267
SALES         DIM_CUSTOMER  GLOBAL       5096
SALES         DIM_REGION    GLOBAL       2267
SALES         FCT_ORDERS    LOCAL        5185
...
```

Seven indexes the optimizer decided it wanted while running the joins, created
during query execution, and dropped again after five unused weeks. No hints, no
`ANALYZE`, no statistics to maintain.

**2. You can see inside a query.** `make profile` turns on session profiling and
reads `EXA_STATISTICS`:

```
PART_ID  PART_NAME          OBJECT_NAME   OBJECT_ROWS  OUT_ROWS  SECONDS
2        SCAN               DIM_CATEGORY            4         4    0.000
3        JOIN               FCT_ORDERS           5000      5000    0.000
4        JOIN               DIM_REGION              4      5000    0.000
5        GROUP BY           tmp_subselect0          0        16    0.002
6        SORT               tmp_subselect0         16        16    0.002
```

Nothing to install — the `exasqllog` service writes those statistics
continuously, whether you look at them or not. `SALES.MART_QUERY_LOG` exposes the
same source to the AI, so "what was slow yesterday?" is the same kind of question
as "which category sold best?".

**3. The semantic layer lives in the database.** `dbt build` runs with
`persist_docs`, which pushes every metric definition from `stack.yaml` into the
Exasol catalog as a column comment. The MCP server hands them to the agent along
with the schema:

```
AVG_ORDER_VALUE   Net revenue per order (ROUND(SUM(f.net_revenue) / NULLIF(COUNT(DISTINCT f.order_id), 0), 2))
DISCOUNT_AMOUNT   Total discount given (SUM(f.discount_amount))
```

The model does not have to guess what "revenue" means, and it cannot quietly
invent a second definition. The number and its definition ship together.

`fct_orders` also carries `distribute_by='customer_key'`. It does nothing here —
single node, and every dimension is far below the 100,000-row
`REPLICATION_BORDER`, so Exasol replicates them and joins locally anyway. It is
in the model because it is the same DDL you would ship to a cluster: scaling out
changes no SQL.

Money is `DECIMAL`, never `DOUBLE` — including derived metrics like
`avg_order_value`, which needs an explicit `CAST` because division promotes to
`DOUBLE`. Exasol's
[performance best practices](https://docs.exasol.com/db/latest/performance/best_practices.htm)
are worth reading before you write the metric layer, not after.

## Changing it

Add a mart with five lines in `stack.yaml`:

```yaml
  - name: mart_rating_by_category
    description: Where the unhappy customers are.
    dimensions: [product_category]
    metrics: [avg_rating, avg_delivery_days, orders]
    order_by: "avg_rating ASC"
```

`make render transform`. The engine works out that `product_category` needs a
join to `dim_category`, writes the model, documents every column with the
metric's own SQL, and the agent can answer questions about it on the next turn.

## Scaling up

Nothing here is local-only. The same `stack.yaml`, the same dbt project, the same
SQL run against a cloud deployment — change the DSN in `transform/profiles.yml`
and point `exapump` at a different profile:

```bash
exasol install aws        # or azure, exoscale, stackit
```

The local container and the cloud cluster are the same engine, so there is no
migration and no dialect to port. You start on a laptop because it is fast, not
because it is a toy.

## Data

[E-Commerce Sales Performance Analysis](https://www.kaggle.com/datasets/srisyra02/e-commerce-sales-performance-analysis)
— 5,000 orders, 12 columns. It is synthetic: order dates run to 2035, which the
staging view flags as `is_future_order` rather than silently hiding. Ask the AI
about it; that is question 8.
