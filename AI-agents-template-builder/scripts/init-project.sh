#!/usr/bin/env bash
# =============================================================================
# init-project.sh — Agent Template Initializer
# Transforms the template into a project-specific agent workspace.
#
# Usage:
#   chmod +x scripts/init-project.sh
#   ./scripts/init-project.sh
#
# Requirements: bash, python3 (pre-installed on macOS, Linux, WSL)
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() { echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}\n"; }
print_ok()     { echo -e "${GREEN}✓${NC} $1"; }
print_warn()   { echo -e "${YELLOW}!${NC} $1"; }
ask()          { echo -e "${BOLD}$1${NC}"; read -r "$2"; }
ask_default()  {
  local _varname="$2"
  local _default="$3"
  echo -e "${BOLD}$1${NC} [default: ${YELLOW}${_default}${NC}]"
  local _input=""
  read -r _input || true
  if [ -z "$_input" ]; then
    printf -v "$_varname" '%s' "$_default"
  else
    printf -v "$_varname" '%s' "$_input"
  fi
}

find_python() {
  if command -v python3 >/dev/null 2>&1; then
    echo "python3"
  elif command -v python >/dev/null 2>&1; then
    echo "python"
  else
    echo "python3"
  fi
}

PYTHON_BIN="$(find_python)"

slugify() {
  "$PYTHON_BIN" - "$1" << 'PYEOF'
import re
import sys

value = sys.argv[1].strip().lower()
value = re.sub(r"[^a-z0-9]+", "-", value)
value = value.strip("-")
print(value or "module")
PYEOF
}

# =============================================================================
# replace_in_file — uses python3 to safely handle any characters in values
# including: / | newlines \n special chars URLs paths
# =============================================================================
replace_in_file() {
  local file="$1"
  local placeholder="$2"
  local value="$3"

  "$PYTHON_BIN" - "$file" "$placeholder" "$value" << 'PYEOF'
import sys

filepath   = sys.argv[1]
placeholder = "{{" + sys.argv[2] + "}}"
value       = sys.argv[3]

with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace(placeholder, value)

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)
PYEOF
}

# =============================================================================
print_header "Agent Template — Project Initializer"
echo "This script customizes all agent instruction files for your project."
echo "Takes about 2 minutes. Press Ctrl+C to cancel."
# =============================================================================

# --- 1. Project identity ---
print_header "1 / 6 — Project Identity"

ask "Project name (e.g. LifeOps, OpenClaw):" PROJECT_NAME
ask "One-line description:" PROJECT_DESCRIPTION
ask "Project type (e.g. 'SaaS web app', 'CLI tool', 'API service', 'Static site'):" PROJECT_TYPE
ask "GitHub repo URL (e.g. https://github.com/you/project):" REPO_URL
ask_default "Is this open source? (yes/no):" IS_OPEN_SOURCE "yes"

# --- 2. Tech stack ---
print_header "2 / 6 — Tech Stack"

echo -e "${BOLD}Select primary language:${NC}"
echo "  1) TypeScript"
echo "  2) JavaScript"
echo "  3) Python"
echo "  4) Go"
echo "  5) Other"
read -r LANG_CHOICE
case $LANG_CHOICE in
  1) LANGUAGE="TypeScript" ; TYPECHECK_CMD="tsc --noEmit" ;;
  2) LANGUAGE="JavaScript" ; TYPECHECK_CMD="echo 'No typecheck'" ;;
  3) LANGUAGE="Python"     ; TYPECHECK_CMD="mypy ." ;;
  4) LANGUAGE="Go"         ; TYPECHECK_CMD="go vet ./..." ;;
  *) ask "Language name:" LANGUAGE ; ask "Type check command:" TYPECHECK_CMD ;;
esac

