# Paseo agent image: implementation handoff

Status: ready for implementation
Last updated: 2026-09-09
Scope: Docker image and image publishing only

## Objective

Build a reproducible Paseo image containing:

- the Paseo daemon and bundled web UI;
- the Codex CLI;
- the Pi CLI;
- the command-line tools needed to work on this homelab repository.

This document intentionally does not cover Kubernetes manifests, storage,
networking, authentication, provider bootstrap, mobile pairing, Argo CD, or
runtime rollout.

## Version pins

Use these versions for the first image build. Re-check availability before
implementation and record any deliberate changes in the image metadata.

| Component | Version | Package/image |
| --- | ---: | --- |
| Paseo base | `0.7.2` | `ghcr.io/getpaseo/paseo:0.7.2` |
| Paseo base digest | — | `sha256:da9286410d9dd86208755b789894534d9e200c9021bd45157557aac4146b84fb` |
| Codex CLI | `0.153.4` | `@openai/codex` |
| Pi CLI | `0.85.1` | `@earendil-works/pi-coding-agent` |
| Pi MCP adapter | `2.32.1` | `pi-mcp-adapter` |

Use this immutable base reference:

```dockerfile
FROM ghcr.io/getpaseo/paseo:0.7.2@sha256:da9286410d9dd86208755b789894534d9e200c9021bd45157557aac4146b84fb
```

If the tag resolves to a different digest, stop for review. Do not silently
replace the digest.

## Image name and tags

Publish the image as:

```text
ghcr.io/jdamp/paseo-agents
```

For the pinned baseline, publish:

```text
0.7.2-codex0.153.4-pi0.85.1
```

Also publish a commit-SHA tag for traceability.

## Dockerfile requirements

Create:

```text
images/paseo/Dockerfile
```

The Dockerfile must:

1. Start from the immutable Paseo base above.
2. Install Codex with `@openai/codex@0.153.4`.
3. Install Pi with `@earendil-works/pi-coding-agent@0.85.1` and
   `--ignore-scripts`.
4. Make both `codex` and `pi` available on the daemon user's `PATH`.
5. Provide `pi-mcp-adapter@2.32.1` for the Paseo Pi integration. Do not bake a
   user-specific Pi configuration or automatically enable Home Assistant MCP.
6. Install the repository tooling required for coding tasks:
   `git`, `openssh-client`, `curl`, `jq`, `ripgrep`, `fd`, and `gh`.
7. Install Kubernetes tooling used by this repository where practical:
   `kubectl`, `kustomize`, `helm`, `sops`, and `kubeseal`. Keep these tools
   version-pinned if the selected installation source supports pinning.
8. Preserve Paseo's upstream entrypoint and bundled web UI behavior.
9. Preserve Paseo's non-root runtime model. Do not add `--privileged`, host
   mounts, a Docker socket, or shell startup code that weakens isolation.
10. Set no credentials, repository URLs, kubeconfig, SSH keys, or Home
    Assistant configuration in the image.

Inspect the base image before choosing the package-manager commands. Keep build
layers small and clean package-manager caches in the same layer that installs
system packages.

The final image may retain the base image's root entrypoint setup behavior, but
launched agents must run as the non-root Paseo user. Do not add an alternative
entrypoint that bypasses the upstream privilege drop.

### Suggested Dockerfile shape

This is an implementation outline, not a literal Dockerfile:

```dockerfile
FROM ghcr.io/getpaseo/paseo:0.7.2@sha256:da9286410d9dd86208755b789894534d9e200c9021bd45157557aac4146b84fb

ARG CODEX_VERSION=0.153.4
ARG PI_VERSION=0.85.1
ARG PI_MCP_ADAPTER_VERSION=2.32.1

USER root

# Install OS tools using the base image's package manager.
# Install the pinned npm packages with lifecycle scripts disabled where
# appropriate. Keep the upstream Paseo entrypoint and CMD unchanged.

LABEL org.opencontainers.image.title="Paseo with Codex and Pi"
LABEL org.opencontainers.image.source="https://github.com/jdamp/paseo-agents"
LABEL org.opencontainers.image.version="0.7.2-codex0.153.4-pi0.85.1"
```

