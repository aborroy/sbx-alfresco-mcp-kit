# alfresco-mcp

A mixin that installs the
[AlfrescoLabs MCP server](https://github.com/AlfrescoLabs/alfresco-mcp-server)
and registers it as a **stdio** MCP server on the `claude` agent. It gives the
agent tools to search, browse, and manage content in an
[Alfresco](https://github.com/Alfresco) repository — search and CMIS queries,
node CRUD and metadata, document upload/download, PDF renditions, folder
creation, and check-in/check-out — all from inside the sandbox boundary.

The server is a single, self-contained Python script. The kit pins it to an
exact commit and verifies its SHA256 before use (same supply-chain stance as
the `vale` and `mise` kits), then installs its two dependencies (`fastmcp`,
`httpx`) with pip.

## Usage

Pair it with the built-in `claude` agent. You need an Alfresco repository the
sandbox can reach — by default the kit assumes one running **on your host**
(e.g. the official
[`acs-deployment`](https://github.com/Alfresco/acs-deployment) community
compose) at `http://localhost:8080`, reached from the sandbox over the Docker
bridge as `host.docker.internal:8080`.

```console
$ sbx run claude --kit "git+https://github.com/docker/sbx-kits-contrib.git#dir=alfresco-mcp" ~/my-project
```

Once the sandbox is up, the `alfresco` MCP server is available to the agent.
Ask it to, e.g., "list the children of the Company Home folder" or "search for
documents modified this week."

## Authentication

Alfresco uses short-lived, per-user **tickets** rather than a long-lived API
key, so the kit deliberately does **not** bake in a credential. Authenticate in
one of two ways:

- **At runtime (default):** ask the agent to call the `set_ticket` tool with a
  ticket. Get one with:

  ```console
  $ curl -s -X POST "$ALFRESCO_HOST/alfresco/api/-default-/public/authentication/versions/1/tickets" \
      -H 'Content-Type: application/json' \
      -d '{"userId":"admin","password":"admin"}'
  ```

  Pass the `id` from the JSON response to `set_ticket`.

- **Non-interactive:** set the `ALFRESCO_TICKET` environment variable (e.g. via
  a fork or `sbx`'s environment handling) and the server picks it up on start.

## Pointing at a different Alfresco

Set `ALFRESCO_HOST` to your repository's base URL. The default
(`http://host.docker.internal:8080`) and any `localhost` target work without
network changes because the Docker bridge is exempt from the sandbox egress
allowlist.

For a **remote** Alfresco (e.g. `https://alfresco.example.com`), fork this kit
and add the host to `network.allowedDomains` in `spec.yaml` — the sandbox runs
deny-all, so an undeclared host is blocked.

## How the MCP server gets registered

The base `claude` kit owns `~/.claude.json`. This kit's `commands.startup` runs
after that file exists and **merges** an `mcpServers.alfresco` entry into it
(load → add key → write back), so it never clobbers the base agent's settings.
The merge is idempotent, which matters because `startup` runs on every
container start.

To verify inside a running sandbox:

```console
$ sbx exec <sandbox-name> -- python3 /home/agent/.alfresco-mcp/alfresco_mcp_server.py --help
$ sbx exec <sandbox-name> -- cat /home/agent/.claude.json
```

## Bumping the server version

In `spec.yaml`, update `MCP_REF` (a 40-hex commit SHA from
`AlfrescoLabs/alfresco-mcp-server`) and `MCP_SHA256` (the SHA256 of
`alfresco_mcp_server.py` at that commit). Both live in the install command.
