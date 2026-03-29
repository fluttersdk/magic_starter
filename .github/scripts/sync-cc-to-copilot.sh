#!/usr/bin/env bash
# sync-cc-to-copilot.sh — Syncs Claude Code rules to GitHub Copilot instructions
# Run after modifying .claude/rules/*.md to keep Copilot instructions in sync.
#
# Usage: bash .github/scripts/sync-cc-to-copilot.sh

set -euo pipefail

RULES_DIR=".claude/rules"
INSTRUCTIONS_DIR=".github/instructions"

mkdir -p "$INSTRUCTIONS_DIR"

declare -A RULE_NAMES=(
  ["flutter"]="Flutter/Dart Standards"
  ["controllers"]="HTTP Controller Patterns"
  ["widgets"]="UI Widget Conventions"
  ["views"]="View Lifecycle Patterns"
  ["layouts"]="Layout Shell Conventions"
  ["routes"]="Route Registration Rules"
  ["tests"]="Testing Conventions"
  ["cli"]="CLI Command Patterns"
)

for rule_file in "$RULES_DIR"/*.md; do
  [ -f "$rule_file" ] || continue

  basename_no_ext=$(basename "$rule_file" .md)
  target_file="${INSTRUCTIONS_DIR}/${basename_no_ext}.instructions.md"

  # Extract frontmatter path: value
  apply_to=$(sed -n '/^---$/,/^---$/{ s/^path: *"\(.*\)"/\1/p; s/^path: *\(.*\)/\1/p }' "$rule_file")

  # Extract body (everything after second ---)
  body=$(awk 'BEGIN{c=0} /^---$/{c++; if(c==2){found=1; next}} found{print}' "$rule_file")

  # Generate human-readable name
  name="${RULE_NAMES[$basename_no_ext]:-$basename_no_ext}"

  # Generate description from first heading
  description=$(echo "$body" | sed -n 's/^# *//p' | head -1)
  [ -z "$description" ] && description="Conventions for ${basename_no_ext}"

  # Write Copilot instruction file
  cat > "$target_file" <<EOF
---
name: '${name}'
description: '${description}'
applyTo: '${apply_to}'
---
${body}
EOF

  echo "  synced: $rule_file → $target_file"
done

echo ""
echo "Done. ${INSTRUCTIONS_DIR}/ is now in sync with ${RULES_DIR}/."
