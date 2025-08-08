#!/usr/bin/env bash
set -euo pipefail

### CONFIGURATION ###
MC_DIR="${HOME}/minecraft"
MC_JAR="${MC_DIR}/server.jar"
JAVA_PKG="openjdk-21-jre-headless"
JAVA_MIN_HEAP="1G"
JAVA_MAX_HEAP="2G"

### FUNCTIONS ###
install_dependencies() {
  sudo apt-get update -y
  sudo apt-get install -y "${JAVA_PKG}" nano wget ca-certificates jq
}

fetch_latest_minecraft_server_url() {
  echo "Fetching latest Minecraft server download URL..."
  # Mojang version manifest
  manifest=$(wget -qO- https://piston-data.mojang.com/mc/game/version_manifest.json)
  # Extract latest release ID
  latest_release=$(echo "$manifest" | jq -r '.latest.release')
  # Get version-specific info
  ver_info=$(echo "$manifest" | jq -r --arg ver "$latest_release" '.versions[] | select(.id == $ver)')
  url=$(echo "$ver_info" | jq -r '.url')
  # Fetch the version details JSON
  version_json=$(wget -qO- "$url")
  server_url=$(echo "$version_json" | jq -r '.downloads.server.url')
  echo "$server_url"
}

download_server_jar() {
  local url="$1"
  echo "Downloading server.jar from: $url"
  wget -O "${MC_JAR}.tmp" --progress=dot:giga "$url"
  mv "${MC_JAR}.tmp" "${MC_JAR}"
  chmod +x "${MC_JAR}"
}

first_run_to_generate_eula() {
  echo "First server run (will generate eula.txt and exit)..."
  set +e
  java -Xms${JAVA_MIN_HEAP} -Xmx${JAVA_MAX_HEAP} -jar "${MC_JAR}" nogui
  set -e
}

accept_eula() {
  if [[ ! -f "${MC_DIR}/eula.txt" ]]; then
    echo "eula.txt not found! Something went wrong." >&2
    exit 1
  fi
  sed -i 's/eula=false/eula=true/' "${MC_DIR}/eula.txt" || echo "eula=true" >> "${MC_DIR}/eula.txt"
  echo "EULA accepted (eula.txt updated)."
}

start_server() {
  echo "Starting Minecraft server (foreground)... Use CTRL+C to stop."
  exec java -Xms${JAVA_MIN_HEAP} -Xmx${JAVA_MAX_HEAP} -jar "${MC_JAR}" nogui
}

### MAIN FLOW ###
install_dependencies

mkdir -p "${MC_DIR}"
cd "${MC_DIR}"

if [[ ! -f "${MC_JAR}" ]]; then
  url=$(fetch_latest_minecraft_server_url)
  download_server_jar "$url"
else
  echo "server.jar already exists; skipping download."
fi

first_run_to_generate_eula
accept_eula
start_server
