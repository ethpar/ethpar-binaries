#!/usr/bin/env bash
set -euo pipefail

# Parse required command line arguments using getopt
OPTIONS=$(getopt -o '' --long besu:,teku:,mode:,besu-repo:,teku-repo: -- "$@")
if [ $? -ne 0 ]; then
  echo "Usage: $0 [--besu <BESU_VERSION>] [--teku <TEKU_VERSION>] --mode <mainnet|testnet> [--besu-repo <public|private>] [--teku-repo <public|private>]"
  echo "Example: $0 --besu 25.8.1 --teku 25.8.0 --mode testnet"
  echo "Example: $0 --besu 26.3-develop-61cf496 --besu-repo private --mode testnet"
  exit 1
fi
eval set -- "$OPTIONS"

BESU_TAG=""
TEKU_TAG=""
MODE=""
BESU_REPO="public"
TEKU_REPO="public"
while true; do
  case "$1" in
    --besu)
      BESU_TAG="$2"; shift 2;;
    --teku)
      TEKU_TAG="$2"; shift 2;;
    --mode)
      MODE="$2"; shift 2;;
    --besu-repo)
      BESU_REPO="$2"; shift 2;;
    --teku-repo)
      TEKU_REPO="$2"; shift 2;;
    --)
      shift; break;;
    * ) break ;;
  esac
done

# Validate required parameters
if [[ -z "${MODE}" ]]; then
  echo "Usage: $0 [--besu <BESU_VERSION>] [--teku <TEKU_VERSION>] --mode <mainnet|testnet> [--besu-repo <public|private>] [--teku-repo <public|private>]"
  echo "Example: $0 --besu 25.8.1 --teku 25.8.0 --mode testnet"
  echo "Example: $0 --besu 26.3-develop-61cf496 --besu-repo private --mode testnet"
  exit 1
fi

# Validate MODE
if [[ "$MODE" != "mainnet" && "$MODE" != "testnet" ]]; then
  echo "Error: --mode must be either 'mainnet' or 'testnet'"
  exit 1
fi

# Validate repository parameters
if [[ "$BESU_REPO" != "public" && "$BESU_REPO" != "private" ]]; then
  echo "Error: --besu-repo must be either 'public' or 'private'"
  exit 1
fi

if [[ "$TEKU_REPO" != "public" && "$TEKU_REPO" != "private" ]]; then
  echo "Error: --teku-repo must be either 'public' or 'private'"
  exit 1
fi

# Function to check GitHub token access to private repos
check_github_token_access() {
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "❌ GITHUB_TOKEN environment variable not set."
    echo "   To access private repositories, please set your GitHub Personal Access Token:"
    echo "   export GITHUB_TOKEN=ghp_your_token_here"
    echo "   Your token needs 'Contents' read access to private repositories."
    exit 1
  fi
  
  echo "🔑 GitHub token found, proceeding with download..."
  
  # Skip heavy validation and let the actual download handle permission issues
  # This avoids false negatives from API endpoint permission checks
}

# Function to get the actual download URL for private repository releases
get_private_release_download_url() {
  local client="$1"
  local tag="$2"
  
  echo "🔍 Getting download URL for ${client} ${tag} from private repository..." >&2
  
  # Get the release info from GitHub API
  local release_info
  release_info=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                      -H "Accept: application/vnd.github.v3+json" \
                      "https://api.github.com/repos/parallellogic-io/${client,,}.par/releases/tags/${client}-${tag}")
  
  if [[ $? -ne 0 ]]; then
    echo "❌ Failed to get release info for ${client} ${tag}" >&2
    exit 1
  fi
  
  # Extract the asset URL from the release info
  local asset_url
  asset_url=$(echo "$release_info" | grep -A 10 '"assets":' | grep '"url":' | head -1 | sed 's/.*"url": "\([^"]*\)".*/\1/')
  
  if [[ -z "$asset_url" ]]; then
    echo "❌ No asset URL found for ${client} ${tag}" >&2
    echo "Debug: API response was:" >&2
    echo "$release_info" >&2
    exit 1
  fi
  
  echo "$asset_url"
}


# Function to construct download URL based on repository selection
get_download_url() {
  local client="$1"
  local tag="$2"
  local repo="$3"
  
  if [[ "$repo" == "public" ]]; then
    echo "https://github.com/ethpar/ethpar-binaries/releases/download/${client}-${tag}/${client,,}-${tag}.tar.gz"
  else
    # For private repos, get the actual download URL from GitHub API
    get_private_release_download_url "$client" "$tag"
  fi
}


