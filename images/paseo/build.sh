#!/usr/bin/env bash
set -euo pipefail

image="${IMAGE_NAME:-paseo-agents}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"

set -a
# shellcheck source=versions.env
source "${script_dir}/versions.env"
set +a

codex_version="$(node -p "require('${script_dir}/package.json').dependencies['@openai/codex']")"
pi_version="$(node -p "require('${script_dir}/package.json').dependencies['@earendil-works/pi-coding-agent']")"
adapter_version="$(node -p "require('${script_dir}/package.json').dependencies['pi-mcp-adapter']")"
image_version="${PASEO_VERSION}-codex${codex_version}-pi${pi_version}"
revision="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf unknown)"
build_date="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

args=()
for name in PASEO_VERSION PASEO_DIGEST KUBECTL_VERSION KUSTOMIZE_VERSION HELM_VERSION SOPS_VERSION KUBESEAL_VERSION GH_VERSION; do
  args+=(--build-arg "${name}=${!name}")
done

builder=(docker build)
output_args=()
if docker buildx version >/dev/null 2>&1; then
  builder=(docker buildx build)
  output_args=(--load)
fi

"${builder[@]}" \
  --platform linux/amd64 \
  --file "${script_dir}/Dockerfile" \
  --tag "${image}:${image_version}" \
  --build-arg "CODEX_VERSION=${codex_version}" \
  --build-arg "PI_VERSION=${pi_version}" \
  --build-arg "PI_MCP_ADAPTER_VERSION=${adapter_version}" \
  --build-arg "BUILD_DATE=${build_date}" \
  --build-arg "REVISION=${revision}" \
  --build-arg "IMAGE_VERSION=${image_version}" \
  "${args[@]}" \
  "${output_args[@]}" \
  "$repo_root"

printf '%s\n' "${image}:${image_version}"
