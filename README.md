# Sales analytics on Exasol Personal

A CSV that was lying on disk, turned into queryable data marts you can ask
questions about in plain English. No BI tool, no cloud account, no license key.

```bash
make all     # ~10 seconds, from nothing to six data marts
make ask     # example questions and the mart catalogue
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

A minimal [declarative data stack](https://www.ssp.sh/blog/rise-of-declarative-data-stack/).
One config file describes the whole thing; an engine compiles it; Exasol runs it.

```
stack.yaml  ──►  engine/render.py  ──►  generated SQL + dbt models  ──►  Exasol  ──►  MCP  ──►  you
  config            the engine            declarative code             runtime      interface
```

`stack.yaml` is the only file with business logic in it. Sources, metric
definitions, mart grains, and the questions worth asking all live there. If a
number looks wrong, you fix the config and re-render — you never edit generated
SQL. That discipline is borrowed from data warehouse automation tools, and it is
what makes the stack reproducible instead of merely automated.

## Requirements

- The [Exasol Personal Local Starter Kit](https://github.com/exasol-labs/exasol-personal-local-starterkit)
  running locally (`exakit status` should say the database is up)
- [`uv`](https://docs.astral.sh/uv/)

That's it. `make all` handles the Python environment itself.

## Layout

| Path | What it is |
|---|---|
| `stack.yaml` | **The config.** Source, staging, metrics, marts, questions. |
| `engine/render.py` | **The engine.** Compiles the config into everything below. |
| `build/*.sql` | Generated: raw DDL, grants, verification checks. |
| `transform/` | Generated: a dbt-exasol project — staging view + six mart tables. |
| `serve/questions.md` | Generated: the mart catalogue, the metric definitions, and example questions. |
| `Makefile` | The runner. `make help` lists every step. |

## The pipeline

| Step | What happens |
|---|---|
| `make render` | `stack.yaml` → DDL, dbt models, docs. Nothing touches the database. |
| `make load` | Creates `RAW_SALES.SALES_ORDERS`, strips the file's CRLF line endings, bulk-loads 5,000 rows via `exapump`. |
| `make transform` | `dbt build` — one typed staging view, six mart tables, eight tests. Runs in ~1.5s. |
| `make grants` | `GRANT SELECT` to `mcp_readonly`. The AI reads; it can never write. |
| `make verify` | Asserts row counts survive staging and that mart revenue still equals staging revenue. |
| `make ask` | Prints the mart catalogue, the metric definitions, and example questions. |

Asking needs an MCP client with the `exasol` server connected — the starter kit
installer wires this up, and `claude mcp list` should show
`exasol: ... ✔ Connected`. The server logs in as `mcp_readonly`, so the agent can
read every mart and change nothing.

Everything is idempotent. `make clean && make all` gets you back to exactly the
same place — the stack is disposable, only the source CSV is precious.

## Why the metrics live in the config

`make transform` pushes every metric definition into the Exasol catalog as a
column comment, so the MCP server hands them to the AI along with the schema:

```
AVG_ORDER_VALUE   Net revenue per order (ROUND(SUM(net_revenue) / NULLIF(COUNT(DISTINCT order_id), 0), 2))
DISCOUNT_AMOUNT   Total discount given (SUM(discount_amount))
```

The model does not have to guess what "revenue" means, and it cannot quietly
invent a second definition — the number and its definition ship together. That
is the whole reason to keep a semantic layer in config rather than in a
dashboard.

## Changing it

Add a mart by adding six lines to `stack.yaml`:

```yaml
  - name: mart_rating_by_category
    description: Where the unhappy customers are.
    dimensions: [product_category]
    metrics: [avg_rating, avg_delivery_days, orders]
    order_by: "avg_rating ASC"
```

Then `make render transform`. New model, new table, new documented metrics,
visible to the AI on the next question.

## Scaling up

Nothing here is local-only. The same `stack.yaml`, the same dbt project, and the
same SQL run against a cloud deployment — you change the DSN in
`transform/profiles.yml` and point `exapump` at a different profile:

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
about it; that is question 7.
