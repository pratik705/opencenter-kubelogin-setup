#!/usr/bin/env bash
set -euo pipefail

# OpenCenter OIDC login setup for Kubernetes
# Supports two modes:
#   1. Update existing kubeconfig (backs up first)
#   2. Create new kubeconfig from scratch (prompts for cluster details)

cat << 'EOF'
========================================================================

                   OpenCenter OIDC Authentication Setup

   This script will configure your Kubernetes cluster access using
   OpenCenter's Keycloak authentication system.

========================================================================
EOF

echo ""

# Check kubectl
command -v kubectl >/dev/null 2>&1 || { echo "[ERROR] kubectl not found" >&2; exit 1; }

# Load environment variables with defaults
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
KUBE_CLUSTER_NAME="${KUBE_CLUSTER_NAME:-}"
KUBE_API_SERVER="${KUBE_API_SERVER:-}"
KUBE_CA_CERT="${KUBE_CA_CERT:-}"
OIDC_ISSUER_URL="${OIDC_ISSUER_URL:-}"
OIDC_CLIENT_ID="${OIDC_CLIENT_ID:-opencenter}"
OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET:-}"
KUBE_CONTEXT_NAME="${KUBE_CONTEXT_NAME:-oidc}"
KUBE_USER_NAME="${KUBE_USER_NAME:-oidc}"

# Determine if running in non-interactive mode
NON_INTERACTIVE=false
if [[ -n "${OIDC_ISSUER_URL}" && -n "${OIDC_CLIENT_SECRET}" ]]; then
  if [[ -n "${KUBE_CLUSTER_NAME}" ]] || [[ -n "${KUBE_API_SERVER}" ]]; then
    NON_INTERACTIVE=true
    echo "[*] Running in non-interactive mode (environment variables detected)"
  fi
fi

# Determine mode: existing kubeconfig or manual setup
USE_EXISTING=false

if [[ "${NON_INTERACTIVE}" == "true" ]]; then
  # Non-interactive mode: decide based on environment variables
  if [[ -n "${KUBE_CLUSTER_NAME}" && -f "${KUBECONFIG_PATH}" ]]; then
    # Use existing kubeconfig if cluster name is provided and file exists
    USE_EXISTING=true
    BACKUP_PATH="${KUBECONFIG_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "${KUBECONFIG_PATH}" "${BACKUP_PATH}"
    echo "[OK] Backed up kubeconfig to: ${BACKUP_PATH}"

    # Verify cluster exists
    if ! kubectl --kubeconfig="${KUBECONFIG_PATH}" config get-clusters 2>/dev/null | grep -q "^${KUBE_CLUSTER_NAME}$"; then
      echo "[ERROR] Cluster '${KUBE_CLUSTER_NAME}' not found in kubeconfig"
      exit 1
    fi
  elif [[ -n "${KUBE_API_SERVER}" ]]; then
    # Manual setup mode
    USE_EXISTING=false
    KUBE_CLUSTER_NAME="${KUBE_CLUSTER_NAME:-kubernetes}"
    if [[ -n "${KUBE_CA_CERT}" && -f "${KUBE_CA_CERT}" ]]; then
      USE_CA_CERT=true
    else
      USE_CA_CERT=false
    fi
  else
    echo "[ERROR] In non-interactive mode, must provide either:"
    echo "  - KUBE_CLUSTER_NAME (for existing kubeconfig)"
    echo "  - KUBE_API_SERVER (for manual setup)"
    exit 1
  fi