Do not use an unpinned `npm install -g package` in the final implementation.
The version must be explicit for every agent package.

## Pi MCP adapter handling

The image must contain the pinned adapter package so the Pi provider can use
Paseo's injected MCP integration. Activation in a specific user's Pi home is a
runtime concern and must not be baked into the image.

Do not copy the existing `pi-bot` Pi home, `mcp.json`, `AGENTS.md`, sessions,
Telegram extension, memories, or Home Assistant endpoint into the image.

## Image metadata

Add OCI labels for:

- source repository and revision;
- Paseo base tag and digest;
- Codex version;
- Pi version;
- Pi MCP adapter version;
- image build timestamp;
- license where known.

The image should expose port `6767` in metadata/documentation. Actual port
binding is a runtime concern and is outside this document.

## CI publishing workflow

Create:

```text
.github/workflows/paseo-image.yaml
```

The workflow must:

- run on changes below `images/paseo/**`;
- support manual dispatch;
- use `contents: read` and `packages: write` only;
- authenticate to GHCR with `GITHUB_TOKEN`;
- build for `linux/amd64`, matching the current K3s nodes;
- use BuildKit/buildx;
- tag the image with the pinned version string and commit SHA;
- publish an SBOM and provenance attestation when supported by the chosen
  action;
- fail before publishing if any smoke test fails.

Do not deploy workloads from this workflow; it is responsible for building and
publishing the image only.

## Image-level validation

### Build validation

- [ ] The Dockerfile builds from the expected base digest.
- [ ] No credentials, kubeconfig, SSH keys, repository checkouts, or
      Home Assistant configuration enter the build context.
- [ ] The build succeeds without network access after dependency layers are
      resolved, where the selected builder supports cached/offline builds.
- [ ] The image architecture is `linux/amd64`.
- [ ] The image scan reports no newly introduced critical vulnerabilities, or
      each accepted exception is recorded with a reason and expiry.

### Binary validation

Run a disposable container and verify:

```sh
paseo --version
codex --version
pi --version
git --version
gh --version
kubectl version --client
kustomize version
helm version --short
sops --version
kubeseal --version
```

Verify that:

- [ ] `paseo`, `codex`, and `pi` resolve from the daemon user's `PATH`;
- [ ] the commands run without root-only assumptions;
- [ ] Paseo still starts with its upstream entrypoint;
- [ ] the bundled web UI remains present;
- [ ] the image contains no user-specific agent state;
- [ ] the image does not contain `TELEGRAM_BOT_TOKEN`, Home Assistant tokens,
      `OPENAI_API_KEY`, GitHub tokens, or other secret values.

### Runtime compatibility smoke test

Start the image with an empty temporary home and workspace, then verify that:

1. Paseo starts and reports a healthy daemon.
2. Provider discovery can find both `codex` and `pi` binaries.
3. Paseo can create a disposable local workspace.
4. The image's non-root user can create files in the mounted workspace.
5. No provider is preconfigured with Home Assistant MCP.

Do not perform real provider authentication in CI. Authentication belongs to
the runtime environment and must never be captured in image layers or logs.

## Handoff outputs

The image implementation is complete when the implementer provides:

- `images/paseo/Dockerfile`;
- `.github/workflows/paseo-image.yaml`;
- the published image tag;
- the published immutable image digest;
- the build log or CI run URL;
- smoke-test results for every listed binary;
- vulnerability scan/SBOM output;
- a short note describing any package that could not be pinned and why.

## References

- [Paseo repository](https://github.com/getpaseo/paseo)
- [Paseo Docker documentation](https://paseo.sh/docs/docker)
- [Paseo provider documentation](https://paseo.sh/docs/providers)
- [Paseo security documentation](https://paseo.sh/docs/security)
- [Paseo v0.7.2 release](https://github.com/getpaseo/paseo/releases/tag/v0.7.2)
- [Pi installation and documentation](https://pi.dev/docs/latest)
