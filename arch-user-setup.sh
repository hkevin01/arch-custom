#!/bin/bash

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info() { echo -e "${CYAN}[>>] $1${NC}"; }
ok() { echo -e "${GREEN}[OK] $1${NC}"; }
warn() { echo -e "${RED}[!!] $1${NC}"; }

if [[ "${EUID}" -eq 0 ]]; then
  warn "Run this as your normal user, not root."
  exit 1
fi

AUR_WORKDIR="${HOME}/.cache/aur-builds"
mkdir -p "${AUR_WORKDIR}" "${HOME}/Projects"

aur_install() {
  local pkg="$1"
  local repo_url="https://aur.archlinux.org/${pkg}.git"

  if pacman -Q "$pkg" >/dev/null 2>&1; then
    ok "$pkg already installed"
    return 0
  fi

  info "Installing $pkg from AUR"
  rm -rf "${AUR_WORKDIR:?}/${pkg}"
  git clone "$repo_url" "${AUR_WORKDIR}/${pkg}"
  (
    cd "${AUR_WORKDIR}/${pkg}"
    makepkg -si --noconfirm
  )
  ok "$pkg installed"
}

install_brave() {
  if command -v brave >/dev/null 2>&1 || command -v brave-browser >/dev/null 2>&1; then
    ok "Brave already installed"
    return 0
  fi

  # If a pacman package exists (repo/third-party), use it. Otherwise AUR fallback.
  if pacman -Si brave-browser >/dev/null 2>&1; then
    info "Installing Brave via pacman package brave-browser"
    sudo pacman -S --noconfirm --needed brave-browser
    ok "Brave installed via pacman"
  else
    aur_install brave-bin
  fi
}

install_vscode_official() {
  info "Ensuring official Microsoft VS Code is installed"

  if pacman -Q code >/dev/null 2>&1; then
    warn "Removing open-source code package"
    sudo pacman -R --noconfirm code || true
  fi
  if pacman -Q code-oss >/dev/null 2>&1; then
    warn "Removing code-oss package"
    sudo pacman -R --noconfirm code-oss || true
  fi

  aur_install visual-studio-code-bin
  ok "Official VS Code setup complete"
}

setup_beastmode() {
  info "Syncing Beastmode agent/chatmode"

  if [[ ! -d "${HOME}/Projects/utility-scripts/.git" ]]; then
    git clone https://github.com/hkevin01/utility-scripts "${HOME}/Projects/utility-scripts"
  else
    git -C "${HOME}/Projects/utility-scripts" pull --ff-only || true
  fi

  if [[ -x "${HOME}/Projects/utility-scripts/scripts/sync_beastmode_to_user.sh" ]]; then
    bash "${HOME}/Projects/utility-scripts/scripts/sync_beastmode_to_user.sh"
    ok "Beastmode synced"
  else
    warn "sync_beastmode_to_user.sh not found"
  fi
}

setup_konsole_transparent() {
  info "Configuring Konsole profile with transparency"

  mkdir -p "${HOME}/.local/share/konsole" "${HOME}/.config"

  if [[ -f "/usr/share/konsole/Breeze.colorscheme" ]]; then
    cp "/usr/share/konsole/Breeze.colorscheme" "${HOME}/.local/share/konsole/Breeze.colorscheme"
  elif [[ -f "${HOME}/.local/share/konsole/Breeze.colorscheme" ]]; then
    true
  else
    cat > "${HOME}/.local/share/konsole/Breeze.colorscheme" <<'EOF'
[Background]
Color=35,38,39

[Foreground]
Color=252,252,252

[General]
Description=Breeze
Opacity=0.8
Blur=false
EOF
  fi

  if grep -q '^Opacity=' "${HOME}/.local/share/konsole/Breeze.colorscheme"; then
    sed -i 's/^Opacity=.*/Opacity=0.8/' "${HOME}/.local/share/konsole/Breeze.colorscheme"
  else
    printf '\n[General]\nOpacity=0.8\nBlur=false\n' >> "${HOME}/.local/share/konsole/Breeze.colorscheme"
  fi

  cat > "${HOME}/.local/share/konsole/Kevin_Konsole_Profile.profile" <<'EOF'
[Appearance]
ColorScheme=Breeze

[General]
Name=Kevin_Konsole_Profile
Parent=FALLBACK/
EOF

  cat > "${HOME}/.config/konsolerc" <<'EOF'
[Desktop Entry]
DefaultProfile=Kevin_Konsole_Profile.profile

[General]
ConfigVersion=1

[UiSettings]
ColorScheme=
EOF

  ok "Konsole transparency/profile configured"
}

run_privacy_scripts() {
  info "Applying privacy setup scripts"

  if [[ -f "${HOME}/Projects/utility-scripts/scripts/deploy_tracking_protection.sh" ]]; then
    sudo bash "${HOME}/Projects/utility-scripts/scripts/deploy_tracking_protection.sh"
    ok "Tracking protection deployed"
  fi

  if [[ -f "${HOME}/Projects/utility-scripts/scripts/setup_privacy_extensions.sh" ]]; then
    sudo bash "${HOME}/Projects/utility-scripts/scripts/setup_privacy_extensions.sh"
    ok "Brave privacy extensions configured"
  fi

  if [[ -f "${HOME}/Projects/utility-scripts/scripts/harden_kde_lockscreen_privacy.sh" ]]; then
    bash "${HOME}/Projects/utility-scripts/scripts/harden_kde_lockscreen_privacy.sh"
    ok "KDE lockscreen privacy hardened"
  fi

  if [[ -f "${HOME}/Projects/arch-custom/kde-dark-theme-fix.sh" ]]; then
    bash "${HOME}/Projects/arch-custom/kde-dark-theme-fix.sh" || true
  fi
}

echo -e "\n${BOLD}${CYAN}=== Arch User Setup (VS Code + Beastmode + Konsole + Brave) ===${NC}\n"

setup_konsole_transparent

sudo pacman -S --noconfirm --needed git base-devel curl

if [[ ! -d "${HOME}/Projects/arch-custom/.git" ]]; then
  git clone https://github.com/hkevin01/arch-custom "${HOME}/Projects/arch-custom"
else
  git -C "${HOME}/Projects/arch-custom" pull --ff-only || true
fi

install_brave
install_vscode_official
setup_beastmode
run_privacy_scripts

echo -e "\n${GREEN}${BOLD}All requested user setup steps are complete.${NC}"
echo "Log out and log back in to apply Konsole and KDE/GTK theme changes fully."
