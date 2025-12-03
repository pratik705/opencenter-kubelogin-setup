# OpenCenter OIDC Authentication Setup

Automated setup script for configuring Kubernetes cluster access using OpenCenter's Keycloak OIDC authentication.

## Overview

This script automates the setup process for OIDC-based authentication with OpenCenter Kubernetes clusters, including:

- Installing required dependencies (krew, kubelogin, yq)
- Configuring kubeconfig with OIDC credentials
- Setting up device code authentication flow
- Cross-platform support (macOS and Linux)

---

## Prerequisites

- **kubectl** must be installed and accessible in your PATH
- **curl** and **tar** commands available
- **sudo** access (only for yq installation on macOS)

---

## Quick Start

### 1. Download the Script

```bash
curl -O https://raw.githubusercontent.com/pratik705/opencenter-kubelogin-setup/refs/heads/main/setup-opencenter-kube-oidc.sh
chmod +x setup-opencenter-kube-oidc.sh
```

### 2. Get Required Details

Contact your OpenCenter administrator to obtain:

- OIDC Issuer URL
- OIDC Client Secret
- Kubernetes API details
- Kubernetes CA Certificate
- Kubernetes Cluster Name

### Interactive Mode

```bash
chmod +x setup-opencenter-kube-oidc.sh
./setup-opencenter-kube-oidc.sh
```

Follow the prompts.

### Non-Interactive Mode

Set environment variables to skip all prompts:

**Option 1: Use Existing Kubeconfig**

```bash
export KUBECONFIG=/path/to/kubeconfig
export KUBE_CLUSTER_NAME=kubernetes
export OIDC_ISSUER_URL=https://auth.example.com/realms/opencenter
export OIDC_CLIENT_ID=opencenter
export OIDC_CLIENT_SECRET=your-secret
export KUBE_CONTEXT_NAME=oidc
export KUBE_USER_NAME=oidc

./setup-opencenter-kube-oidc.sh
```

**Option 2: Create New Kubeconfig**

```bash
export KUBE_API_SERVER=https://10.0.0.1:6443
export KUBE_CLUSTER_NAME=kubernetes
export KUBE_CA_CERT=/path/to/ca.crt  # Optional
export OIDC_ISSUER_URL=https://auth.example.com/realms/opencenter
export OIDC_CLIENT_ID=opencenter
export OIDC_CLIENT_SECRET=your-secret
export KUBE_CONTEXT_NAME=oidc
export KUBE_USER_NAME=oidc

./setup-opencenter-kube-oidc.sh
```

---

## Environment Variables

### Required (for non-interactive)

| Variable | Description |
|----------|-------------|
| `OIDC_ISSUER_URL` | Keycloak issuer URL |
| `OIDC_CLIENT_SECRET` | OIDC client secret |
| `KUBE_CLUSTER_NAME` | Cluster name (for existing kubeconfig) |
| OR `KUBE_API_SERVER` | API server URL (for new kubeconfig) |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `KUBECONFIG` | `~/.kube/config` | Kubeconfig file path |
| `OIDC_CLIENT_ID` | `opencenter` | OIDC client ID |
| `KUBE_CONTEXT_NAME` | `oidc` | Context name |
| `KUBE_USER_NAME` | `oidc` | User name |
| `KUBE_CA_CERT` | - | CA certificate path |

---

## Usage Examples

### Example 1: Update Existing Kubeconfig

``` bash
# bash setup-opencenter-kube-oidc.sh

========================================================================

                   OpenCenter OIDC Authentication Setup

   This script will configure your Kubernetes cluster access using
   OpenCenter's Keycloak authentication system.

========================================================================

[*] Found existing kubeconfig at: /root/.kube/config

Do you want to use this existing kubeconfig? (y/n): y
[OK] Backed up kubeconfig to: /root/.kube/config.backup.20251203_080013

==========================================================================
                    Cluster Configuration
==========================================================================

[*] Using existing kubeconfig

Available clusters in kubeconfig:
     1 cluster.local

Enter cluster name to use: cluster.local

==========================================================================
                    OIDC Configuration
==========================================================================

Enter OIDC Issuer URL (e.g., <https://auth.example.com/realms/opencenter>): <https://auth.example.com/realms/opencenter>
Enter OIDC Client ID (default: opencenter):
Enter OIDC Client Secret:
Enter context name (default: oidc):
Enter user name (default: oidc):

==========================================================================
                    Installing Dependencies
==========================================================================

[+] Installing krew...
tar: Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.com.apple.provenance'
tar: Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.com.apple.provenance'
Adding "default" plugin index from <https://github.com/kubernetes-sigs/krew-index.git>.
Updated the local copy of plugin index.
Installing plugin: krew
Installed plugin: krew
\
 | Use this plugin:
 |  kubectl krew
 | Documentation:
 |  <https://krew.sigs.k8s.io/>
 | Caveats:
 | \
 |  | krew is now installed! To start using kubectl plugins, you need to add
 |  | krew's installation directory to your PATH:
 |  |
 |  |   * macOS/Linux:
 |  |     - Add the following to your ~/.bashrc or ~/.zshrc:
 |  |         export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
 |  |     - Restart your shell.
 |  |
 |  |   * Windows: Add %USERPROFILE%\.krew\bin to your PATH environment variable
 |  |
 |  | To list krew commands and to get help, run:
 |  |   $ kubectl krew
 |  | For a full list of available plugins, run:
 |  |   $ kubectl krew search
 |  |
 |  | You can find documentation at
 |  |   <https://krew.sigs.k8s.io/docs/user-guide/quickstart/>.
 | /
/
[OK] Krew installed
[+] Installing kubectl oidc-login plugin...
Updated the local copy of plugin index.
Installing plugin: oidc-login
Installed plugin: oidc-login
\
 | Use this plugin:
 |  kubectl oidc-login
 | Documentation:
 |  <https://github.com/int128/kubelogin>
 | Caveats:
 | \
 |  | You need to setup the OIDC provider, Kubernetes API server, role binding and kubeconfig.
 | /
/
WARNING: You installed plugin "oidc-login" from the krew-index plugin repository.
   These plugins are not audited for security by the Krew maintainers.
   Run them at your own risk.
[OK] oidc-login plugin installed
[+] Installing yq...
[OK] yq installed

==========================================================================
                    Configuring Kubeconfig
==========================================================================

[*] Setting up OIDC user...
User "oidc" set.
[OK] OIDC user configured
[*] Creating context...
Context "oidc" created.
Switched to context "oidc".
[OK] Context created and activated
[*] Patching kubeconfig...
[OK] Kubeconfig patched

==========================================================================

              OpenCenter OIDC Setup Complete!

==========================================================================

Configuration Summary:

- Cluster: cluster.local
- Context: oidc
- User: oidc
- Kubeconfig: /root/.kube/config
- Backup: /root/.kube/config.backup.20251203_080013

Next Steps:

  1. Add krew to your PATH:
     export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

  2. Test your connection:
     kubectl get nodes

  3. Follow device code authentication prompt

# kubectl config get-contexts
CURRENT   NAME                             CLUSTER         AUTHINFO           NAMESPACE
          kubernetes-admin@cluster.local   cluster.local   kubernetes-admin
*         oidc                             cluster.local   oidc     

# export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
# kubectl get nodes
Please visit the following URL in your browser: <https://auth.example.com/realms/opencenter/device?user_code=TAAK-DFDE>
```

