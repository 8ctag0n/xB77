# MCP Integration: The Universal Interface

xB77 is built on the **Model Context Protocol (MCP)**, an open standard that enables AI models to interact with external tools and data sources seamlessly. 

## Why MCP?
- **Model Agnostic:** Whether you use Claude, GPT-4, or a local Llama model, the interface remains the same.
- **Strict Security:** Tools are explicitly defined. The LLM cannot execute arbitrary code; it can only request execution of validated financial tools.
- **Context Awareness:** The agent provides real-time state snapshots (balance, treasury efficiency, latest receipts) directly into the LLM's context window.

## Available Tools
The xB77 MCP Server exposes the following core capabilities:
- `agent.pay`: Executes a payment with autonomous strategy selection.
- `agent.strategy.evaluate`: Pre-screens a transaction for risk and compliance.
- `agent.status`: Retrieves the current financial health of the agent.
- `agent.audit.report`: Generates a ZK-certified selective disclosure for a specific receipt.
- `cfo.treasury.rebalance`: Triggers autonomous liquidity management between rails.