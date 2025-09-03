#!/usr/bin/env bash
set -euo pipefail

# Parse required command line arguments using getopt
OPTIONS=$(getopt -o '' --long besu:,teku:,mode: -- "$@")
if [ $? -ne 0 ]; then
  echo "Usage: $0 --besu <BESU_VERSION> --teku <TEKU_VERSION> --mode <mainnet|testnet>"
  echo "Example: $0 --besu 25.8.1 --teku 25.8.0 --mode testnet"
  exit 1
fi
eval set -- "$OPTIONS"

BESU_TAG=""
TEKU_TAG=""
MODE=""
while true; do
  case "$1" in
    --besu)
      BESU_TAG="$2"; shift 2;;
    --teku)
      TEKU_TAG="$2"; shift 2;;
    --mode)
      MODE="$2"; shift 2;;
    --)
      shift; break;;
    * ) break ;;
  esac
done

# Validate required parameters
if [[ -z "$BESU_TAG" || -z "$TEKU_TAG" || -z "$MODE" ]]; then
  echo "Usage: $0 --besu <BESU_VERSION> --teku <TEKU_VERSION> --mode <mainnet|testnet>"
  echo "Example: $0 --besu 25.8.1 --teku 25.8.0 --mode testnet"
  exit 1
fi

# Validate MODE
if [[ "$MODE" != "mainnet" && "$MODE" != "testnet" ]]; then
  echo "Error: --mode must be either 'mainnet' or 'testnet'"
  exit 1
fi

# Install Besu
BESU_URL="https://github.com/ethpar/ethpar-binaries/releases/download/Besu-${BESU_TAG}/besu-${BESU_TAG}.tar.gz"
BESU_INSTALL_DIR="/usr/local/bin/"

if [ -d "$BESU_INSTALL_DIR/besu-${BESU_TAG}" ]; then
  echo "⚠️ Besu ${BESU_TAG} already installed at ${BESU_INSTALL_DIR}, skipping."
else
  cd "$HOME"
  wget -O "besu-${BESU_TAG}.tar.gz" "$BESU_URL"
  tar -xvf "besu-${BESU_TAG}.tar.gz" -C "$HOME"
  rm "besu-${BESU_TAG}.tar.gz"
  sudo mv "$HOME/besu-${BESU_TAG}" "$BESU_INSTALL_DIR"
fi

# Install Teku
TEKU_URL="https://github.com/ethpar/ethpar-binaries/releases/download/Teku-${TEKU_TAG}/teku-${TEKU_TAG}.tar.gz"
TEKU_INSTALL_DIR="/usr/local/bin/"

if [ -d "$TEKU_INSTALL_DIR/teku-${TEKU_TAG}" ]; then
  echo "⚠️ Teku ${TEKU_TAG} already installed at ${TEKU_INSTALL_DIR}, skipping."
else
  cd "$HOME"
  wget -O "teku-${TEKU_TAG}.tar.gz" "$TEKU_URL"
  tar -xvf "teku-${TEKU_TAG}.tar.gz" -C "$HOME"
  rm "teku-${TEKU_TAG}.tar.gz"
  sudo mv "$HOME/teku-${TEKU_TAG}" "$TEKU_INSTALL_DIR"
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

# Replace paths
sudo sed -i "s|/usr/local/bin.*/bin/besu|${BESU_INSTALL_DIR}/bin/besu|g" "$EXECUTION_SERVICE"
sudo sed -i "s|/usr/local/bin.*/bin/teku|${TEKU_INSTALL_DIR}/bin/teku|g" "$CONSENSUS_SERVICE"

# Reload and restart services
echo "Restarting Besu and Teku services"
sudo systemctl daemon-reload
sudo systemctl restart "$EXECUTION_SERVICE_NAME"
sudo systemctl restart "$CONSENSUS_SERVICE_NAME"

echo "✅ Besu ${BESU_TAG} and Teku ${TEKU_TAG} installed, service files updated, and services restarted."
echo "Previous service files have been created at ${EXECUTION_SERVICE}.bak and ${CONSENSUS_SERVICE}.bak"
