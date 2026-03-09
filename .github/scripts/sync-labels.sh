#!/usr/bin/env bash
#
# Sync GitHub labels from .github/labels.yml to the repository.
# Idempotent — safe to re-run. Creates missing labels and updates
# existing ones to match the definitions file.
#
# Usage: .github/scripts/sync-labels.sh [--delete-unknown]
#   --delete-unknown  Remove labels not defined in labels.yml
#
# Requires: gh (GitHub CLI), yq (https://github.com/mikefarah/yq)

set -euo pipefail

LABELS_FILE="$(git rev-parse --show-toplevel)/.github/labels.yml"

if [[ ! -f "$LABELS_FILE" ]]; then
  echo "Error: $LABELS_FILE not found" >&2
  exit 1
fi

command -v gh >/dev/null 2>&1 || { echo "Error: gh CLI not found" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "Error: yq (mikefarah flavor) not found. See https://github.com/mikefarah/yq#install for installation options." >&2; exit 1; }

DELETE_UNKNOWN=false
if [[ "${1:-}" == "--delete-unknown" ]]; then
  DELETE_UNKNOWN=true
fi

# Read defined labels
DEFINED_LABELS=()
COUNT=$(yq 'length' "$LABELS_FILE")

for ((i = 0; i < COUNT; i++)); do
  NAME=$(yq -r ".[$i].name" "$LABELS_FILE")
  COLOR=$(yq -r ".[$i].color" "$LABELS_FILE")
  DESC=$(yq -r ".[$i].description" "$LABELS_FILE")
  DEFINED_LABELS+=("$NAME")

  if gh label list --search "$NAME" --json name --jq '.[].name' | grep -Fqxi "$NAME" 2>/dev/null; then
    echo "Updating: $NAME"
    gh label edit "$NAME" --color "$COLOR" --description "$DESC"
  else
    echo "Creating: $NAME"
    gh label create "$NAME" --color "$COLOR" --description "$DESC"
  fi
done

# Optionally remove labels not in the definitions file
if [[ "$DELETE_UNKNOWN" == true ]]; then
  echo ""
  echo "Checking for unknown labels..."
  while IFS= read -r EXISTING; do
    FOUND=false
    for DEFINED in "${DEFINED_LABELS[@]}"; do
      if [[ "$EXISTING" == "$DEFINED" ]]; then
        FOUND=true
        break
      fi
    done
    if [[ "$FOUND" == false ]]; then
      echo "Deleting: $EXISTING"
      gh label delete "$EXISTING" --yes
    fi
  done < <(gh label list --json name --jq '.[].name')
fi

echo ""
echo "Done. Labels synced."
