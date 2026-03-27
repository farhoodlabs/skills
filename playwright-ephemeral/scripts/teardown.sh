#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

# --- Dependencies ---
command -v kubectl >/dev/null 2>&1 || die "kubectl is not installed or not in PATH"

# --- Arguments ---
SESSION_NAME="${1:-}"
[ -n "$SESSION_NAME" ] || die "Usage: teardown.sh <session-name>"

NAMESPACE="${PLAYWRIGHT_NAMESPACE:-playwright-sessions}"

# --- Delete Job and Service ---
echo "Tearing down session: ${SESSION_NAME} in namespace: ${NAMESPACE}" >&2

kubectl delete job "$SESSION_NAME" -n "$NAMESPACE" --ignore-not-found >&2
echo "Job deleted." >&2

kubectl delete service "$SESSION_NAME" -n "$NAMESPACE" --ignore-not-found >&2
echo "Service deleted." >&2

echo "Session ${SESSION_NAME} torn down successfully." >&2