# Install Besu if BESU_TAG is set
if [[ -n "${BESU_TAG:-}" ]]; then
  BESU_INSTALL_DIR="/usr/local/bin/"
  if [ -d "$BESU_INSTALL_DIR/besu-${BESU_TAG}" ]; then
    echo "⚠️ Besu ${BESU_TAG} already installed at ${BESU_INSTALL_DIR}, skipping."
  else
    BESU_URL=$(get_download_url "Besu" "$BESU_TAG" "$BESU_REPO")
    
    if [[ "$BESU_REPO" == "private" ]]; then
      check_github_token_access
      echo "📦 Downloading Besu ${BESU_TAG} from private repository..."
      cd "$HOME"
      wget --header="Authorization: token $GITHUB_TOKEN" \
           --header="Accept: application/octet-stream" \
           -O "besu-${BESU_TAG}.tar.gz" "$BESU_URL"
    else
      echo "📦 Downloading Besu ${BESU_TAG} from public repository..."
      cd "$HOME"
      wget -O "besu-${BESU_TAG}.tar.gz" "$BESU_URL"
    fi
    
    tar -xvf "besu-${BESU_TAG}.tar.gz" -C "$HOME"
    rm "besu-${BESU_TAG}.tar.gz"
    sudo mv "$HOME/besu-${BESU_TAG}" "$BESU_INSTALL_DIR"
  fi
fi


# Install Teku if TEKU_TAG is set
if [[ -n "${TEKU_TAG:-}" ]]; then
  TEKU_INSTALL_DIR="/usr/local/bin/"
  if [ -d "$TEKU_INSTALL_DIR/teku-${TEKU_TAG}" ]; then
    echo "⚠️ Teku ${TEKU_TAG} already installed at ${TEKU_INSTALL_DIR}, skipping."
  else
    TEKU_URL=$(get_download_url "Teku" "$TEKU_TAG" "$TEKU_REPO")
    
    if [[ "$TEKU_REPO" == "private" ]]; then
      check_github_token_access
      echo "📦 Downloading Teku ${TEKU_TAG} from private repository..."
      cd "$HOME"
      wget --header="Authorization: token $GITHUB_TOKEN" -O "teku-${TEKU_TAG}.tar.gz" "$TEKU_URL"
    else
      echo "📦 Downloading Teku ${TEKU_TAG} from public repository..."
      cd "$HOME"
      wget -O "teku-${TEKU_TAG}.tar.gz" "$TEKU_URL"
    fi
    
    tar -xvf "teku-${TEKU_TAG}.tar.gz" -C "$HOME"
    rm "teku-${TEKU_TAG}.tar.gz"
    sudo mv "$HOME/teku-${TEKU_TAG}" "$TEKU_INSTALL_DIR"
  fi
fi


# Update systemd service files with backups
if [[ "$MODE" == "mainnet" ]]; then
  EXECUTION_SERVICE="/etc/systemd/system/execution.service"
  CONSENSUS_SERVICE="/etc/systemd/system/consensus.service"
  EXECUTION_SERVICE_NAME="execution"
  CONSENSUS_SERVICE_NAME="consensus"
else
  EXECUTION_SERVICE="/etc/systemd/system/execution2.service"
  CONSENSUS_SERVICE="/etc/systemd/system/consensus2.service"
  EXECUTION_SERVICE_NAME="execution2"
  CONSENSUS_SERVICE_NAME="consensus2"
fi

# Backup (always overwrite previous .bak)
sudo cp "$EXECUTION_SERVICE" "${EXECUTION_SERVICE}.bak"
sudo cp "$CONSENSUS_SERVICE" "${CONSENSUS_SERVICE}.bak"

# Update service files to reference the desired Besu/Teku versions if set
if [[ -n "${BESU_TAG:-}" ]]; then
  sudo sed -i "s|ExecStart=/usr/local/bin.*/bin/besu|ExecStart=/usr/local/bin/besu-${BESU_TAG}/bin/besu|g" "$EXECUTION_SERVICE"
  sudo systemctl daemon-reload
  sudo systemctl restart "$EXECUTION_SERVICE_NAME"
fi
if [[ -n "${TEKU_TAG:-}" ]]; then
  sudo sed -i "s|ExecStart=/usr/local/bin.*/bin/teku|ExecStart=/usr/local/bin/teku-${TEKU_TAG}/bin/teku|g" "$CONSENSUS_SERVICE"
  sudo systemctl daemon-reload
  sudo systemctl restart "$CONSENSUS_SERVICE_NAME"
fi

echo "✅ Update complete."
if [[ -n "${BESU_TAG:-}" ]]; then
  echo "Besu ${BESU_TAG} installed/updated from ${BESU_REPO} repository."
fi
if [[ -n "${TEKU_TAG:-}" ]]; then
  echo "Teku ${TEKU_TAG} installed/updated from ${TEKU_REPO} repository."
fi
echo "Previous service files have been created at ${EXECUTION_SERVICE}.bak and ${CONSENSUS_SERVICE}.bak"
