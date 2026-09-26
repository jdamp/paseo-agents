# Paseo agent image

This image extends the upstream Paseo image with Codex, Pi, the Pi MCP adapter,
and infrastructure command-line tools. Its source repository is
`https://github.com/jdamp/paseo-agents`. It preserves Paseo's upstream
entrypoint, web UI, health check, and non-root agent execution.

Versions are not pinned in the repository. `resolve-versions.sh` looks up the
latest stable release of Paseo (tag and digest), Codex, Pi, the Pi MCP adapter,
and each standalone tool at build time, and passes them as exact build
arguments. CI rebuilds every Monday, so new upstream releases are published
automatically once they pass the smoke tests and security scan. The resolved
versions are recorded in the image tag, OCI labels, and attached SBOM.

The security gate fails on critical vulnerabilities and detected secrets.
Temporary findings that cannot yet be removed are narrowly scoped by binary or
package in `.trivyignore.yaml`, with a rationale and mandatory expiry date.

Build and test locally:

```sh
image="$(images/paseo/build.sh)"
images/paseo/smoke-test.sh "$image"
```

The image exposes port 6767 as metadata. Supply credentials and persistent
homes only at runtime; none are included in the image.
