#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${1:-rancho-trilha-do-sol-static}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

if ! npx wrangler whoami --json >/dev/null 2>&1; then
  echo "Wrangler não autenticado. Execute: npx wrangler login" >&2
  exit 2
fi

npx wrangler pages deploy public --project-name "$PROJECT_NAME"
