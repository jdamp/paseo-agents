#!/usr/bin/env bash
set -euo pipefail

image="${1:?usage: smoke-test.sh IMAGE}"
container="paseo-smoke-${RANDOM}-$$"
adapter_version="$(docker image inspect --format '{{index .Config.Labels "io.paseo.pi-mcp-adapter.version"}}' "$image")"
cleanup() { docker rm --force "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run --rm --env "EXPECTED_ADAPTER_VERSION=${adapter_version}" "$image" sh -euc '
  test "$(id -u)" != 0
  test "$(id -un)" = paseo
  test -z "${OPENAI_API_KEY:-}${GITHUB_TOKEN:-}${GH_TOKEN:-}${TELEGRAM_BOT_TOKEN:-}${SUPERVISOR_TOKEN:-}"
  test ! -e "$HOME/.config/pi/mcp.json"
  test ! -e "$HOME/.codex/auth.json"
  paseo --version
  codex --version
  pi --version
  command -v pi-mcp-adapter
  test "$(node -p "require(\"/opt/paseo-agent-tools/node_modules/pi-mcp-adapter/package.json\").version")" = "$EXPECTED_ADAPTER_VERSION"
  git --version
  gh --version
  kubectl version --client
  kustomize version
  helm version --short
  sops --version
  kubeseal --version
  fd --version
  rg --version | head -1
  touch /workspace/non-root-write-test
  rm /workspace/non-root-write-test
'

docker run --detach --name "$container" --tmpfs /home/paseo:uid=1000,gid=1000 --tmpfs /workspace:uid=1000,gid=1000 "$image" >/dev/null
for _ in $(seq 1 60); do
  status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container")"
  case "$status" in
    healthy) break ;;
    unhealthy) docker logs "$container"; exit 1 ;;
  esac
  sleep 1
done
test "$(docker inspect --format '{{.State.Health.Status}}' "$container")" = healthy
docker exec --user paseo "$container" node -e 'require("http").get("http://127.0.0.1:6767/", response => process.exit(response.statusCode < 400 ? 0 : 1)).on("error", () => process.exit(1))'
provider_json="$(docker exec --user paseo "$container" paseo provider ls --json)"
printf '%s\n' "$provider_json"
printf '%s\n' "$provider_json" | jq -e 'tostring | test("codex"; "i") and test("pi"; "i")' >/dev/null
docker exec --user paseo "$container" sh -euc 'test "$(id -u)" != 0; touch /workspace/daemon-write-test'
docker exec --user paseo "$container" paseo workspace create --isolation local --path /workspace --title ci-smoke-test --json
