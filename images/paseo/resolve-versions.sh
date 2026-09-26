#!/usr/bin/env bash
# Prints the latest stable upstream version of every image component as NAME=VALUE lines.
set -euo pipefail

github_auth=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  github_auth=(--header "Authorization: Bearer ${GITHUB_TOKEN}")
fi

fetch() { curl --fail --location --retry 3 --silent --show-error "$@"; }

npm_latest() { fetch "https://registry.npmjs.org/$1/latest" | jq -r .version; }

# Highest stable release of a GitHub repo whose tag starts with the given prefix.
github_latest() {
  fetch "${github_auth[@]}" "https://api.github.com/repos/$1/releases?per_page=100" \
    | jq -r --arg prefix "$2" \
        '.[] | select((.draft or .prerelease) | not) | .tag_name | select(startswith($prefix)) | ltrimstr($prefix)' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1
}

ghcr_digest() {
  local token
  token="$(fetch "https://ghcr.io/token?scope=repository:$1:pull" | jq -r .token)"
  fetch --head \
    --header "Authorization: Bearer ${token}" \
    --header "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json" \
    "https://ghcr.io/v2/$1/manifests/$2" \
    | tr -d '\r' | awk -F': ' 'tolower($1) == "docker-content-digest" { print $2 }'
}

# Output is sourced by shells, so reject anything that is not a plain version or digest.
emit() {
  if [[ ! "$2" =~ ^[0-9A-Za-z.:+-]+$ ]]; then
    printf 'resolve-versions: invalid or missing value for %s: %q\n' "$1" "$2" >&2
    exit 1
  fi
  printf '%s=%s\n' "$1" "$2"
}

paseo_version="$(github_latest getpaseo/paseo v)"
emit PASEO_VERSION "$paseo_version"
emit PASEO_DIGEST "$(ghcr_digest getpaseo/paseo "$paseo_version")"
emit CODEX_VERSION "$(npm_latest @openai/codex)"
emit PI_VERSION "$(npm_latest @earendil-works/pi-coding-agent)"
emit PI_MCP_ADAPTER_VERSION "$(npm_latest pi-mcp-adapter)"
emit KUBECTL_VERSION "$(fetch https://dl.k8s.io/release/stable.txt | sed 's/^v//')"
emit KUSTOMIZE_VERSION "$(github_latest kubernetes-sigs/kustomize kustomize/v)"
emit HELM_VERSION "$(github_latest helm/helm v)"
emit SOPS_VERSION "$(github_latest getsops/sops v)"
emit KUBESEAL_VERSION "$(github_latest bitnami-labs/sealed-secrets v)"
emit GH_VERSION "$(github_latest cli/cli v)"
