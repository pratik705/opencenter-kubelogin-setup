# OpenCenter OIDC Authentication Setup

Automated setup script for configuring Kubernetes cluster access using OpenCenter's Keycloak OIDC authentication.

## Overview

This script automates the setup process for OIDC-based authentication with OpenCenter Kubernetes clusters, including:

- Installing required dependencies (krew, kubelogin, yq)
- Configuring kubeconfig with OIDC credentials
- Setting up device code authentication flow
- Cross-platform support (macOS and Linux)

## Prerequisites

- **kubectl** must be installed and accessible in your PATH
- **curl** and **tar** commands available
- **sudo** access (only for yq installation on macOS)
- Active OpenCenter Kubernetes cluster configuration in kubeconfig

## Quick Start

### 1. Download the Script

```bash
curl -O https://raw.githubusercontent.com/pratik705/opencenter-kubelogin-setup/refs/heads/main/setup-opencenter-kube-oidc.sh
chmod +x setup-opencenter-kube-oidc.sh
```

### 2. Get Your Credentials

Contact your OpenCenter administrator to obtain:

- OIDC Issuer URL
- OIDC Client Secret
- Kubernetes Cluster Name

### 3. Run the Setup

```bash
export OIDC_ISSUER_URL="https://auth.demo.stage.sjc3.k8s.opencenter.cloud/realms/opencenter" \
export OIDC_CLIENT_SECRET="your-client-secret" \
export KUBE_CLUSTER_NAME="cluster.local" \
./setup-opencenter-kube-oidc.sh
```

### 4. Test Your Connection

```bash
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
kubectl get nodes
```

You'll be prompted for device code authentication. Follow the URL and enter the code displayed.

## Configuration Options

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OIDC_ISSUER_URL` | OpenCenter Keycloak issuer URL | `https://auth.demo.stage.sjc3.k8s.opencenter.cloud/realms/opencenter` |
| `OIDC_CLIENT_SECRET` | OIDC client secret from Keycloak | `xxxxxx` |
| `KUBE_CLUSTER_NAME` | Kubernetes cluster name in your kubeconfig | `cluster.local`|

### Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OIDC_CLIENT_ID` | `opencenter` | OIDC client ID |
| `OIDC_GRANT_TYPE` | `device-code` | OAuth2 grant type |
| `OIDC_SKIP_OPEN_BROWSER` | `true` | Skip automatic browser opening |
| `KUBE_CONTEXT_NAME` | `oidc` | Name for the kubectl context |
| `KUBE_USER_NAME` | `oidc` | Name for the kubectl user |
| `KUBECONFIG` | `~/.kube/config` | Path to kubeconfig file |

## Usage Examples

### Basic Setup

```bash
export OIDC_ISSUER_URL="https://auth.demo.stage.sjc3.k8s.opencenter.cloud/realms/opencenter"
export OIDC_CLIENT_SECRET="your-secret"
export KUBE_CLUSTER_NAME="kubernetes"

./setup-opencenter-kube-oidc.sh
```

### Using Environment File

```bash
# Create .env file
cat > .env << 'EOF'
export OIDC_ISSUER_URL="https://auth.demo.stage.sjc3.k8s.opencenter.cloud/realms/opencenter"
export OIDC_CLIENT_SECRET="your-secret"
export KUBE_CLUSTER_NAME="cluster.local"
EOF

# Source and run
source .env
./setup-opencenter-kube-oidc.sh
```

## Authentication Flow

The script configures **device code authentication**, which works as follows:

1. When you run a kubectl command (e.g., `kubectl get nodes`)
2. The OIDC login plugin generates a device code
3. You will see output like:

   ```
   Please visit the following URL in your browser: https://auth.demo.stage.sjc3.k8s.opencenter.cloud/realms/opencenter/device?user_code=PGUD-SDJD
   ```

4. Open the URL in your browser
5. Authenticate with your OpenCenter credentials
6. The kubectl command completes automatically

### Token Caching

Once authenticated, tokens are cached locally (`~/.kube/cache/oidc-login/`). You won't need to re-authenticate until the token expires.

`kubectl oidc-login clean`: Clears all cached OIDC tokens and session data used by the oidc-login plugin. This forces kubectl to perform a fresh OIDC authentication on the next command.

## What the Script Installs

### 1. Krew (kubectl plugin manager)

- **Location (Linux)**: `~/.krew/bin/kubectl-krew`
- **Location (macOS)**: `~/.krew/bin/kubectl-krew`
- **Purpose**: Manages kubectl plugins

### 2. kubelogin (oidc-login plugin)

- **Installed via**: krew
- **Purpose**: Handles OIDC authentication flow

### 3. yq (YAML processor)

- **Location (Linux)**: `~/.local/bin/yq`
- **Location (macOS)**: `/usr/local/bin/yq`
- **Purpose**: Patches kubeconfig YAML structure

## Platform Support

### Supported Operating Systems

- macOS
- Linux

### Supported Architectures

- x86_64 (Intel/AMD 64-bit)
- ARM64 (Apple Silicon M1/M2/M3, ARM servers)

## Updating Components

### Update kubelogin Plugin

```bash
kubectl krew update
kubectl krew upgrade oidc-login
```

### Update yq

```bash
# macOS
brew upgrade yq

# Linux (re-run installation)
curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" -o ~/.local/bin/yq
chmod +x ~/.local/bin/yq
```

## Uninstallation

### Remove OIDC Configuration

```bash
# Remove user and context
kubectl config delete-user oidc
kubectl config delete-context oidc
```

### Remove Installed Tools

```bash
# Remove kubelogin plugin
kubectl krew uninstall oidc-login

# Remove krew (optional)
rm -rf ~/.krew

# Remove yq (optional)
# macOS
sudo rm /usr/local/bin/yq

# Linux
rm ~/.local/bin/yq
```

## Additional Resources

- [OpenCenter Documentation](https://docs.opencenter.io)
- [kubelogin GitHub](https://github.com/int128/kubelogin)
- [Kubernetes OIDC Authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
