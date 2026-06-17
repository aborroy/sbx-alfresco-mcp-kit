# sbx-alfresco-mcp-kit

A [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) **mixin kit** that
gives a coding agent (e.g. `claude`) tools to work with an
[Alfresco](https://github.com/Alfresco) content repository, via the
[AlfrescoLabs MCP server](https://github.com/AlfrescoLabs/alfresco-mcp-server).

This repository is set up to **publish the kit as an OCI artifact** to Docker
Hub, so others can run it without cloning anything.

The kit itself lives in [`alfresco-mcp/`](./alfresco-mcp/) — see its
[README](./alfresco-mcp/README.md) for what it does and how auth works.

## Quick start (consume the published kit)

```console
$ sbx run claude --kit docker.io/angelborroy/sbx-alfresco-mcp-kit:1.1.0 .
```

You need an Alfresco repository the sandbox can reach (by default one running on
your host at `http://localhost:8080`). See the kit README for details.

## Publishing

Install the `sbx` CLI (`brew install docker/tap/sbx` on macOS) and `sbx login`,
then:

```console
$ DOCKER_NAMESPACE=angelborroy ./scripts/publish.sh
```

`scripts/publish.sh` rsyncs a **clean staging copy** before pushing, because
`sbx kit push` packages the directory exactly as-is and ignores `.gitignore` /
`.dockerignore` — staging is what prevents a stray `.venv` or `.sbx/.env` from
being published. It validates the staged copy, then pushes two tags:

- `:1.1.0` — pinned to the upstream MCP-server version (traceable, immutable-ish)
- `:latest` — moving pointer

Use `DRY_RUN=1` to stage + validate without pushing.

## Versioning

The kit pins the MCP server to an exact commit + SHA256 (in
`alfresco-mcp/spec.yaml`). The published image tag (`KIT_VERSION` in
`scripts/publish.sh`, default `1.1.0`) tracks that upstream version. **Bump all
three together** when upgrading: `MCP_REF`, `MCP_SHA256`, and `KIT_VERSION`.

## CI

Two **decoupled** workflows (per Docker's kit-authoring guidance — a policy
tweak shouldn't trigger a release):

- **`.github/workflows/test.yml`** — on push/PR and nightly: validates the
  manifest and re-verifies the pinned MCP-server digest still resolves. Never
  pushes.
- **`.github/workflows/publish.yml`** — on a `v*` tag (or manual dispatch):
  logs into Docker Hub and runs the staging + push script. Requires repo
  secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`.

## Local verification

The kit's spec and install were validated against the Docker Sandboxes TCK
(real-container install of the SHA-pinned server + `fastmcp`/`httpx`). Full
end-to-end (`sbx run`) requires Linux with `/dev/kvm`.
