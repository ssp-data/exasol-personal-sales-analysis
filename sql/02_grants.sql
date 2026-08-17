-- Security as code. The agent reads, and can never write.
--
-- The starter kit's mcp_readonly user is what the MCP server logs in as. It is
-- the database, not a system prompt, that enforces this.

GRANT SELECT ON SCHEMA RAW_SALES TO mcp_readonly;
GRANT SELECT ON SCHEMA SALES     TO mcp_readonly;
