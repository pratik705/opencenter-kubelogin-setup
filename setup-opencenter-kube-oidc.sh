#!/usr/bin/env bash
set -euo pipefail

# Cross-platform OIDC login setup for Kubernetes
# Works on macOS and Linux
#
# Required env vars:
#   OIDC_ISSUER_URL      - e.g. https://auth.example.com/realms/opencenter
#   OIDC_CLIENT_SECRET   - client secret for the OIDC app
#   KUBE_CLUSTER_NAME    - cluster entry to bind the context to
#
# Optional env vars:
#   OIDC_CLIENT_ID       - default: opencenter
#   OIDC_GRANT_TYPE      - default: device-code
#   OIDC_SKIP_OPEN_BROWSER - default: true
#   KUBE_CONTEXT_NAME    - default: oidc
#   KUBE_USER_NAME       - default: oidc
#   KUBECONFIG           - defaults to ~/.kube/config

# Display banner
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║                   OpenCenter OIDC Authentication Setup                ║
║                                                                       ║
║   This script will configure your Kubernetes cluster access using     ║
║   OpenCenter's Keycloak authentication system.                        ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF

echo ""
echo "[*] Checking prerequisites..."
echo ""

OIDC_ISSUER_URL="${OIDC_ISSUER_URL:-}"
OIDC_CLIENT_ID="${OIDC_CLIENT_ID:-opencenter}"
OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET:-}"
OIDC_GRANT_TYPE="${OIDC_GRANT_TYPE:-device-code}"
OIDC_SKIP_OPEN_BROWSER="${OIDC_SKIP_OPEN_BROWSER:-true}"
KUBE_CLUSTER_NAME="${KUBE_CLUSTER_NAME:-}"
KUBE_CONTEXT_NAME="${KUBE_CONTEXT_NAME:-oidc}"
KUBE_USER_NAME="${KUBE_USER_NAME:-oidc}"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"

[[ -z "${OIDC_ISSUER_URL}" || -z "${OIDC_CLIENT_SECRET}" || -z "${KUBE_CLUSTER_NAME}" ]] && {
  echo "[ERROR] Missing required environment variables"
  echo ""
  echo "Required:"
  echo "  OIDC_ISSUER_URL       - OpenCenter Keycloak issuer URL"
  echo "  OIDC_CLIENT_SECRET    - OpenCenter OIDC client secret"
  echo "  KUBE_CLUSTER_NAME     - Kubernetes cluster name in kubeconfig"
  echo "  KUBECONFIG            - Path to kubeconfig file"
  echo ""
  echo "Example:"
  echo "  export OIDC_ISSUER_URL='https://auth.demo.stage.sjc3.k8s.opencenter.cloud/realms/opencenter' \\"
  echo "  export OIDC_CLIENT_SECRET='your-secret' \\"
  echo "  export KUBE_CLUSTER_NAME='cluster.local' \\"
  echo "  export KUBECONFIG='kubeconfig.yaml' \\"
  echo "  ./setup-oidc-login.sh"
  echo ""
  exit 1
}

command -v kubectl >/dev/null 2>&1 || { echo "[ERROR] kubectl not found" >&2; exit 1; }

# Install krew if needed
if ! kubectl krew version >/dev/null 2>&1; then
  echo "[+] Installing krew (kubectl plugin manager)..."
  tmpdir="$(mktemp -d)"
  cd "${tmpdir}"

  OS="$(uname -s)"
  ARCH="$(uname -m)"

  # Normalize OS and ARCH for krew
  case "${OS}" in
    Darwin*) OS="darwin" ;;
    Linux*)  OS="linux" ;;
    *) echo "[ERROR] Unsupported OS: ${OS}" >&2; exit 1 ;;
  esac

  case "${ARCH}" in
    x86_64)  ARCH="amd64" ;;
    arm64)   ARCH="arm64" ;;
    aarch64) ARCH="arm64" ;;
    *) echo "[ERROR] Unsupported architecture: ${ARCH}" >&2; exit 1 ;;
  esac

  KREW="krew-${OS}_${ARCH}"
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz"
  tar zxf "${KREW}.tar.gz"
  ./"${KREW}" install krew

  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:${PATH}"
  cd - >/dev/null
  echo "[OK] Krew installed successfully"
else
  echo "[OK] Krew already installed"
fi

# Ensure PATH includes krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:${PATH}"

# Install oidc-login plugin if needed
if ! kubectl krew list 2>/dev/null | grep -q '^oidc-login$'; then
  echo "[+] Installing kubectl oidc-login plugin..."
  kubectl krew install oidc-login
  echo "[OK] oidc-login plugin installed successfully"
