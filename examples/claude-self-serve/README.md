# Self-Serve Analytics with Claude, BigQuery, and MCP

This directory contains the configuration and context files required to build a **"Zero-Context" Analytics Agent**.

This setup allows the Claude Desktop App to query your `growthcues-core` data directly in BigQuery, using the metric definitions baked into the database schema via dbt.

> 📖 **Read the full tutorial:** [The Zero-Context Dashboard: Building Self-Serve GTM Analytics](https://growthcues.com/blog/self-serve-analytics-claude-mcp)

## Prerequisites

1.  **Claude Desktop App** installed.
2.  **Google Cloud CLI** installed and authenticated (`gcloud auth application-default login`).
3.  **GrowthCues Core** dbt models deployed to a BigQuery project.
4.  **Google MCP Toolbox** binary installed.

## Setup Instructions

### 1. Configure the MCP Server

Locate your Claude configuration file:

- **Mac:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

Add the BigQuery configuration. Replace `PROJECT_ID` with your Google Cloud Project ID and update the path to your `toolbox` binary.

```json
{
  "mcpServers": {
    "bigquery": {
      "command": "/path/to/toolbox",
      "args": ["--prebuilt", "bigquery", "--stdio"],
      "env": {
        "BIGQUERY_PROJECT": "YOUR_PROJECT_ID"
      }
    }
  }
}
```

### 2. The "Soft System Prompt"

The file `growthcues_context.md` in this directory acts as a lightweight guide for Claude. It doesn't contain metric logic (that lives in the database); it simply points Claude to the right tables and instructs it to **read column metadata** before querying.

**Usage:**

1. Open a new chat in Claude Desktop.
2. Drag and drop `growthcues_context.md` into the chat window.
3. Start asking questions.

## How It Works

1. **Context as Code:** `growthcues-core` uses dbt's `persist_docs` feature to push rich metric definitions (e.g., "[Definition] Churn Risk") into BigQuery column metadata.
2. **The Protocol:** The MCP server gives Claude read-only access to query these tables and inspect the metadata.
3. **No Hallucinations:** Because Claude reads the metadata descriptions _before_ writing SQL, it understands your specific business logic without needing a massive system prompt.

## Example Queries

Once connected, try asking natural language questions:

- _"What is the daily active user trend for the last 30 days?"_
- _"Which accounts indicate high churn risk?"_
- _"Show me the top 5 champions to contact for upsell based on user engagement."_
