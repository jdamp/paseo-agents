#!/usr/bin/env bash
set -euo pipefail

image="${IMAGE_NAME:-paseo-agents}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"

versions="$("${script_dir}/resolve-versions.sh")"
printf '%s\n' "$versions" >&2

args=()
while IFS='=' read -r name value; do
  declare "${name}=${value}"
  args+=(--build-arg "${name}=${value}")
done <<<"$versions"

image_version="${PASEO_VERSION}-codex${CODEX_VERSION}-pi${PI_VERSION}"
revision="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf unknown)"
build_date="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

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
  --build-arg "BUILD_DATE=${build_date}" \
  --build-arg "REVISION=${revision}" \
  --build-arg "IMAGE_VERSION=${image_version}" \
  "${args[@]}" \
  "${output_args[@]}" \
  "$repo_root"

printf '%s\n' "${image}:${image_version}"
