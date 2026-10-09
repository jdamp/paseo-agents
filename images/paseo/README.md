# Paseo agent image

This image extends the upstream Paseo image with Codex, Pi, the Pi MCP adapter,
Go (including a C compiler for cgo), Playwright with Chromium and its system
libraries, PostgreSQL client tools, and infrastructure command-line tools. Its source repository is
`https://github.com/jdamp/paseo-agents`. It preserves Paseo's upstream
entrypoint, web UI, health check, and non-root agent execution.

Versions are not pinned in the repository. `resolve-versions.sh` looks up the
latest stable release of Paseo (tag and digest), Codex, Pi, the Pi MCP adapter,
Go, Playwright, and each standalone tool at build time, and passes them as exact build
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

Go downloads are verified against the SHA-256 checksum in Go's release metadata.
The Go and Playwright versions are also recorded in `io.paseo.go.version` and
`io.paseo.playwright.version` image labels.

Projects should install their own `@playwright/test` dependency and run tests
with their project-local `npx playwright test`. Chromium is preinstalled for the
image's Playwright version in `/opt/playwright-browsers`, outside the mounted
home. If a project uses a different Playwright version, run
`npx playwright install chromium` in that project to download its matching
browser; the shared browser directory is writable by `paseo`, and the OS
libraries are already installed. Do not override `PLAYWRIGHT_BROWSERS_PATH`
unless you also install browsers into the new location. This follows
[Playwright's browser version requirements](https://playwright.dev/docs/docker).
For larger browser suites, give the container more shared memory (for example,
Docker's `--shm-size=1g`, or a memory-backed volume at `/dev/shm` in Kubernetes).
The image smoke test compiles and runs a Go program and launches headless
Chromium as `paseo` with a fresh home.

For apps using PostgreSQL, run a separate **development Postgres instance** on
the homelab with its own storage and credentials. Match the production major
version and required extensions. Give each app its own database and login role,
and use a separate disposable database for tests that reset data. Keep production
credentials out of Paseo; migrations, seed scripts, and tests should target only
the development instance. Sanitized seed data is preferable to production data.

Run Postgres as a separate container/service alongside Paseo (or a separate
StatefulSet/operator-managed cluster in Kubernetes), with persistent storage
for development data. Connect over private service networking using a URL such
as `postgresql://myapp:DEV_PASSWORD@postgres-dev:5432/myapp_dev`, supplied to
the app at runtime as `DATABASE_URL`. The `postgres-dev` hostname must resolve
from Paseo's network. Publish no database port if both services share that
network. In Compose, a `pg_isready` health check with
[`depends_on: condition: service_healthy`](https://docs.docker.com/compose/how-tos/startup-order/)
can wait for Postgres before starting Paseo; apps should still retry connections.

Provision app databases and roles through deployment/admin tooling. Apps normally
need ownership of their own database to run migrations, rather than cluster-wide
superuser access. `psql` and `pg_isready` are available in Paseo for querying and
checking connections; the Postgres server runs independently of the agent image.
Per-project disposable Postgres containers offer stronger isolation when needed,
but require a container runtime or external provisioning service. A shared
development instance with per-app databases is a practical starting point.