echo -e "\n${BOLD}Select package manager:${NC}"
echo "  1) pnpm  (recommended for Node)"
echo "  2) npm"
echo "  3) yarn"
echo "  4) pip / uv  (Python)"
echo "  5) go mod  (Go)"
echo "  6) Other"
read -r PKG_CHOICE
case $PKG_CHOICE in
  1) PKG_MANAGER="pnpm"   ; PKG_MANAGER_WRONG="npm or yarn"   ; CMD_INSTALL="pnpm install" ;;
  2) PKG_MANAGER="npm"    ; PKG_MANAGER_WRONG="yarn or pnpm"  ; CMD_INSTALL="npm install" ;;
  3) PKG_MANAGER="yarn"   ; PKG_MANAGER_WRONG="npm or pnpm"   ; CMD_INSTALL="yarn install" ;;
  4) PKG_MANAGER="pip"    ; PKG_MANAGER_WRONG="conda"          ; CMD_INSTALL="pip install -r requirements.txt" ;;
  5) PKG_MANAGER="go mod" ; PKG_MANAGER_WRONG="manual"         ; CMD_INSTALL="go mod download" ;;
  *) ask "Package manager:" PKG_MANAGER
     ask "Wrong alternatives (comma separated):" PKG_MANAGER_WRONG
     ask "Install command:" CMD_INSTALL ;;
esac

ask "Framework / main library (e.g. Next.js 14, Fastify, Django, Echo):" FRAMEWORK
ask "Database (e.g. PostgreSQL 16, SQLite, MongoDB, none):" DATABASE

ask_default "Dev command:" CMD_DEV "pnpm dev"
ask_default "Lint command:" CMD_LINT "pnpm lint"
ask_default "Test command:" CMD_TEST "pnpm test"
ask_default "Build command:" CMD_BUILD "pnpm build"

TECH_STACK="${LANGUAGE} — ${FRAMEWORK} — ${DATABASE}"

# --- 3. Repo structure ---
print_header "3 / 6 — Repo Structure"

echo -e "${BOLD}Select repo structure:${NC}"
echo "  1) Monorepo (Turborepo / nx)"
echo "  2) Fullstack single repo (frontend + backend together)"
echo "  3) Single app (pure frontend or pure backend)"
echo "  4) Describe manually"
read -r STRUCTURE_CHOICE

# Initialize to avoid unbound variable error
REPO_STRUCTURE=""

case $STRUCTURE_CHOICE in
  1) REPO_STRUCTURE="apps/web/        # Frontend app
apps/api/        # Backend API
packages/ui/     # Shared component library
packages/types/  # Shared TypeScript types
packages/db/     # Database schema + client
packages/config/ # Shared ESLint, TSConfig
docs/            # PRD, specs, ADRs" ;;
  2) REPO_STRUCTURE="src/
  app/           # Frontend pages and components
  api/           # Backend routes
  lib/           # Shared utilities
  db/            # Database schema and migrations
docs/            # PRD, specs, ADRs" ;;
  3) REPO_STRUCTURE="src/             # Application source
  routes/        # Route handlers
  lib/           # Utilities
  types/         # Type definitions
docs/            # PRD, specs, ADRs
tests/           # Test files" ;;
  4) echo "Paste your repo structure (press Enter twice when done):"
     REPO_STRUCTURE=""
     while IFS= read -r line; do
       [[ -z "$line" ]] && break
       REPO_STRUCTURE="${REPO_STRUCTURE}${line}
"
     done ;;
esac

# --- 4. Modules ---
print_header "4 / 6 — Modules"

echo -e "${BOLD}List your modules, one per line.${NC}"
echo "Press Enter on a blank line when done."
echo "Example:"
echo "  Auth"
echo "  Notes"
echo "  Tasks"
echo ""

MODULES=()
while IFS= read -r line; do
  [[ -z "$line" ]] && break
  MODULES+=("$line")
done

if [ ${#MODULES[@]} -eq 0 ]; then
  MODULES=("Core")
fi

# --- 5. Security profile ---
print_header "5 / 6 — Security Profile"

echo -e "${BOLD}What kind of project is this?${NC}"
echo "  1) User-facing web app (auth, user data)"
echo "  2) Internal tool / admin panel"
echo "  3) Public API / service"
echo "  4) Static site / no backend"
echo "  5) CLI tool"
read -r SECURITY_PROFILE

case $SECURITY_PROFILE in
  1) SECURITY_LEVEL="full" ;;
  2) SECURITY_LEVEL="medium" ;;
  3) SECURITY_LEVEL="api" ;;
  4) SECURITY_LEVEL="minimal" ;;
  5) SECURITY_LEVEL="minimal" ;;
  *) SECURITY_LEVEL="medium" ;;
esac

# --- 6. Confirm ---
print_header "6 / 6 — Confirm"

