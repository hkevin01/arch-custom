#!/usr/bin/env bash
# project-bootstrap.sh — scaffold any project with memory-bank, CI, .vscode, docs, and Copilot config.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/hkevin01/arch-custom/main/project-bootstrap.sh | bash
#   curl -fsSL ... | bash -s -- /path/to/project

set -euo pipefail

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' CYAN='\033[0;36m' NC='\033[0m'
info() { echo -e "${CYAN}[>>] $1${NC}"; }
ok()   { echo -e "${GREEN}[OK] $1${NC}"; }
skip() { echo -e "${YELLOW}[--] $1 (skipped — already exists)${NC}"; }

TARGET="${1:-$PWD}"
mkdir -p "$TARGET"
cd "$TARGET"
PROJECT_NAME="$(basename "$(pwd)")"
info "Bootstrapping: $PROJECT_NAME in $TARGET"

# Write file only if it does not already exist; reads content from stdin.
write_new() {
  local path="$1"
  if [[ -f "$path" ]]; then skip "$path"; cat > /dev/null; return; fi
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  ok "Created $path"
}

# ── Directory skeleton ──────────────────────────────────────────────────────────
for d in \
  memory-bank/implementation-plans memory-bank/architecture-decisions \
  docs scripts data assets \
  .github/workflows .github/ISSUE_TEMPLATE \
  .copilot .vscode; do
  mkdir -p "$d"
done
# Ensure empty dirs are tracked by git
for d in scripts data assets; do touch "$d/.gitkeep"; done
ok "Directory skeleton ready"

# ── .gitignore ──────────────────────────────────────────────────────────────────
write_new .gitignore << 'EOF'
.DS_Store
Thumbs.db
*.swp
*.swo
__pycache__/
*.py[cod]
*.egg-info/
dist/
build/
venv/
.env
.env.*
node_modules/
*.class
*.jar
target/
*.o
*.a
*.so
*.log
tmp/
.tmp/
EOF

# ── .editorconfig ───────────────────────────────────────────────────────────────
write_new .editorconfig << 'EOF'
root = true
[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2
[*.{py,java}]
indent_size = 4
[*.md]
trim_trailing_whitespace = false
EOF

# ── .vscode/settings.json ───────────────────────────────────────────────────────
write_new .vscode/settings.json << 'EOF'
{
  // ── Copilot & Chat (documented settings only — OWASP compliant) ──────────────
  "github.copilot.chat.enabled": true,
  "github.copilot.chat.alternateGptPrompt.enabled": true,
  "chat.agent.maxRequests": 100,
  "chat.autopilot.enabled": true,
  "chat.todoListTool.enabled": true,
  "chat.useAgentsMdFile": true,
  "chat.useAgentSkills": true,

  // Terminal auto-approve for safe read-only commands only
  "chat.tools.terminal.enableAutoApprove": true,
  "chat.tools.terminal.autoApprove": {
    "ls": true, "pwd": true, "cat": true, "grep": true, "rg": true,
    "find": true, "head": true, "tail": true, "sed": true, "awk": true,
    "wc": true, "sort": true, "uniq": true, "echo": true,
    "git status": true, "git diff": true, "git log": true, "git branch": true,
    "python --version": true, "node --version": true,
    "npm list": true, "pip list": true,
    "rm": false, "rmdir": false, "del": false, "kill": false, "eval": false
  },
  // SECURITY: chat.tools.global.autoApprove deliberately false (OWASP A01)
  // Enabling it removes ALL agent security protections.
  "chat.tools.global.autoApprove": false,
  "security.workspace.trust.enabled": false,

  // ── General ───────────────────────────────────────────────────────────────────
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "files.eol": "\n",
  "editor.tabSize": 2,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": "explicit",
    "source.fixAll.eslint": "explicit",
    "source.organizeImports": "explicit"
  },

  // ── TypeScript / JavaScript ───────────────────────────────────────────────────
  "typescript.tsdk": "node_modules/typescript/lib",
  "typescript.preferences.importModuleSpecifier": "non-relative",
  "javascript.preferences.importModuleSpecifier": "non-relative",

  // ── Python — snake_case functions, PascalCase classes, UPPER_SNAKE constants ──
  "python.analysis.typeCheckingMode": "basic",
  "python.analysis.autoImportCompletions": true,
  "python.formatting.provider": "black",
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true,
  "python.linting.flake8Enabled": false,
  "python.testing.pytestEnabled": true,
  "python.testing.unittestEnabled": false,
  "python.languageServer": "Pylance",

  // ── C/C++ — Google style, PascalCase classes, snake_case functions ───────────
  "C_Cpp.default.cppStandard": "c++20",
  "C_Cpp.default.cStandard": "c17",
  "C_Cpp.clang_format_style": "{ BasedOnStyle: Google, IndentWidth: 2, ColumnLimit: 100 }",

  // ── Java — camelCase methods, PascalCase classes, UPPER_SNAKE constants ───────
  "java.configuration.updateBuildConfiguration": "interactive",
  "java.compile.nullAnalysis.mode": "automatic",
  "java.format.settings.profile": "GoogleStyle",
  "java.configuration.runtimes": [
    { "name": "JavaSE-21", "path": "/usr/lib/jvm/java-21-openjdk" }
  ],

  // ── Terminal ──────────────────────────────────────────────────────────────────
  "terminal.integrated.shellIntegration.enabled": true,
  "terminal.integrated.shellIntegration.decorationsEnabled": "both",
  "terminal.integrated.shellIntegration.history": 500,
  "terminal.integrated.stickyScroll.enabled": true,
  "terminal.integrated.suggest.enabled": true,
  "terminal.integrated.suggest.quickSuggestions": true,
  "terminal.integrated.suggest.inlineSuggestion": "auto",
  "terminal.integrated.confirmOnExit": "never",
  "terminal.integrated.confirmOnKill": "never",

  // ── Git & Extensions ──────────────────────────────────────────────────────────
  "git.confirmSync": false,
  "git.autofetch": true,
  "extensions.autoUpdate": true,
  "extensions.autoCheckUpdates": true
}
EOF

# ── .vscode/extensions.json ────────────────────────────────────────────────────
write_new .vscode/extensions.json << 'EOF'
{
  "recommendations": [
    "github.copilot",
    "github.copilot-chat",
    "ms-python.python",
    "ms-python.pylance",
    "ms-vscode.cpptools",
    "redhat.java",
    "vscjava.vscode-java-pack",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "editorconfig.editorconfig",
    "ms-azuretools.vscode-docker"
  ]
}
EOF

# ── .copilot/copilot-config.md ─────────────────────────────────────────────────
write_new .copilot/copilot-config.md << 'EOF'
# Copilot Configuration

## Behavior
- Plan before coding. No code without an approved plan.
- TDD: write tests first, then implementation.
- Max file length: 500 lines. Max function length: 50 lines.
- Follow OWASP Top 10 security practices at all times.

## Agent Settings
- Max 100 tool calls per session (chat.agent.maxRequests: 100).
- Auto-approve only safe read-only terminal commands.
- Never auto-approve: rm, kill, eval, curl with pipes, chmod, chown.
- chat.tools.global.autoApprove remains false per OWASP A01.

## Code Standards
- Python:  snake_case functions/vars, PascalCase classes, UPPER_SNAKE_CASE constants.
- Java:    camelCase methods, PascalCase classes, UPPER_SNAKE_CASE constants.
- C++:     Google style — snake_case/camelCase functions, PascalCase classes.
- Bash:    snake_case functions and variables, UPPER_CASE env vars.
EOF

# ── .github files ──────────────────────────────────────────────────────────────
write_new .github/CONTRIBUTING.md << 'EOF'
# Contributing

1. Fork and create a feature branch from `main`.
2. Write tests before implementation (TDD).
3. Keep files under 500 lines and functions under 50 lines.
4. Run lint/shellcheck before submitting a pull request.
5. Use clear, descriptive commit messages.
6. No hardcoded secrets or credentials — follow OWASP A02.
EOF

write_new .github/SECURITY.md << 'EOF'
# Security Policy

## Reporting a Vulnerability
Open a private GitHub security advisory.
Do not file a public issue for security vulnerabilities.

## Practices
- Follow OWASP Top 10 guidelines.
- No hardcoded secrets or credentials in source code.
- Review dependencies for known CVEs before inclusion.
- Validate all user input at system boundaries.
EOF

write_new .github/CODEOWNERS << 'EOF'
* @hkevin01
EOF

write_new .github/pull_request_template.md << 'EOF'
## Summary

## Type
- [ ] Bug fix
- [ ] New feature
- [ ] Refactor
- [ ] Documentation

## Checklist
- [ ] Tests written and passing
- [ ] Files under 500 lines
- [ ] No hardcoded secrets
- [ ] OWASP practices followed
EOF

write_new .github/ISSUE_TEMPLATE/bug_report.md << 'EOF'
---
name: Bug Report
about: Report a bug or unexpected behavior
---
**Describe the bug:**

**Steps to reproduce:**

**Expected behavior:**

**Environment:**
- OS:
- Shell version:
EOF

write_new .github/ISSUE_TEMPLATE/feature_request.md << 'EOF'
---
name: Feature Request
about: Suggest a new feature or improvement
---
**Problem this solves:**

**Proposed solution:**

**Alternatives considered:**
EOF

write_new .github/workflows/ci.yml << 'EOF'
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: ShellCheck
        uses: ludeeus/action-shellcheck@master
        with:
          scandir: .
          severity: warning
EOF

write_new .github/workflows/lint.yml << 'EOF'
name: Lint
on: [push, pull_request]
jobs:
  line-limit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Enforce 500-line cap on shell scripts
        run: |
          fail=0
          while IFS= read -r -d '' f; do
            lines=$(wc -l < "$f")
            if (( lines > 500 )); then
              echo "OVER LIMIT: $f ($lines lines)"
              fail=1
            fi
          done < <(find . -name "*.sh" -not -path "./.git/*" -print0)
          exit $fail
EOF

# ── memory-bank ────────────────────────────────────────────────────────────────
write_new memory-bank/app-description.md << APPDESC
# $PROJECT_NAME

## Overview
Automated Arch Linux installer and post-install developer environment bootstrap.

## Core Features
- LUKS2 encrypted Arch Linux install: linux-zen kernel, KDE Plasma 6, systemd-boot.
- Curlable post-login setup: VS Code (official), Brave, Beastmode, Konsole, privacy.
- VS Code Copilot configuration and Beastmode agent installer.
- KDE dark-theme automation and privacy-hardening scripts.

## Technical Stack
- Language: Bash
- Target: Arch Linux UEFI, KDE Plasma 6, SDDM
- Editor: VS Code (visual-studio-code-bin via AUR)

## Goals
- One-command reproducible Arch setup.
- Privacy-first browser and system defaults.
- Developer-ready environment with Copilot Beastmode pre-wired.
APPDESC

write_new memory-bank/change-log.md << 'EOF'
# Change Log

| Date | Component | Change |
|------|-----------|--------|
| 2026-03-17 | arch-install.sh | Initial LUKS2 + linux-zen + KDE installer |
| 2026-03-17 | arch-user-setup.sh | Post-login environment bootstrap |
| 2026-03-17 | enable-copilot-autopilot.sh | Copilot settings (auto-installs jq) |
| 2026-03-17 | enable-beastmode.sh | Beastmode agent + chatmode installer |
| 2026-03-17 | project-bootstrap.sh | Project scaffold generator |
EOF

write_new memory-bank/implementation-plans/install-flow.md << 'EOF'
# Install Flow Plan

## Phase 1 – Disk & Encryption
- [ ] UEFI check and stale-state cleanup (unmount, swapoff, cryptsetup close)
- [ ] Partition disk: 512MB EFI + LUKS2 root
- [ ] Format EFI (FAT32) and root (ext4)
- [ ] Mount partitions to /mnt

## Phase 2 – Base System
- [ ] pacstrap linux-zen, base, base-devel, essential packages
- [ ] Generate fstab, configure locale, hostname, timezone

## Phase 3 – Boot & Desktop
- [ ] systemd-boot entries with encrypt + resume hooks
- [ ] KDE Plasma 6, SDDM, PipeWire, NetworkManager

## Phase 4 – Post-Login
- [ ] arch-user-setup.sh: Brave, VS Code, Beastmode, privacy scripts
EOF

write_new memory-bank/architecture-decisions/systemd-boot.md << 'EOF'
# ADR-001: systemd-boot over GRUB

**Status:** Accepted | **Date:** 2026-03-17

## Decision
Use systemd-boot — UEFI-only, no external packages, simpler entry management.

## Trade-offs
- No BIOS/legacy boot support.
- Boot entries live in /boot/loader/entries/.
- Easy to extend with additional kernels.
EOF

# ── docs/project-plan.md ───────────────────────────────────────────────────────
write_new docs/project-plan.md << PROJPLAN
# Project Plan: $PROJECT_NAME

## Phase 1: Arch Linux Base Installation
- [ ] Validate UEFI environment and auto-detect target disk (/dev/mmcblk0)
- [ ] Stale-state cleanup — unmount /mnt, close cryptroot, disable swap
- [ ] Full-disk LUKS2 encryption with systemd-boot EFI bootloader
- [ ] Bootstrap base system: linux-zen, base, base-devel, essential packages
- [ ] Configure locale (en_US.UTF-8), hostname, and America/New_York timezone

## Phase 2: Desktop Environment
- [ ] Install KDE Plasma 6, SDDM, PipeWire, NetworkManager
- [ ] Apply GTK/QT dark-theme fix via kde-dark-theme-fix.sh
- [ ] Configure Konsole transparency and custom color profile
- [ ] Set up user account with sudo and first-login setup launcher
- [ ] Enable SDDM and NetworkManager systemd services

## Phase 3: Developer Environment
- [ ] Install official VS Code (visual-studio-code-bin via AUR; remove code-oss)
- [ ] Apply Copilot autopilot settings (enable-copilot-autopilot.sh)
- [ ] Install Beastmode agent and chatmode (enable-beastmode.sh)
- [ ] Install base-devel, git, curl, and yay for AUR builds
- [ ] Install Brave browser via pacman; AUR fallback if not in repos

## Phase 4: Privacy and Security Hardening
- [ ] Run deploy_tracking_protection.sh from utility-scripts
- [ ] Run harden_kde_lockscreen_privacy.sh
- [ ] Verify no hardcoded credentials in any script (OWASP A02)
- [ ] Confirm .gitignore covers .env and secrets patterns
- [ ] ShellCheck all scripts clean — zero warnings in CI

## Phase 5: Automation and Maintenance
- [ ] ShellCheck CI passing on every push via GitHub Actions
- [ ] 500-line cap lint check enforced in CI (lint.yml)
- [ ] Tag stable releases and add entries to memory-bank/change-log.md
- [ ] Validate all curl one-liners in a clean Arch ISO VM
- [ ] Expand memory-bank with each new feature or architecture decision
PROJPLAN

# ── README.md (only if absent) ─────────────────────────────────────────────────
write_new README.md << README_CONTENT
# $PROJECT_NAME

Automated Arch Linux installer and post-install developer environment bootstrap.

## Curlable Scripts

| Script | Purpose |
|--------|---------|
| \`arch-install.sh\` | Full Arch install: LUKS2, linux-zen, KDE Plasma 6 |
| \`arch-user-setup.sh\` | First-login: VS Code, Brave, Beastmode, privacy tools |
| \`enable-beastmode.sh\` | VS Code Beastmode agent + chatmode installer |
| \`enable-copilot-autopilot.sh\` | Copilot agent settings (auto-installs jq) |
| \`kde-dark-theme-fix.sh\` | GTK/QT dark-theme fix for KDE |
| \`project-bootstrap.sh\` | Scaffold any project with memory-bank, CI, .vscode |

## Quick Start

Boot from Arch ISO with internet connected:
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/hkevin01/arch-custom/main/arch-install.sh | bash
\`\`\`

First login after install:
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/hkevin01/arch-custom/main/arch-user-setup.sh | bash
\`\`\`

Scaffold any project (run inside project directory):
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/hkevin01/arch-custom/main/project-bootstrap.sh | bash
\`\`\`

## Requirements
- UEFI system, internet connection, Arch Linux ISO

## License
MIT
README_CONTENT

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
ok "Bootstrap complete → $TARGET"
echo ""
echo "Created:"
find . -not -path './.git/*' -not -name '.git' -not -name '.gitkeep' | sort | head -80