else
  echo "[OK] oidc-login plugin already installed"
fi

# Configure kubeconfig
echo ""
echo "[*] Configuring OpenCenter OIDC authentication..."

kubectl --kubeconfig="${KUBECONFIG_PATH}" config set-credentials "${KUBE_USER_NAME}" \
  --exec-command=kubectl \
  --exec-api-version=client.authentication.k8s.io/v1 \
  --exec-arg=oidc-login \
  --exec-arg=get-token \
  --exec-arg="--oidc-issuer-url=${OIDC_ISSUER_URL}" \
  --exec-arg="--oidc-client-id=${OIDC_CLIENT_ID}" \
  --exec-arg="--oidc-client-secret=${OIDC_CLIENT_SECRET}" \
  --exec-arg="--grant-type=${OIDC_GRANT_TYPE}" \
  --exec-arg="--skip-open-browser=${OIDC_SKIP_OPEN_BROWSER}"

kubectl --kubeconfig="${KUBECONFIG_PATH}" config set-context "${KUBE_CONTEXT_NAME}" \
  --cluster "${KUBE_CLUSTER_NAME}" \
  --user "${KUBE_USER_NAME}"

kubectl --kubeconfig="${KUBECONFIG_PATH}" config use-context "${KUBE_CONTEXT_NAME}"

echo "[OK] OIDC credentials configured"

# Install yq if needed
if ! command -v yq >/dev/null 2>&1; then
  echo "[+] Installing yq (YAML processor)..."

  OS="$(uname -s)"
  ARCH="$(uname -m)"

  case "${OS}" in
    Darwin*) OS="darwin" ;;
    Linux*)  OS="linux" ;;
  esac

  case "${ARCH}" in
    x86_64)  ARCH="amd64" ;;
    arm64)   ARCH="arm64" ;;
    aarch64) ARCH="arm64" ;;
  esac

  YQ_VERSION="v4.40.5"
  YQ_BINARY="yq_${OS}_${ARCH}"

  if [[ "${OS}" == "darwin" ]]; then
    # macOS - install to /usr/local/bin
    echo "    (requires sudo for /usr/local/bin access)"
    sudo curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}" -o /usr/local/bin/yq
    sudo chmod +x /usr/local/bin/yq
  else
    # Linux - install to ~/.local/bin
    mkdir -p "$HOME/.local/bin"
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}" -o "$HOME/.local/bin/yq"
    chmod +x "$HOME/.local/bin/yq"
    export PATH="$HOME/.local/bin:${PATH}"
  fi
  echo "[OK] yq installed successfully"
else
  echo "[OK] yq already installed"
fi

# Patch exec flags
echo "[*] Patching kubeconfig exec flags..."
tmpfile="$(mktemp)"
kubectl --kubeconfig="${KUBECONFIG_PATH}" config view --raw \
  | yq eval '.users[] |= (select(.name == "'"${KUBE_USER_NAME}"'").user.exec.interactiveMode = "IfAvailable" | select(.name == "'"${KUBE_USER_NAME}"'").user.exec.provideClusterInfo = false)' - \
  > "${tmpfile}" 2>/dev/null && mv "${tmpfile}" "${KUBECONFIG_PATH}" || rm -f "${tmpfile}"

echo "[OK] Kubeconfig patched successfully"
echo ""
echo "========================================================================"
echo ""
echo "              OpenCenter OIDC Setup Complete!"
echo ""
echo "========================================================================"
echo ""
echo "Configuration Summary:"
echo "  * Context: ${KUBE_CONTEXT_NAME}"
echo "  * User: ${KUBE_USER_NAME}"
echo "  * Cluster: ${KUBE_CLUSTER_NAME}"
echo "  * Kubeconfig: ${KUBECONFIG_PATH}"
echo "  * Grant Type: ${OIDC_GRANT_TYPE}"
echo ""
echo "Next Steps:"
echo "  1. Add krew to your PATH (if not already):"
echo "     export PATH=\"\${KREW_ROOT:-\$HOME/.krew}/bin:\$PATH\""
echo ""
echo "  2. Test your connection:"
echo "     kubectl get nodes"
echo ""
echo "  3. You will be prompted for device code authentication"
echo "     Follow the URL and enter the code displayed"
echo ""
echo "Tip: To switch back to this context later, run:"
echo "  kubectl config use-context ${KUBE_CONTEXT_NAME}"
echo ""