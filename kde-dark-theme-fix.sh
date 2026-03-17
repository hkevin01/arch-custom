#!/bin/bash

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info() { echo -e "${CYAN}[>>] $1${NC}"; }
ok() { echo -e "${GREEN}[OK] $1${NC}"; }
warn() { echo -e "${RED}[!!] $1${NC}"; }
die() { echo -e "${RED}[ERR] $1${NC}"; exit 1; }

resolve_target_user() {
  if [[ -n "${TARGET_USER:-}" ]]; then
    echo "$TARGET_USER"
    return
  fi

  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    echo "$SUDO_USER"
    return
  fi

  echo "${USER:-kevin}"
}

TARGET_USER="$(resolve_target_user)"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

[[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] || die "Could not resolve home for user '$TARGET_USER'"

echo -e "\n${BOLD}${CYAN}=== KDE Dark Theme Fix (Arch) ===${NC}\n"
info "Target user: $TARGET_USER"

if ! command -v sudo >/dev/null 2>&1; then
  die "sudo is required for package and system file changes"
fi

info "Installing kde-gtk-config"
sudo pacman -S --noconfirm --needed kde-gtk-config
ok "kde-gtk-config installed"

info "Setting QT_QPA_PLATFORMTHEME=kde in /etc/environment"
if sudo grep -q '^QT_QPA_PLATFORMTHEME=' /etc/environment 2>/dev/null; then
  sudo sed -i 's/^QT_QPA_PLATFORMTHEME=.*/QT_QPA_PLATFORMTHEME=kde/' /etc/environment
else
  echo 'QT_QPA_PLATFORMTHEME=kde' | sudo tee -a /etc/environment >/dev/null
fi
ok "/etc/environment updated"

info "Configuring GTK dark theme for user"
mkdir -p "$TARGET_HOME/.config/gtk-3.0" "$TARGET_HOME/.config/gtk-4.0"

cat > "$TARGET_HOME/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Breeze-Dark
gtk-application-prefer-dark-theme=1
EOF

cat > "$TARGET_HOME/.config/gtk-4.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Breeze-Dark
gtk-application-prefer-dark-theme=1
EOF

sudo chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.config/gtk-3.0" "$TARGET_HOME/.config/gtk-4.0"
ok "GTK dark theme defaults written"

if command -v kwriteconfig6 >/dev/null 2>&1; then
  info "Setting KDE color scheme defaults for user"
  sudo -u "$TARGET_USER" kwriteconfig6 --file "$TARGET_HOME/.config/kdeglobals" --group General --key ColorScheme BreezeDark || true
  sudo -u "$TARGET_USER" kwriteconfig6 --file "$TARGET_HOME/.config/kdeglobals" --group KDE --key widgetStyle Breeze || true
  ok "KDE defaults updated"
else
  warn "kwriteconfig6 not found; skipping direct KDE config writes"
fi

patch_desktop_exec() {
  local desktop_file="$1"
  local exec_cmd="$2"

  [[ -f "$desktop_file" ]] || return 0

  info "Patching $desktop_file"
  sudo cp -n "$desktop_file" "${desktop_file}.bak" || true
  sudo sed -i "s|^Exec=.*|Exec=env QT_QUICK_CONTROLS_STYLE=org.kde.desktop ${exec_cmd}|" "$desktop_file"
  ok "Patched $desktop_file"
}

patch_desktop_exec "/usr/share/applications/systemsettings.desktop" "systemsettings"
patch_desktop_exec "/usr/share/applications/systemsettings5.desktop" "systemsettings5"

echo ""
ok "Dark theme fixes applied"
echo ""
echo "Next steps:"
echo "  1. Log out and log back in"
echo "  2. Open System Settings -> Colors & Themes -> Application Style"
echo "  3. Confirm GTK theme is Breeze Dark"
echo ""
echo "Quick test command:"
echo "  env QT_QUICK_CONTROLS_STYLE=org.kde.desktop systemsettings"
