#!/usr/bin/env bash
# Install agy-codex, download CLIProxyAPI binary, and register with CC Switch.
#
# Usage:
#   ./install.sh                # install binary + config + symlink + register CC Switch
#   ./install.sh --launchd      # also install macOS LaunchAgent to auto-start proxy on login
#   ./install.sh --update       # force re-download latest CLIProxyAPI release
#   ./install.sh --uninstall    # remove symlinks, LaunchAgent, and CC Switch provider entry

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPA_DIR="${AGY_CPA_DIR:-${HOME}/.cli-proxy-api}"
BIN_DIR="${HOME}/.local/bin"
LAUNCHD_LABEL="com.dremig.agy-codex-proxy"
LAUNCHD_PLIST="${HOME}/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"

DO_LAUNCHD=0
DO_UPDATE=0
DO_UNINSTALL=0

for arg in "$@"; do
  case "${arg}" in
    --launchd) DO_LAUNCHD=1 ;;
    --update) DO_UPDATE=1 ;;
    --uninstall) DO_UNINSTALL=1 ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
  esac
done

info() { printf '==> %s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if [[ "${DO_UNINSTALL}" -eq 1 ]]; then
  info "Stopping proxy and removing agy-codex..."
  "${REPO_ROOT}/bin/agy-codex" stop 2>/dev/null || true
  if [[ -f "${LAUNCHD_PLIST}" ]]; then
    launchctl unload "${LAUNCHD_PLIST}" 2>/dev/null || true
    rm -f "${LAUNCHD_PLIST}"
    info "Removed LaunchAgent: ${LAUNCHD_PLIST}"
  fi
  rm -f "${BIN_DIR}/agy-codex" "${BIN_DIR}/cli-proxy-api"
  python3 "${REPO_ROOT}/scripts/register-cc-switch.py" --remove 2>/dev/null || true
  info "Uninstall complete. (Credentials and config in ${CPA_DIR} were kept.)"
  exit 0
fi

mkdir -p "${CPA_DIR}" "${BIN_DIR}"

detect_asset_suffix() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "${os}" in
    darwin) os="darwin" ;;
    linux) os="linux" ;;
    *) die "Unsupported OS: ${os}" ;;
  esac
  case "${arch}" in
    arm64|aarch64) arch="aarch64" ;;
    x86_64|amd64) arch="amd64" ;;
    *) die "Unsupported architecture: ${arch}" ;;
  esac
  echo "${os}_${arch}"
}

if [[ ! -x "${CPA_DIR}/cli-proxy-api" || "${DO_UPDATE}" -eq 1 ]]; then
  suffix="$(detect_asset_suffix)"
  info "Fetching latest CLIProxyAPI release for ${suffix}..."
  download_url="$(
    curl -fsSL https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest \
      | grep -Eo "\"browser_download_url\": *\"[^\"]*_${suffix}\\.tar\\.gz\"" \
      | head -n 1 \
      | cut -d'"' -f4
  )"
  [[ -n "${download_url}" ]] || die "Failed to locate CLIProxyAPI release asset for ${suffix}"
  info "Downloading ${download_url}..."
  curl -fsSL "${download_url}" | tar -xz -C "${CPA_DIR}"
  chmod +x "${CPA_DIR}/cli-proxy-api"
else
  info "CLIProxyAPI binary already installed at ${CPA_DIR}/cli-proxy-api"
fi

if [[ ! -f "${CPA_DIR}/config.yaml" ]]; then
  info "Writing default config to ${CPA_DIR}/config.yaml"
  cp "${REPO_ROOT}/config/config.example.yaml" "${CPA_DIR}/config.yaml"
else
  info "Keeping existing ${CPA_DIR}/config.yaml"
fi

chmod +x "${REPO_ROOT}/bin/agy-codex" "${REPO_ROOT}/scripts/register-cc-switch.py"
ln -sf "${REPO_ROOT}/bin/agy-codex" "${BIN_DIR}/agy-codex"
ln -sf "${CPA_DIR}/cli-proxy-api" "${BIN_DIR}/cli-proxy-api"
info "Linked agy-codex -> ${BIN_DIR}/agy-codex"

info "Syncing Antigravity (AGY) provider into CC Switch (if installed)..."
python3 "${REPO_ROOT}/scripts/register-cc-switch.py" || true

if [[ "${DO_LAUNCHD}" -eq 1 && "$(uname -s)" == "Darwin" ]]; then
  mkdir -p "${HOME}/Library/LaunchAgents"
  cat >"${LAUNCHD_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LAUNCHD_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${CPA_DIR}/cli-proxy-api</string>
    <string>-config</string>
    <string>${CPA_DIR}/config.yaml</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${CPA_DIR}/proxy.log</string>
  <key>StandardErrorPath</key>
  <string>${CPA_DIR}/proxy.log</string>
</dict>
</plist>
EOF
  launchctl unload "${LAUNCHD_PLIST}" 2>/dev/null || true
  launchctl load "${LAUNCHD_PLIST}"
  info "Installed and loaded macOS LaunchAgent: ${LAUNCHD_PLIST}"
fi

info "Done! Run 'agy-codex' to login and start Codex with Antigravity."