echo -e "${BOLD}About to generate agent files for:${NC}"
echo ""
echo "  Project:     $PROJECT_NAME"
echo "  Description: $PROJECT_DESCRIPTION"
echo "  Type:        $PROJECT_TYPE"
echo "  Stack:       $TECH_STACK"
echo "  Repo:        $REPO_URL"
echo "  Open source: $IS_OPEN_SOURCE"
echo "  Modules:     ${MODULES[*]}"
echo "  Security:    $SECURITY_LEVEL"
echo ""
ask "Looks good? (yes/no):" CONFIRM

if [[ "$CONFIRM" != "yes" && "$CONFIRM" != "y" ]]; then
  echo "Cancelled. Run the script again to restart."
  exit 0
fi

# =============================================================================
print_header "Generating files..."
# =============================================================================

# Ensure required directories exist
mkdir -p docs/specs docs/adr docs/testing

# ---- Fill placeholders in CLAUDE.md and AGENTS.md ----
for file in CLAUDE.md AGENTS.md; do
  if [ ! -f "$file" ]; then
    print_warn "$file not found — skipping"
    continue
  fi
  replace_in_file "$file" "PROJECT_NAME"        "$PROJECT_NAME"
  replace_in_file "$file" "PROJECT_TYPE"        "$PROJECT_TYPE"
  replace_in_file "$file" "PROJECT_DESCRIPTION" "$PROJECT_DESCRIPTION"
  replace_in_file "$file" "TECH_STACK"          "$TECH_STACK"
  replace_in_file "$file" "REPO_URL"            "$REPO_URL"
  replace_in_file "$file" "IS_OPEN_SOURCE"      "$IS_OPEN_SOURCE"
  replace_in_file "$file" "LANGUAGE"            "$LANGUAGE"
  replace_in_file "$file" "FRAMEWORK"           "$FRAMEWORK"
  replace_in_file "$file" "DATABASE"            "$DATABASE"
  replace_in_file "$file" "PKG_MANAGER"         "$PKG_MANAGER"
  replace_in_file "$file" "PKG_MANAGER_WRONG"   "$PKG_MANAGER_WRONG"
  replace_in_file "$file" "CMD_INSTALL"         "$CMD_INSTALL"
  replace_in_file "$file" "CMD_DEV"             "$CMD_DEV"
  replace_in_file "$file" "CMD_TYPECHECK"       "$TYPECHECK_CMD"
  replace_in_file "$file" "CMD_LINT"            "$CMD_LINT"
  replace_in_file "$file" "CMD_TEST"            "$CMD_TEST"
  replace_in_file "$file" "CMD_BUILD"           "$CMD_BUILD"
  replace_in_file "$file" "REPO_STRUCTURE"      "$REPO_STRUCTURE"
  print_ok "Filled $file"
done

# ---- Update module table in CLAUDE.md ----
# Build the new rows as a string then use python to splice them in
MODULE_ROWS=""
for mod in "${MODULES[@]}"; do
  filename=$(slugify "$mod")
  MODULE_ROWS="${MODULE_ROWS}| ${mod} | 🔲 Not started | \`docs/specs/${filename}.spec.md\` |\n"
done

# Replace the placeholder example row using python
"$PYTHON_BIN" - CLAUDE.md "$MODULE_ROWS" << 'PYEOF'
import sys, re

filepath = sys.argv[1]
new_rows  = sys.argv[2].replace("\\n", "\n")

with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

# Replace any line containing "Example" inside the module table
content = re.sub(r'\| Example \|.*\|\n?', new_rows, content)

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)
PYEOF
print_ok "Updated module table in CLAUDE.md"

# ---- Generate docs/PRD.md ----
PRD_MODULES_SECTION=""
for mod in "${MODULES[@]}"; do
  PRD_MODULES_SECTION="${PRD_MODULES_SECTION}### ${mod}

<!-- TODO: Describe this module -->

"
done

cat > docs/PRD.md << HEREDOC
# PRD.md — ${PROJECT_NAME} Product Requirements

**Version:** 1.0
**Status:** Draft
**Date:** $(date +%Y-%m-%d)

---

## 1. Vision

${PROJECT_DESCRIPTION}

---

## 2. Problem Statement

<!-- TODO: Describe the problem this project solves -->

---

## 3. Modules / Features

${PRD_MODULES_SECTION}
---

## 4. Non-Functional Requirements

- Performance: API p95 < 200ms
- Security: all user inputs validated, auth required on protected routes
- Deployment: single command startup

---

## 5. Out of Scope (v1.0)

<!-- TODO: List what is explicitly NOT being built -->

---

## 6. Success Metrics