### Example 2: Create New Kubeconfig (Non-Interactive)

``` bash
export KUBE_API_SERVER=<https://10.0.0.1:443>
export KUBE_CA_CERT=/root/ca.crt
export OIDC_ISSUER_URL=<https://auth.example.com/realms/opencenter>
export OIDC_CLIENT_SECRET=xxxxxxxxxxx
export OIDC_CLIENT_ID=opencenter
export KUBE_CONTEXT_NAME=oidc
export KUBE_USER_NAME=oidc
export KUBE_CLUSTER_NAME=staging

# bash setup-opencenter-kube-oidc.sh

========================================================================

                   OpenCenter OIDC Authentication Setup

   This script will configure your Kubernetes cluster access using
   OpenCenter's Keycloak authentication system.

========================================================================

[*] Running in non-interactive mode (environment variables detected)

==========================================================================
                    Installing Dependencies
==========================================================================

[+] Installing krew...
tar: Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.com.apple.provenance'
tar: Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.com.apple.provenance'
Adding "default" plugin index from <https://github.com/kubernetes-sigs/krew-index.git>.
Updated the local copy of plugin index.
Installing plugin: krew
Installed plugin: krew
\
 | Use this plugin:
 |  kubectl krew
 | Documentation:
 |  <https://krew.sigs.k8s.io/>
 | Caveats:
 | \
 |  | krew is now installed! To start using kubectl plugins, you need to add
 |  | krew's installation directory to your PATH:
 |  |
 |  |   * macOS/Linux:
 |  |     - Add the following to your ~/.bashrc or ~/.zshrc:
 |  |         export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
 |  |     - Restart your shell.
 |  |
 |  |   * Windows: Add %USERPROFILE%\.krew\bin to your PATH environment variable
 |  |
 |  | To list krew commands and to get help, run:
 |  |   $ kubectl krew
 |  | For a full list of available plugins, run:
 |  |   $ kubectl krew search
 |  |
 |  | You can find documentation at
 |  |   <https://krew.sigs.k8s.io/docs/user-guide/quickstart/>.
 | /
/
[OK] Krew installed
[+] Installing kubectl oidc-login plugin...
Updated the local copy of plugin index.
Installing plugin: oidc-login
Installed plugin: oidc-login
\
 | Use this plugin:
 |  kubectl oidc-login
 | Documentation:
 |  <https://github.com/int128/kubelogin>
 | Caveats:
 | \
 |  | You need to setup the OIDC provider, Kubernetes API server, role binding and kubeconfig.
 | /
/
WARNING: You installed plugin "oidc-login" from the krew-index plugin repository.
   These plugins are not audited for security by the Krew maintainers.
   Run them at your own risk.
[OK] oidc-login plugin installed
[+] Installing yq...
[OK] yq installed

==========================================================================
                    Configuring Kubeconfig
==========================================================================

[*] Setting up cluster configuration...
Cluster "staging" set.
[OK] Cluster configured with CA certificate
[*] Setting up OIDC user...
User "oidc" set.
[OK] OIDC user configured
[*] Creating context...
Context "oidc" created.
Switched to context "oidc".
[OK] Context created and activated
[*] Patching kubeconfig...
[OK] Kubeconfig patched

==========================================================================

              OpenCenter OIDC Setup Complete!

==========================================================================

Configuration Summary:

- Cluster: staging
- Context: oidc
- User: oidc
- Kubeconfig: /root/.kube/config

Next Steps:

  1. Add krew to your PATH:
     export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

  2. Test your connection:
     kubectl get nodes

  3. Follow device code authentication prompt

---

# kubectl config get-contexts
CURRENT   NAME   CLUSTER   AUTHINFO   NAMESPACE
*         oidc   staging   oidc

# export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
# kubectl get nodes
Please visit the following URL in your browser: <https://auth.example.com/realms/opencenter/device?user_code=GLNY-DFDD>
```

---

## Additional Resources

- [OpenCenter](https://github.com/rackerlabs/openCenter-gitops-base)
- [kubelogin GitHub](https://github.com/int128/kubelogin)
- [Kubernetes OIDC Authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
