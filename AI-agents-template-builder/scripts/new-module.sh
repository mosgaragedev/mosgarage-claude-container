#!/usr/bin/env bash
# =============================================================================
# new-module.sh — Add a new module to an existing project
#
# Usage:
#   ./scripts/new-module.sh
#   ./scripts/new-module.sh "Notes"        # non-interactive
#
# What it does:
#   1. Creates docs/specs/<module>.spec.md with full template
#   2. Adds the module row to CLAUDE.md module table
#   3. Tells you the next steps for implementation
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
print_ok() { echo -e "${GREEN}✓${NC} $1"; }
print_header() { echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}\n"; }

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

# Get module name
if [ $# -ge 1 ]; then
  MODULE_NAME="$1"
else
  echo -e "${BOLD}Module name:${NC}"
  read -r MODULE_NAME
fi

# Convert to safe kebab-case filename
FILENAME=$(slugify "$MODULE_NAME")
SPECFILE="docs/specs/${FILENAME}.spec.md"

if [ -f "$SPECFILE" ]; then
  echo "Spec already exists: $SPECFILE"
  exit 1
fi

print_header "Creating module: ${MODULE_NAME}"
mkdir -p docs/specs

# Ask for phase
echo -e "${BOLD}Phase:${NC}"
echo "  1) Phase 1 — MVP"
echo "  2) Phase 2 — Power features"
echo "  3) Phase 3 — Advanced"
read -r PHASE_CHOICE
case $PHASE_CHOICE in
  1) PHASE="1 (MVP)" ;;
  2) PHASE="2 (Power features)" ;;
  3) PHASE="3 (Advanced)" ;;
  *) PHASE="1 (MVP)" ;;
esac

# Generate full spec file
cat > "$SPECFILE" << SPECEOF
# ${MODULE_NAME} — Feature Specification

**Module:** ${MODULE_NAME}
**Phase:** ${PHASE}
**Status:** 🔲 Not started
**Spec version:** 1.0
**Date:** $(date +%Y-%m-%d)

---

## Overview

<!-- Describe what this module does in 2-3 sentences -->

---

## Data Model

\`\`\`
<!-- Paste the database schema for this module -->
<!-- Include: fields, types, indexes, relations -->
\`\`\`

---

## API Endpoints

| Method | Route | Auth | Description |
|---|---|---|---|
| GET | \`/api/v1/${FILENAME}\` | Yes | List ${MODULE_NAME,,}s |
| POST | \`/api/v1/${FILENAME}\` | Yes | Create ${MODULE_NAME,,} |
| GET | \`/api/v1/${FILENAME}/:id\` | Yes | Get single ${MODULE_NAME,,} |
| PUT | \`/api/v1/${FILENAME}/:id\` | Yes | Update ${MODULE_NAME,,} |
| DELETE | \`/api/v1/${FILENAME}/:id\` | Yes | Soft delete ${MODULE_NAME,,} |

---

## Request / Response Schemas

### Create — Request body
\`\`\`typescript
{
  // TODO: Define fields
}
\`\`\`

### Response shape
\`\`\`typescript
{
  id: string
  // TODO: Define response fields
  // NEVER include: userId, deletedAt, password, internal fields
  createdAt: string
  updatedAt: string
}
\`\`\`

---

## Business Rules

1. <!-- Rule: what happens on delete? -->
2. <!-- Rule: what fields are immutable after creation? -->
3. <!-- Rule: what are the ownership rules? -->
4. <!-- Rule: any cascade behaviors? -->

---

## Frontend Pages & Components

### Pages
\`\`\`
<!-- List the Next.js pages for this module -->
app/(dashboard)/${FILENAME}/page.tsx          # main list view
app/(dashboard)/${FILENAME}/[id]/page.tsx     # detail / edit view
\`\`\`

### Key Components
\`\`\`
<!-- List the React components needed -->
${MODULE_NAME}List        # scrollable list
${MODULE_NAME}Card        # preview card
${MODULE_NAME}Detail      # detail panel or page
${MODULE_NAME}Form        # create / edit form
\`\`\`

---

## Security Checklist

- [ ] All routes behind auth middleware
- [ ] All Prisma queries include \`userId: request.user.id\`
- [ ] IDOR test: user B cannot access user A's ${MODULE_NAME,,}s
- [ ] Mass assignment: userId cannot be set via request body
- [ ] Input validation: Zod schema for all inputs

---

## Acceptance Criteria

- [ ] User can create a ${MODULE_NAME,,} and see it immediately
- [ ] User can list, edit, and delete their ${MODULE_NAME,,}s
- [ ] User cannot access another user's ${MODULE_NAME,,}s (404, not 403)
- [ ] Soft deleted items not returned in main list
- [ ] All API routes return correct HTTP status codes
- [ ] TypeScript strict — 0 errors
- [ ] Integration tests for all routes
- [ ] Validation loop tests for all Zod schemas
SPECEOF

print_ok "Created $SPECFILE"

# Add to CLAUDE.md module table if it exists
if [ -f "CLAUDE.md" ]; then
  # Find the module table and append a new row
  # Look for the last row with 🔲 or ✅ or 🚧 pattern
  if grep -q "Not started\|In progress\|Done" CLAUDE.md; then
    # Add new row before the closing of the table
    NEW_ROW="| ${MODULE_NAME} | 🔲 Not started | \`docs/specs/${FILENAME}.spec.md\` |"
    "$PYTHON_BIN" - CLAUDE.md "$NEW_ROW" << 'PYEOF'
import sys

path = sys.argv[1]
new_row = sys.argv[2]

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

last_spec_row = None
for index, line in enumerate(lines):
    if "docs/specs/" in line:
        last_spec_row = index

if last_spec_row is None:
    lines.append(new_row + "\n")
else:
    lines.insert(last_spec_row + 1, new_row + "\n")

with open(path, "w", encoding="utf-8") as f:
    f.writelines(lines)
PYEOF
    print_ok "Added ${MODULE_NAME} to CLAUDE.md module table"
  fi
fi

echo ""
echo -e "${BOLD}Next steps for ${MODULE_NAME}:${NC}"
echo ""
echo "  1. Fill in the spec: ${SPECFILE}"
echo "  2. Particularly: Data Model, Business Rules, Acceptance Criteria"
echo "  3. Then tell Claude Code:"
echo ""
echo -e "     ${CYAN}\"Read docs/specs/${FILENAME}.spec.md and implement the ${MODULE_NAME} module end-to-end\"${NC}"
echo ""