<!-- TODO: How will you know when v1.0 is done? -->
HEREDOC
print_ok "Generated docs/PRD.md"

# ---- Generate docs/ARCHITECTURE.md ----
cat > docs/ARCHITECTURE.md << HEREDOC
# ARCHITECTURE.md — ${PROJECT_NAME}

**Version:** 1.0
**Date:** $(date +%Y-%m-%d)

---

## Stack

${TECH_STACK}

---

## Repo Structure

\`\`\`
${REPO_STRUCTURE}
\`\`\`

---

## Data Flow

<!-- TODO: Describe request → processing → response flow -->

---

## Key Decisions

| Decision | Why |
|---|---|
| ${FRAMEWORK} | <!-- TODO --> |
| ${DATABASE} | <!-- TODO --> |
| ${PKG_MANAGER} | <!-- TODO --> |

---

## ADR Index

| # | Decision | Status |
|---|---|---|
| ADR-001 | Initial stack choice | Accepted |
HEREDOC
print_ok "Generated docs/ARCHITECTURE.md"

# ---- Generate spec stub for each module ----
for mod in "${MODULES[@]}"; do
  filename=$(slugify "$mod")
  specfile="docs/specs/${filename}.spec.md"

  cat > "$specfile" << HEREDOC
# ${mod} — Feature Specification

**Module:** ${mod}
**Status:** 🔲 Not started
**Spec version:** 1.0
**Date:** $(date +%Y-%m-%d)

---

## Overview

<!-- TODO: 2-3 sentences describing what this module does -->

---

## Data Model

\`\`\`
<!-- TODO: Paste your schema here (Prisma, SQLAlchemy, Go structs, etc.) -->
\`\`\`

---

## API / Interface

| Method | Route / Function | Auth | Description |
|---|---|---|---|
| GET | /api/v1/${filename} | Yes | List items |
| POST | /api/v1/${filename} | Yes | Create item |
| GET | /api/v1/${filename}/:id | Yes | Get single item |
| PUT | /api/v1/${filename}/:id | Yes | Update item |
| DELETE | /api/v1/${filename}/:id | Yes | Soft delete item |

---

## Business Rules

1. <!-- TODO: What happens on delete? -->
2. <!-- TODO: What fields are immutable after creation? -->
3. <!-- TODO: Any cascade behaviors? -->

---

## Acceptance Criteria

- [ ] <!-- TODO: Testable condition 1 -->
- [ ] <!-- TODO: Testable condition 2 -->
- [ ] All API routes return correct HTTP status codes
- [ ] TypeScript strict — 0 errors
- [ ] Integration tests for all routes
- [ ] Validation loop tests for all input schemas
HEREDOC
  print_ok "Generated spec: ${specfile}"
done

# ---- Generate docs/adr/ADR-001 ----
cat > docs/adr/ADR-001-initial-stack.md << HEREDOC
# ADR-001 — Initial Tech Stack

**Status:** Accepted
**Date:** $(date +%Y-%m-%d)

## Context

Starting ${PROJECT_NAME} from scratch. Need to choose the core technology stack.

## Decision

Use: ${TECH_STACK}

## Reasons

<!-- TODO: Why did you choose this stack? -->
1.
2.
3.

## Consequences

<!-- TODO: What are the tradeoffs? -->
HEREDOC
print_ok "Generated docs/adr/ADR-001"

# ---- Generate .env.example ----
DB_LOWER=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')

DB_SECTION="# DATABASE_URL=\"your_database_url\""
if echo "$DATABASE" | grep -qi "postgres"; then
  DB_SECTION="DATABASE_URL=\"postgresql://user:password@localhost:5432/${DB_LOWER}\""
elif echo "$DATABASE" | grep -qi "sqlite"; then
  DB_SECTION="DATABASE_URL=\"file:./dev.db\""
elif echo "$DATABASE" | grep -qi "mongo"; then
  DB_SECTION="MONGODB_URI=\"mongodb://localhost:27017/${DB_LOWER}\""
fi

AUTH_SECTION=""
if [[ "$SECURITY_LEVEL" == "full" || "$SECURITY_LEVEL" == "api" ]]; then
  AUTH_SECTION="
# --- Auth ----------------------------------------------------
# Generate secrets with: openssl rand -base64 64
JWT_ACCESS_SECRET=\"replace-with-random-string\"
JWT_REFRESH_SECRET=\"replace-with-different-random-string\"
JWT_ACCESS_EXPIRY=\"15m\"
JWT_REFRESH_EXPIRY=\"30d\"

# --- Redis ---------------------------------------------------
REDIS_URL=\"redis://localhost:6379\""
fi

cat > .env.example << HEREDOC
# ${PROJECT_NAME} — Environment Variables
# Copy to .env and fill in values. Never commit .env.
# Generated: $(date +%Y-%m-%d)

# --- App -----------------------------------------------------
NODE_ENV="development"
PORT=3000
APP_URL="http://localhost:3000"

# --- Database ------------------------------------------------
${DB_SECTION}
${AUTH_SECTION}

# --- Add project-specific variables below --------------------
HEREDOC
print_ok "Generated .env.example"

# ---- Generate .gitignore if missing ----
if [ ! -f .gitignore ]; then
  cat > .gitignore << 'HEREDOC'
# Environment — NEVER commit these
.env
.env.local
.env.*.local

# Dependencies
node_modules/
__pycache__/
*.pyc
.venv/
venv/

# Build output
dist/
build/
.next/
out/

# OS
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/
*.swp
*.swo

# Logs
*.log
logs/

# Test coverage
coverage/
.nyc_output/

# Docker local
.docker/
HEREDOC
  print_ok "Generated .gitignore"
fi

# ---- Generate CONTRIBUTING.md ----
REPO_BASENAME=$(basename "$REPO_URL" .git 2>/dev/null || echo "project")
LICENSE_LINE="MIT — contributions welcome."
if [[ "$IS_OPEN_SOURCE" != "yes" ]]; then
  LICENSE_LINE="Proprietary."
fi

cat > CONTRIBUTING.md << HEREDOC
# Contributing to ${PROJECT_NAME}

## Local Setup

\`\`\`bash
git clone ${REPO_URL}
cd ${REPO_BASENAME}
cp .env.example .env
# Fill in .env values
${CMD_INSTALL}
${CMD_DEV}
\`\`\`

## Branch Strategy

\`\`\`
main        — production ready, protected
dev         — integration branch, PRs merge here
feat/<n> — new feature
fix/<n>  — bug fix
chore/<n>— maintenance, deps, config
\`\`\`

## Before Opening a PR

\`\`\`bash
${TYPECHECK_CMD}
${CMD_LINT}
${CMD_TEST}
\`\`\`

All three must pass with zero errors.

## Commit Format

[Conventional Commits](https://www.conventionalcommits.org/):

\`\`\`
feat(module): add thing
fix(module): fix thing
chore: update deps
docs: update readme
refactor(module): extract helper
\`\`\`

## License

${LICENSE_LINE}
HEREDOC
print_ok "Generated CONTRIBUTING.md"

# ---- Customize SECURITY.md project name if it exists ----
if [ -f "SECURITY.md" ]; then
  replace_in_file "SECURITY.md" "PROJECT_NAME" "$PROJECT_NAME"
  print_ok "Customized SECURITY.md"
fi

# ---- Customize testing docs project name if they exist ----
for f in docs/testing/TESTING.md docs/testing/VALIDATION.md docs/testing/ADVERSARIAL.md docs/testing/PERFORMANCE.md; do
  if [ -f "$f" ]; then
    replace_in_file "$f" "PROJECT_NAME" "$PROJECT_NAME"
    print_ok "Customized $f"
  fi
done

# =============================================================================
print_header "Done! Your agent workspace is ready."
# =============================================================================

echo -e "${BOLD}Files generated:${NC}"
echo ""
find docs/ -name "*.md" | sort | while read -r f; do echo "  $f"; done
echo "  CLAUDE.md"
echo "  AGENTS.md"
echo "  CONTRIBUTING.md"
echo "  .env.example"
[ -f .gitignore ] && echo "  .gitignore"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo ""
echo -e "  ${YELLOW}1.${NC} Fill in the TODO sections in CLAUDE.md"
echo -e "  ${YELLOW}2.${NC} Complete docs/PRD.md with your requirements"
echo -e "  ${YELLOW}3.${NC} Fill in docs/specs/*.spec.md for each module"
echo -e "  ${YELLOW}4.${NC} Copy .env.example to .env and fill in values"
echo -e "  ${YELLOW}5.${NC} Start Claude Code: ${CYAN}claude${NC}"
echo ""
echo -e "${GREEN}${BOLD}Happy building! 🚀${NC}"