else
  # Interactive mode
  if [[ -f "${KUBECONFIG_PATH}" ]]; then
    echo "[*] Found existing kubeconfig at: ${KUBECONFIG_PATH}"
    echo ""
    read -p "Do you want to use this existing kubeconfig? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      USE_EXISTING=true
      # Backup existing kubeconfig
      BACKUP_PATH="${KUBECONFIG_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
      cp "${KUBECONFIG_PATH}" "${BACKUP_PATH}"
      echo "[OK] Backed up kubeconfig to: ${BACKUP_PATH}"
    fi
  fi

  echo ""
  echo "=========================================================================="
  echo "                    Cluster Configuration"
  echo "=========================================================================="
  echo ""

  if [[ "${USE_EXISTING}" == "true" ]]; then
    # Mode 1: Use existing kubeconfig
    echo "[*] Using existing kubeconfig"
    echo ""

    # Show available clusters
    echo "Available clusters in kubeconfig:"
    kubectl --kubeconfig="${KUBECONFIG_PATH}" config get-clusters | tail -n +2 | nl
    echo ""

    if [[ -z "${KUBE_CLUSTER_NAME}" ]]; then
      read -p "Enter cluster name to use: " KUBE_CLUSTER_NAME
    fi

    # Verify cluster exists
    if ! kubectl --kubeconfig="${KUBECONFIG_PATH}" config get-clusters | grep -q "^${KUBE_CLUSTER_NAME}$"; then
      echo "[ERROR] Cluster '${KUBE_CLUSTER_NAME}' not found in kubeconfig"
      exit 1
    fi
  else
    # Mode 2: Manual cluster setup
    echo "[*] Manual cluster configuration"
    echo ""

    if [[ -z "${KUBE_API_SERVER}" ]]; then
      read -p "Enter Kubernetes API Server URL (e.g., https://10.0.0.1:6443): " KUBE_API_SERVER
    fi

    if [[ -z "${KUBE_CLUSTER_NAME}" ]]; then
      read -p "Enter cluster name (default: kubernetes): " input_cluster
      KUBE_CLUSTER_NAME="${input_cluster:-kubernetes}"
    fi

    echo ""
    if [[ -z "${KUBE_CA_CERT}" ]]; then
      read -p "Do you have a CA certificate file? (y/n): " -n 1 -r
      echo ""
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter path to CA certificate file: " KUBE_CA_CERT
      fi
    fi

    if [[ -n "${KUBE_CA_CERT}" ]]; then
      if [[ ! -f "${KUBE_CA_CERT}" ]]; then
        echo "[ERROR] CA certificate file not found: ${KUBE_CA_CERT}"
        exit 1
      fi
      USE_CA_CERT=true
    else
      echo "[WARNING] Will use --insecure-skip-tls-verify (not recommended for production)"
      USE_CA_CERT=false
    fi
  fi

  echo ""
  echo "=========================================================================="
  echo "                    OIDC Configuration"
  echo "=========================================================================="
  echo ""

  if [[ -z "${OIDC_ISSUER_URL}" ]]; then
    read -p "Enter OIDC Issuer URL (e.g., https://auth.example.com/realms/opencenter): " OIDC_ISSUER_URL
  fi

  if [[ -z "${OIDC_CLIENT_ID}" || "${OIDC_CLIENT_ID}" == "opencenter" ]]; then
    read -p "Enter OIDC Client ID (default: opencenter): " input_client_id
    OIDC_CLIENT_ID="${input_client_id:-opencenter}"
  fi

  if [[ -z "${OIDC_CLIENT_SECRET}" ]]; then
    read -sp "Enter OIDC Client Secret: " OIDC_CLIENT_SECRET
    echo ""
  fi

  if [[ -z "${KUBE_CONTEXT_NAME}" || "${KUBE_CONTEXT_NAME}" == "oidc" ]]; then
    read -p "Enter context name (default: oidc): " input_context
    KUBE_CONTEXT_NAME="${input_context:-oidc}"
  fi

  if [[ -z "${KUBE_USER_NAME}" || "${KUBE_USER_NAME}" == "oidc" ]]; then
    read -p "Enter user name (default: oidc): " input_user
    KUBE_USER_NAME="${input_user:-oidc}"
  fi
fi

# Validate required inputs
if [[ -z "${OIDC_ISSUER_URL}" || -z "${OIDC_CLIENT_SECRET}" ]]; then
  echo "[ERROR] OIDC Issuer URL and Client Secret are required"
  exit 1
fi

if [[ "${USE_EXISTING}" == "false" && -z "${KUBE_API_SERVER}" ]]; then
  echo "[ERROR] Kubernetes API Server URL is required"
  exit 1
fi

echo ""
echo "=========================================================================="
echo "                    Installing Dependencies"
echo "=========================================================================="
echo ""

# Install krew if needed
if ! kubectl krew version >/dev/null 2>&1; then
  echo "[+] Installing krew..."
  tmpdir="$(mktemp -d)"
  cd "${tmpdir}"

  OS="$(uname -s)"
  ARCH="$(uname -m)"

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
  echo "[OK] Krew installed"
else
  echo "[OK] Krew already installed"
fi

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:${PATH}"

# Install oidc-login plugin
if ! kubectl krew list 2>/dev/null | grep -q '^oidc-login$'; then
  echo "[+] Installing kubectl oidc-login plugin..."
  kubectl krew install oidc-login
  echo "[OK] oidc-login plugin installed"
