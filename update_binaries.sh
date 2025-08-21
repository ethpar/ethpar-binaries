#!/usr/bin/env bash
set -euo pipefail

# === Install Besu ===
BESU_TAG="25.8.1"
BESU_URL="https://github.com/ethpar/ethpar-binaries/releases/download/Besu-${BESU_TAG}/besu-${BESU_TAG}.tar"
BESU_INSTALL_DIR="/usr/local/bin/besu${BESU_TAG}"

if [ -d "$BESU_INSTALL_DIR" ]; then
  echo "⚠️ Besu ${BESU_TAG} already installed at ${BESU_INSTALL_DIR}, skipping."
else
  cd "$HOME"
  wget -O "besu-${BESU_TAG}.tar" "$BESU_URL"
  tar -xvf "besu-${BESU_TAG}.tar" -C "$HOME"
  rm "besu-${BESU_TAG}.tar"
  sudo mv "$HOME/besu" "$BESU_INSTALL_DIR"
fi

# === Install Teku ===
TEKU_TAG="25.8.0"
TEKU_URL="https://github.com/ethpar/ethpar-binaries/releases/download/Teku-${TEKU_TAG}/teku-${TEKU_TAG}.tar"
TEKU_INSTALL_DIR="/usr/local/bin/teku${TEKU_TAG}"

if [ -d "$TEKU_INSTALL_DIR" ]; then
  echo "⚠️ Teku ${TEKU_TAG} already installed at ${TEKU_INSTALL_DIR}, skipping."
else
  cd "$HOME"
  wget -O "teku-${TEKU_TAG}.tar" "$TEKU_URL"
  tar -xvf "teku-${TEKU_TAG}.tar" -C "$HOME"
  rm "teku-${TEKU_TAG}.tar"
  sudo mv "$HOME/teku" "$TEKU_INSTALL_DIR"
fi

# === Update systemd service files with backups ===
EXECUTION_SERVICE="/etc/systemd/system/execution2.service"
CONSENSUS_SERVICE="/etc/systemd/system/consensus2.service"

# Backup (always overwrite previous .bak)
sudo cp "$EXECUTION_SERVICE" "${EXECUTION_SERVICE}.bak"
sudo cp "$CONSENSUS_SERVICE" "${CONSENSUS_SERVICE}.bak"

# Replace paths
sudo sed -i "s|/usr/local/bin.*/bin/besu|${BESU_INSTALL_DIR}/bin/besu|g" "$EXECUTION_SERVICE"
sudo sed -i "s|/usr/local/bin.*/bin/teku|${TEKU_INSTALL_DIR}/bin/teku|g" "$CONSENSUS_SERVICE"

# === Reload and restart services ===
echo "Restarting Besu and Teku services"
sudo systemctl daemon-reload
sudo systemctl restart execution2
sudo systemctl restart consensus2

echo "✅ Besu ${BESU_TAG} and Teku ${TEKU_TAG} installed, service files updated, and services restarted."
echo "Previous service files have been created at ${EXECUTION_SERVICE}.bak and ${CONSENSUS_SERVICE}.bak"
