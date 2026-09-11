# Paseo agent image

This image extends the upstream Paseo image with Codex, Pi, the Pi MCP adapter,
and infrastructure command-line tools. Its source repository is
`https://github.com/jdamp/paseo-agents`. It preserves Paseo's upstream
entrypoint, web UI, health check, and non-root agent execution.

Versions are intentionally centralized:

- `package.json` pins Codex, Pi, and the Pi MCP adapter; `package-lock.json`
  makes their full dependency graph reproducible.
- `versions.env` pins the Paseo base digest and standalone tool releases.
- Renovate is configured at the repository root to propose weekly updates.
- CI also rebuilds the current pins every Monday, catching upstream or base
  regressions even when no source file changed.

The security gate fails on critical vulnerabilities and detected secrets.
Temporary findings that cannot yet be removed are narrowly scoped by binary or
package in `.trivyignore.yaml`, with a rationale and mandatory expiry date.

Build and test locally:

```sh
images/paseo/build.sh
images/paseo/smoke-test.sh paseo-agents:0.7.2-codex0.153.4-pi0.85.1
```

The image exposes port 6767 as metadata. Supply credentials and persistent
homes only at runtime; none are included in the image.
