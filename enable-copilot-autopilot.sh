#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() {
  echo -e "${CYAN}[>>] $1${NC}"
}

ok() {
  echo -e "${GREEN}[OK] $1${NC}"
}

warn() {
  echo -e "${YELLOW}[!!] $1${NC}"
}

die() {
  echo -e "${RED}[ERR] $1${NC}"
  exit 1
}

run_privileged() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "Need root privileges to install jq automatically. Install sudo or run as root."
  fi
}

ensure_jq() {
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi

  warn "jq is missing. Attempting to install it automatically."

  if command -v pacman >/dev/null 2>&1; then
    run_privileged pacman -Sy --noconfirm jq
  elif command -v apt-get >/dev/null 2>&1; then
    run_privileged apt-get update
    run_privileged apt-get install -y jq
  elif command -v dnf >/dev/null 2>&1; then
    run_privileged dnf install -y jq
  elif command -v zypper >/dev/null 2>&1; then
    run_privileged zypper --non-interactive install jq
  else
    die "Unsupported package manager. Install jq manually and re-run this script."
  fi

  command -v jq >/dev/null 2>&1 || die "jq installation completed but jq is still not available in PATH."
  ok "Installed jq"
}

SETTINGS_DIR="${HOME}/.config/Code/User"
SETTINGS_FILE="${SETTINGS_DIR}/settings.json"
BACKUP_DIR="${HOME}/.local/share/vscode-state-backups/manual"
BACKUP_FILE="${BACKUP_DIR}/settings.$(date +%Y%m%d-%H%M%S).json"

mkdir -p "$SETTINGS_DIR" "$BACKUP_DIR"

ensure_jq

if [[ -f "$SETTINGS_FILE" ]]; then
  cp "$SETTINGS_FILE" "$BACKUP_FILE"
  ok "Backed up existing settings to $BACKUP_FILE"
else
  printf '{}\n' > "$SETTINGS_FILE"
fi

tmp_file="$(mktemp)"

jq '
  . + {
    "github.copilot.chat.enabled": true,
    "github.copilot.chat.alternateGptPrompt.enabled": true,
    "chat.agent.maxRequests": 100,
    "chat.todoListTool.enabled": true,
    "chat.autopilot.enabled": true,
    "chat.tools.terminal.autoApprove": {
      "ls": true,
      "pwd": true,
      "cat": true,
      "grep": true,
      "rg": true,
      "find": true,
      "head": true,
      "tail": true,
      "sed": true,
      "awk": true,
      "wc": true,
      "sort": true,
      "uniq": true,
      "git status": true,
      "git diff": true,
      "git log": true,
      "python --version": true,
      "node --version": true
    },
    "chat.tools.terminal.ignoreDefaultAutoApproveRules": false,
    "chat.tools.terminal.autoReplyToPrompts": false,
    "chat.tools.terminal.blockDetectedFileWrites": "outsideWorkspace",
    "chat.tools.urls.autoApprove": [],
    "chat.tools.global.autoApprove": false,
    "chat.agentFilesLocations": [
      "~/.copilot/agents",
      "~/.config/Code/User/agents"
    ],
    "chat.useAgentsMdFile": true,
    "chat.useAgentSkills": true,
    "chat.tools.terminal.sandbox.enabled": false,
    "terminal.integrated.shellIntegration.enabled": true,
    "terminal.integrated.shellIntegration.decorationsEnabled": "both",
    "terminal.integrated.suggest.enabled": true,
    "terminal.integrated.suggest.quickSuggestions": true,
    "terminal.integrated.confirmOnExit": "never",
    "terminal.integrated.confirmOnKill": "never",
    "security.workspace.trust.enabled": false
  }
' "$SETTINGS_FILE" > "$tmp_file"

mv "$tmp_file" "$SETTINGS_FILE"

ok "Updated VS Code user settings: $SETTINGS_FILE"
echo ""
warn "Notes:"
echo "- This script only writes documented settings that currently exist in VS Code/Copilot docs."
echo "- It does not enable unsupported fake keys such as tools.terminal.allowAnyCommand."
echo "- It keeps global tool auto-approval disabled because that removes critical protections."
echo "- Sudo commands are not globally auto-approved by this script."
echo ""
echo "Open VS Code and review settings with:"
echo "  Preferences: Open User Settings (JSON)"
