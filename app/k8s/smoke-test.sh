#!/usr/bin/env bash
#
# Kontrollerar att hello-app svarar efter en deploy till AKS.
#
# Öppnar en tillfällig tunnel till appen med kubectl port-forward, så att
# appen inte behöver vara nåbar från internet. Kräver att kubectl redan är
# kopplat till klustret (az aks get-credentials).
#
# Användning: ./smoke-test.sh

set -euo pipefail

NAMESPACE="hello-app"
SERVICE="service/hello-app"

# En port på den egna maskinen som sällan används av något annat.
LOCAL_PORT=18080

# Hur länge vi väntar på att tunneln ska komma upp. port-forward brukar
# behöva några sekunder.
MAX_ATTEMPTS=10
SECONDS_BETWEEN_ATTEMPTS=2

EXPECTED_HEALTH_RESPONSE='"status":"ok"'

start_port_forward() {
  kubectl port-forward --namespace "$NAMESPACE" "$SERVICE" "$LOCAL_PORT:80" >/dev/null 2>&1 &
  PORT_FORWARD_PID=$!
}

stop_port_forward() {
  kill "$PORT_FORWARD_PID" 2>/dev/null || true
}

# Hämtar /health och skriver ut svaret. Försöker igen medan tunneln startar.
fetch_health() {
  local attempt
  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    if curl --silent --fail "http://localhost:$LOCAL_PORT/health"; then
      return 0
    fi
    echo "Försök $attempt av $MAX_ATTEMPTS misslyckades, väntar..." >&2
    sleep "$SECONDS_BETWEEN_ATTEMPTS"
  done
  return 1
}

main() {
  start_port_forward
  trap stop_port_forward EXIT

  local response
  if ! response=$(fetch_health); then
    echo "FEL: appen svarade inte på /health." >&2
    exit 1
  fi

  if [[ "$response" != *"$EXPECTED_HEALTH_RESPONSE"* ]]; then
    echo "FEL: oväntat svar från /health: $response" >&2
    exit 1
  fi

  echo "OK: appen svarar på /health ($response)"
  echo "Startsidan svarar med:"
  curl --silent "http://localhost:$LOCAL_PORT/"
  echo
}

main
