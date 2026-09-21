#!/usr/bin/env bash
#
# sync-to-exchange.sh
# -------------------
# Demo wrapper for the Anypoint API Catalog CLI.
#
#   ① Pull the latest API specs from the source repository (GitHub)
#   ② Detect new APIs / version changes and refresh the catalog descriptor
#   ③ (optional) Dry-run to preview what would publish
#   ④ Publish new + changed assets to Anypoint Exchange
#
# Usage:
#   ./sync-to-exchange.sh            # full run: pull, detect, preview, publish
#   ./sync-to-exchange.sh --preview  # stop after the dry-run (nothing published)
#
# Auth is read from environment variables (see .env.example):
#   ANYPOINT_ORG            (required)  Business group / org name
#   ANYPOINT_CLIENT_ID      (required)  Connected App client id
#   ANYPOINT_CLIENT_SECRET  (required)  Connected App client secret
#
set -euo pipefail

DESCRIPTOR="catalog.yaml"
PREVIEW_ONLY="false"
[[ "${1:-}" == "--preview" ]] && PREVIEW_ONLY="true"

# --- Load .env if present (keeps secrets off the command line) --------------
if [[ -f .env ]]; then
  set -a; source .env; set +a
fi

# --- Validate required auth up front ----------------------------------------
: "${ANYPOINT_ORG:?Set ANYPOINT_ORG — see .env.example}"
: "${ANYPOINT_CLIENT_ID:?Set ANYPOINT_CLIENT_ID — see .env.example}"
: "${ANYPOINT_CLIENT_SECRET:?Set ANYPOINT_CLIENT_SECRET — see .env.example}"

bold()  { printf "\n\033[1m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }

# --- ① Pull latest specs from the external repo -----------------------------
bold "① Pulling latest API specs from the source repository..."
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  git pull --ff-only
else
  echo "   (no upstream configured yet — using local specs)"
fi

# --- ② Detect new APIs / version changes ------------------------------------
bold "② Detecting new APIs and version changes..."
api-catalog update-descriptor --descriptor-file "$DESCRIPTOR"
echo "   Descriptor changes vs. last commit:"
git --no-pager diff -- "$DESCRIPTOR" || true

# --- ③ Dry-run preview (validates descriptor + auth; publishes nothing) ------
bold "③ Dry run — previewing what would publish (nothing sent yet)..."
api-catalog publish-asset --descriptor-file "$DESCRIPTOR" --dry-run --organization "$ANYPOINT_ORG"

if [[ "$PREVIEW_ONLY" == "true" ]]; then
  green "✔ Preview complete. Re-run without --preview to publish to Exchange."
  exit 0
fi

# --- ④ Publish new + changed assets to Exchange -----------------------------
bold "④ Publishing new and changed assets to Anypoint Exchange..."
api-catalog publish-asset --descriptor-file "$DESCRIPTOR" --organization "$ANYPOINT_ORG"

green "✔ Done — view your assets at https://anypoint.mulesoft.com/exchange"
