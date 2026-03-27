#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

# --- Dependencies ---
command -v kubectl >/dev/null 2>&1 || die "kubectl is not installed or not in PATH"

# --- Configuration ---
NAMESPACE="${PLAYWRIGHT_NAMESPACE:-playwright-sessions}"
TIMEOUT="${PLAYWRIGHT_TIMEOUT:-120}"
TTL="${PLAYWRIGHT_TTL:-1800}"
DEADLINE="${PLAYWRIGHT_DEADLINE:-1800}"
MEMORY_REQUEST="${PLAYWRIGHT_MEMORY_REQUEST:-512Mi}"
MEMORY_LIMIT="${PLAYWRIGHT_MEMORY_LIMIT:-1Gi}"

# Generate unique session name
AGENT_NAME="${PAPERCLIP_AGENT_ID:-agent}"
# Use first 8 chars of agent ID + random suffix
AGENT_SHORT="${AGENT_NAME:0:8}"
SHORT_UUID=$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 8)
SESSION_NAME="playwright-${AGENT_SHORT}-${SHORT_UUID}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REF_DIR="${SCRIPT_DIR}/../references"

# --- Ensure namespace exists ---
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "Creating namespace $NAMESPACE..." >&2
  kubectl create namespace "$NAMESPACE"
fi

# --- Render and apply Job manifest ---
sed \
  -e "s|{{SESSION_NAME}}|${SESSION_NAME}|g" \
  -e "s|{{NAMESPACE}}|${NAMESPACE}|g" \
  -e "s|{{TTL}}|${TTL}|g" \
  -e "s|{{DEADLINE}}|${DEADLINE}|g" \
  -e "s|{{MEMORY_REQUEST}}|${MEMORY_REQUEST}|g" \
  -e "s|{{MEMORY_LIMIT}}|${MEMORY_LIMIT}|g" \
  "$REF_DIR/job-template.yaml" | kubectl apply -f - >&2

# --- Render and apply Service manifest ---
sed \
  -e "s|{{SESSION_NAME}}|${SESSION_NAME}|g" \
  -e "s|{{NAMESPACE}}|${NAMESPACE}|g" \
  "$REF_DIR/svc-template.yaml" | kubectl apply -f - >&2

# --- Wait for pod to be Ready ---
echo "Waiting for pod to be ready (timeout: ${TIMEOUT}s)..." >&2
SECONDS=0
POD_READY=false

while [ "$SECONDS" -lt "$TIMEOUT" ]; do
  POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "session=${SESSION_NAME}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [ -n "$POD_NAME" ]; then
    PHASE=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || true)
    if [ "$PHASE" = "Running" ]; then
      READY=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || true)
      if [ "$READY" = "true" ]; then
        POD_READY=true
        break
      fi
    elif [ "$PHASE" = "Failed" ] || [ "$PHASE" = "Succeeded" ]; then
      # Cleanup on failure
      echo "Pod entered $PHASE state unexpectedly. Cleaning up..." >&2
      kubectl delete job "$SESSION_NAME" -n "$NAMESPACE" --ignore-not-found >&2
      kubectl delete service "$SESSION_NAME" -n "$NAMESPACE" --ignore-not-found >&2
      die "Pod failed to start (phase: $PHASE)"
    fi
  fi

  sleep 3
done

if [ "$POD_READY" != "true" ]; then
  echo "Timed out waiting for MCP server. Cleaning up..." >&2
  kubectl delete job "$SESSION_NAME" -n "$NAMESPACE" --ignore-not-found >&2
  kubectl delete service "$SESSION_NAME" -n "$NAMESPACE" --ignore-not-found >&2
  die "Playwright MCP server did not become ready within ${TIMEOUT}s"
fi

MCP_URL="http://${SESSION_NAME}.${NAMESPACE}.svc.cluster.local:8931/mcp"

echo "Playwright MCP session ready." >&2
echo "SESSION_NAME=${SESSION_NAME}"
echo "MCP_URL=${MCP_URL}"
