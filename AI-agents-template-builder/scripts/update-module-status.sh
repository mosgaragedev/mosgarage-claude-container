#!/usr/bin/env bash
# =============================================================================
# update-module-status.sh — Update a module's status in CLAUDE.md
#
# Usage:
#   ./scripts/update-module-status.sh "Notes" done
#   ./scripts/update-module-status.sh "Tasks" in-progress
#   ./scripts/update-module-status.sh "Ideas" not-started
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

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

if [ $# -lt 2 ]; then
  echo -e "${BOLD}Usage:${NC} $0 <ModuleName> <status>"
  echo "  Status options: done | in-progress | not-started"
  exit 1
fi

MODULE_NAME="$1"
STATUS_INPUT="$2"

case "$STATUS_INPUT" in
  done|complete|completed)   STATUS_EMOJI="✅ Done" ;;
  in-progress|wip|started)   STATUS_EMOJI="🚧 In progress" ;;
  not-started|todo|pending)  STATUS_EMOJI="🔲 Not started" ;;
  *) echo "Unknown status: $STATUS_INPUT"; exit 1 ;;
esac

if [ ! -f "CLAUDE.md" ]; then
  echo -e "${RED}CLAUDE.md not found. Run from project root.${NC}"
  exit 1
fi

# Update the status in CLAUDE.md
"$PYTHON_BIN" - CLAUDE.md "$MODULE_NAME" "$STATUS_EMOJI" << 'PYEOF'
import sys

path = sys.argv[1]
module_name = sys.argv[2]
status = sys.argv[3]

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

target_prefix = f"| {module_name} |"
updated = False

for index, line in enumerate(lines):
    if line.startswith(target_prefix):
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) >= 3:
            cells[1] = status
            lines[index] = "| " + " | ".join(cells) + " |\n"
            updated = True
        break

if not updated:
    raise SystemExit(f"Module not found in CLAUDE.md: {module_name}")

with open(path, "w", encoding="utf-8") as f:
    f.writelines(lines)
PYEOF

echo -e "${GREEN}✓${NC} Updated ${BOLD}${MODULE_NAME}${NC} → ${STATUS_EMOJI}"
