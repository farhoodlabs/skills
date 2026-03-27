---
name: playwright-ephemeral
description: Provision and tear down ephemeral Playwright MCP browser sessions as Kubernetes Jobs for E2E testing.
---

# Ephemeral Playwright Browser Provisioning

Provision an ephemeral Playwright MCP browser session running in a Kubernetes Job. Use this when you need to drive a real browser for E2E or integration testing.

## Prerequisites

| Requirement | Description |
|---|---|
| `kubectl` | Must be available and configured with cluster access |
| RBAC | Agent service account needs Jobs and Services CRUD in `playwright-sessions` namespace |
| Network | Cluster networking must allow traffic from agent pod to `playwright-sessions` namespace |

## When to Use

- You need to drive a real Chromium browser (click, navigate, screenshot, scrape)
- You are running E2E or integration tests against a web application
- You need a Playwright MCP server endpoint to connect your MCP client to

## Provision a Session

Run the provision script. It creates a Kubernetes Job + Service pair and waits until the Playwright MCP server is accepting connections.

```bash
RESULT=$(bash ./playwright-ephemeral/scripts/provision.sh)
```

On success, the script prints two lines to stdout:

```
SESSION_NAME=playwright-<agent>-<uuid>
MCP_URL=http://playwright-<agent>-<uuid>.playwright-sessions.svc.cluster.local:8931/mcp
```

Extract the values:

```bash
SESSION_NAME=$(echo "$RESULT" | grep '^SESSION_NAME=' | cut -d= -f2)
MCP_URL=$(echo "$RESULT" | grep '^MCP_URL=' | cut -d= -f2)
```

### Optional Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PLAYWRIGHT_NAMESPACE` | `playwright-sessions` | Kubernetes namespace for browser pods |
| `PLAYWRIGHT_TIMEOUT` | `120` | Seconds to wait for the MCP server to become ready |
| `PLAYWRIGHT_TTL` | `1800` | TTL in seconds after Job finishes (auto-cleanup) |
| `PLAYWRIGHT_DEADLINE` | `1800` | Hard ceiling in seconds for the Job (kills zombie sessions) |
| `PLAYWRIGHT_MEMORY_REQUEST` | `512Mi` | Memory request for the browser container |
| `PLAYWRIGHT_MEMORY_LIMIT` | `1Gi` | Memory limit for the browser container |

## Connect to the Session

Configure your Playwright MCP client with the returned `MCP_URL`. The endpoint speaks HTTP-based MCP transport on port 8931 at the `/mcp` path.

Example: if `MCP_URL=http://playwright-goose-a1b2c3.playwright-sessions.svc.cluster.local:8931/mcp`, point your MCP client at that URL.

## Tear Down a Session

When you are finished with the browser, tear it down:

```bash
bash ./playwright-ephemeral/scripts/teardown.sh "$SESSION_NAME"
```

This deletes both the Job and Service. If you forget, the Job self-cleans after `PLAYWRIGHT_TTL` seconds and hard-terminates after `PLAYWRIGHT_DEADLINE` seconds.

## Error Handling

| Scenario | What Happens |
|---|---|
| Pod fails to schedule | Provision script times out and exits non-zero with an error message |
| MCP server not ready in time | Provision script times out and cleans up the Job/Service before exiting |
| kubectl not found | Script exits immediately with an error |
| Namespace does not exist | Script creates the namespace automatically |

## Security Notes

- Each session runs in an isolated pod with its own network identity.
- Sessions are ephemeral — the Job TTL and active deadline prevent resource leaks.
- The browser runs with `--no-sandbox` (required in containers) and headless Chromium only.
- No data persists after teardown.
