# Ask your data

Now ask with the MCP client of choice (Claude Code, Codex, Cursor) at the local Exasol
and ask in plain English. With MCP connected to your DWH, it will find the answers with
actual queries of the database.

Here some example questions:

**Business**

1. Which product category generated the most revenue, and how much of it was given away as discount?
2. Show me the monthly revenue trend and point out any month that breaks the pattern.
3. Which region has the best customer rating, and does slower delivery explain the worst one?
4. Who are my top 10 customers by revenue, and how long has each been active?
5. Is there a category that sells well in one region but not the others?
6. Do my High-value customers buy different categories than the Low segment?
7. Does paying by COD correlate with lower ratings or slower delivery?
8. How much revenue sits in orders dated in the future, and should I exclude them?

**About the database itself** — the same interface, pointed at the engine:

9. What has been running against this database in the last day, and what was slowest?
10. Which indexes exist on the SALES schema, and which of them did I create? (Answer: none — Exasol built all of them itself.)

