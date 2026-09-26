# syntax=docker/dockerfile:1.7

ARG PASEO_VERSION
ARG PASEO_DIGEST
FROM ghcr.io/getpaseo/paseo:${PASEO_VERSION}@${PASEO_DIGEST}

ARG PASEO_VERSION
ARG PASEO_DIGEST
ARG TARGETARCH=amd64
ARG KUBECTL_VERSION
ARG KUSTOMIZE_VERSION
ARG HELM_VERSION
ARG SOPS_VERSION
ARG KUBESEAL_VERSION
ARG GH_VERSION
ARG CODEX_VERSION
ARG PI_VERSION
ARG PI_MCP_ADAPTER_VERSION
ARG BUILD_DATE="unknown"
ARG REVISION="unknown"
ARG IMAGE_VERSION="unknown"

USER root

RUN set -eux; \
    test "${TARGETARCH}" = "amd64"; \
    apt-get update; \
    apt-get install --yes --no-install-recommends \
      ca-certificates \
      curl \
      fd-find \
      git \
      jq \
      openssh-client \
      ripgrep \
      tar; \
    ln -s /usr/bin/fdfind /usr/local/bin/fd; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/paseo-agent-tools
RUN set -eux; \
    : "${CODEX_VERSION:?}" "${PI_VERSION:?}" "${PI_MCP_ADAPTER_VERSION:?}"; \
    npm init --yes >/dev/null; \
    npm install --omit=dev --ignore-scripts --save-exact \
      "@openai/codex@${CODEX_VERSION}" \
      "@earendil-works/pi-coding-agent@${PI_VERSION}" \
      "pi-mcp-adapter@${PI_MCP_ADAPTER_VERSION}"; \
    npm cache clean --force; \
    ln -s /opt/paseo-agent-tools/node_modules/.bin/codex /usr/local/bin/codex; \
    ln -s /opt/paseo-agent-tools/node_modules/.bin/pi /usr/local/bin/pi; \
    ln -s /opt/paseo-agent-tools/node_modules/.bin/pi-mcp-adapter /usr/local/bin/pi-mcp-adapter; \
    rm -rf /home/paseo/.npm

RUN set -eux; \
    tmp="$(mktemp -d)"; \
    cd "$tmp"; \
    fetch() { curl --fail --location --retry 3 --silent --show-error "$1" --output "$2"; }; \
    verify_from_list() { grep "[[:space:]]$1$" "$2" | sha256sum --check --status; }; \
    fetch "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" kubectl; \
    fetch "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256" kubectl.sha256; \
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check --status; \
    install -m 0755 kubectl /usr/local/bin/kubectl; \
    kustomize_archive="kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"; \
    fetch "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION}/${kustomize_archive}" "$kustomize_archive"; \
    fetch "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION}/checksums.txt" kustomize-checksums.txt; \
    verify_from_list "$kustomize_archive" kustomize-checksums.txt; \
    tar -xzf "$kustomize_archive" kustomize; \
    install -m 0755 kustomize /usr/local/bin/kustomize; \
    helm_archive="helm-v${HELM_VERSION}-linux-amd64.tar.gz"; \
    fetch "https://get.helm.sh/${helm_archive}" "$helm_archive"; \
    fetch "https://get.helm.sh/${helm_archive}.sha256sum" helm.sha256sum; \
    verify_from_list "$helm_archive" helm.sha256sum; \
    tar -xzf "$helm_archive" linux-amd64/helm; \
    install -m 0755 linux-amd64/helm /usr/local/bin/helm; \
    sops_binary="sops-v${SOPS_VERSION}.linux.amd64"; \
    fetch "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/${sops_binary}" "$sops_binary"; \
    fetch "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.checksums.txt" sops-checksums.txt; \
    verify_from_list "$sops_binary" sops-checksums.txt; \
    install -m 0755 "$sops_binary" /usr/local/bin/sops; \
    kubeseal_archive="kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"; \
    fetch "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/${kubeseal_archive}" "$kubeseal_archive"; \
    fetch "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/sealed-secrets_${KUBESEAL_VERSION}_checksums.txt" kubeseal-checksums.txt; \
    verify_from_list "$kubeseal_archive" kubeseal-checksums.txt; \
    tar -xzf "$kubeseal_archive" kubeseal; \
    install -m 0755 kubeseal /usr/local/bin/kubeseal; \
    gh_archive="gh_${GH_VERSION}_linux_amd64.tar.gz"; \
    fetch "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${gh_archive}" "$gh_archive"; \
    fetch "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt" gh-checksums.txt; \
    verify_from_list "$gh_archive" gh-checksums.txt; \
    tar -xzf "$gh_archive" "gh_${GH_VERSION}_linux_amd64/bin/gh"; \
    install -m 0755 "gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh; \
    cd /; \
    rm -rf "$tmp"

WORKDIR /workspace

LABEL org.opencontainers.image.title="Paseo with Codex and Pi" \
      org.opencontainers.image.description="Paseo agent daemon with pinned coding and infrastructure command-line tools" \
      org.opencontainers.image.source="https://github.com/jdamp/paseo-agents" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.licenses="MIT" \
      io.paseo.base.version="${PASEO_VERSION}" \
      io.paseo.base.digest="${PASEO_DIGEST}" \
      io.paseo.codex.version="${CODEX_VERSION}" \
      io.paseo.pi.version="${PI_VERSION}" \
      io.paseo.pi-mcp-adapter.version="${PI_MCP_ADAPTER_VERSION}"

EXPOSE 6767