else
  echo "[OK] oidc-login plugin already installed"
fi

# Install yq
if ! command -v yq >/dev/null 2>&1; then
  echo "[+] Installing yq..."

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
    echo "    (requires sudo for /usr/local/bin access)"
    sudo curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}" -o /usr/local/bin/yq
    sudo chmod +x /usr/local/bin/yq
  else
    mkdir -p "$HOME/.local/bin"
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}" -o "$HOME/.local/bin/yq"
    chmod +x "$HOME/.local/bin/yq"
    export PATH="$HOME/.local/bin:${PATH}"
  fi
  echo "[OK] yq installed"
else
  echo "[OK] yq already installed"
fi

echo ""
echo "=========================================================================="
echo "                    Configuring Kubeconfig"
echo "=========================================================================="
echo ""

# Create .kube directory if needed
mkdir -p "$(dirname "${KUBECONFIG_PATH}")"

# Configure cluster (only if manual setup)
if [[ "${USE_EXISTING}" == "false" ]]; then
  echo "[*] Setting up cluster configuration..."
  if [[ "${USE_CA_CERT}" == "true" ]]; then
    kubectl --kubeconfig="${KUBECONFIG_PATH}" config set-cluster "${KUBE_CLUSTER_NAME}" \
      --server="${KUBE_API_SERVER}" \
      --certificate-authority="${KUBE_CA_CERT}" \
      --embed-certs=true
    echo "[OK] Cluster configured with CA certificate"
  else
    kubectl --kubeconfig="${KUBECONFIG_PATH}" config set-cluster "${KUBE_CLUSTER_NAME}" \
      --server="${KUBE_API_SERVER}" \
      --insecure-skip-tls-verify=true
    echo "[OK] Cluster configured (insecure skip TLS)"
  fi
fi

# Configure OIDC user
echo "[*] Setting up OIDC user..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" config set-credentials "${KUBE_USER_NAME}" \
  --exec-command=kubectl \
  --exec-api-version=client.authentication.k8s.io/v1 \
  --exec-arg=oidc-login \
  --exec-arg=get-token \
  --exec-arg="--oidc-issuer-url=${OIDC_ISSUER_URL}" \
  --exec-arg="--oidc-client-id=${OIDC_CLIENT_ID}" \
  --exec-arg="--oidc-client-secret=${OIDC_CLIENT_SECRET}" \
  --exec-arg=--grant-type=device-code \
  --exec-arg=--skip-open-browser=true

echo "[OK] OIDC user configured"

# Create context
echo "[*] Creating context..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" config set-context "${KUBE_CONTEXT_NAME}" \
  --cluster="${KUBE_CLUSTER_NAME}" \
  --user="${KUBE_USER_NAME}"

kubectl --kubeconfig="${KUBECONFIG_PATH}" config use-context "${KUBE_CONTEXT_NAME}"
echo "[OK] Context created and activated"

# Patch exec flags
echo "[*] Patching kubeconfig..."
tmpfile="$(mktemp)"
kubectl --kubeconfig="${KUBECONFIG_PATH}" config view --raw \
  | yq eval '.users[] |= (select(.name == "'"${KUBE_USER_NAME}"'").user.exec.interactiveMode = "IfAvailable" | select(.name == "'"${KUBE_USER_NAME}"'").user.exec.provideClusterInfo = false)' - \
  > "${tmpfile}" 2>/dev/null && mv "${tmpfile}" "${KUBECONFIG_PATH}" || rm -f "${tmpfile}"

echo "[OK] Kubeconfig patched"

echo ""
echo "=========================================================================="
echo ""
echo "              OpenCenter OIDC Setup Complete!"
echo ""
echo "=========================================================================="
echo ""
echo "Configuration Summary:"
echo "  * Cluster: ${KUBE_CLUSTER_NAME}"
echo "  * Context: ${KUBE_CONTEXT_NAME}"
echo "  * User: ${KUBE_USER_NAME}"
echo "  * Kubeconfig: ${KUBECONFIG_PATH}"
if [[ "${USE_EXISTING}" == "true" ]]; then
  echo "  * Backup: ${BACKUP_PATH}"
fi
echo ""
echo "Next Steps:"
echo "  1. Add krew to your PATH:"
echo "     export PATH=\"\${KREW_ROOT:-\$HOME/.krew}/bin:\$PATH\""
echo ""
echo "  2. Test your connection:"
echo "     kubectl get nodes"
echo ""
echo "  3. Follow device code authentication prompt"
echo ""