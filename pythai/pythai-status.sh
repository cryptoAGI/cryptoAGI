#!/usr/bin/env bash
# pythai-status.sh — produce the live/deploy admin breakdown for pythai.net.
#
# Runs ON the VPS (where the systems live), probes each system in systems.json, and writes
# status.json — the live feed the pythai.net portal renders. pythai.net stays INDEPENDENT of the
# VPS: the VPS pushes this file to Hostinger (see WIRING.md), it does not expose its ports.
#
#   ./pythai-status.sh                 # write status.json next to systems.json
#   ./pythai-status.sh --print         # also print a human table
#   PYTHAI_MANIFEST=… PYTHAI_OUT=…  ./pythai-status.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAN="${PYTHAI_MANIFEST:-$HERE/systems.json}"
OUT="${PYTHAI_OUT:-$HERE/status.json}"
PRINT=0; [ "${1:-}" = "--print" ] && PRINT=1
command -v jq >/dev/null || { echo "needs jq (apt install jq)"; exit 1; }

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
probe_http(){ # url -> "code time_total" (000 on failure)
  curl -sS -o /dev/null -m 8 -w '%{http_code} %{time_total}' "$1" 2>/dev/null || echo "000 0"
}
probe_port(){ # host port -> up|down (localhost systems on the VPS)
  (exec 3<>"/dev/tcp/$1/$2") 2>/dev/null && { exec 3>&-; echo up; } || echo down
}

# build the systems array with live status merged in
systems_json="$(jq -c '.systems[]' "$MAN" | while read -r sys; do
  key=$(jq -r '.key' <<<"$sys"); sub=$(jq -r '.subdomain' <<<"$sys"); exists=$(jq -r '.exists' <<<"$sys")
  machine=$(jq -r '.machine' <<<"$sys")
  live="unknown"; code=""; rt=""
  if [ "$exists" = "true" ]; then
    read -r code rt < <(probe_http "https://$sub/")
    if [ "$code" = "000" ]; then live="down"; elif [ "${code:0:1}" = "2" ] || [ "${code:0:1}" = "3" ]; then live="up"; else live="degraded"; fi
  else
    live="not-created"
  fi
  # local port check (only meaningful when this script runs on the VPS that hosts the ports)
  ports=$(jq -c '.localPorts // []' <<<"$sys"); portstat="[]"
  if [ "$ports" != "[]" ]; then
    portstat="$(jq -r '.localPorts[]' <<<"$sys" | while read -r p; do
      st=$(probe_port 127.0.0.1 "$p"); printf '{"port":%s,"state":"%s"}\n' "$p" "$st"; done | jq -s -c '.')"
  fi
  jq -c --arg live "$live" --arg code "$code" --arg rt "$rt" --argjson ports "$portstat" \
     '. + {live:$live, httpCode:($code|tonumber? // 0), responseS:($rt|tonumber? // 0), localPortStatus:$ports}' <<<"$sys"
done | jq -s -c '.')"

jq -n --arg ts "$now" --argjson systems "$systems_json" \
  --arg portal "$(jq -r '.portal' "$MAN")" --arg tagline "$(jq -r '.tagline' "$MAN")" \
  '{portal:$portal, tagline:$tagline, generatedAt:$ts,
    summary:{ total:($systems|length),
              up:([$systems[]|select(.live=="up")]|length),
              down:([$systems[]|select(.live=="down")]|length),
              notCreated:([$systems[]|select(.live=="not-created")]|length) },
    systems:$systems}' > "$OUT"

echo "wrote $OUT ($(jq '.summary' "$OUT" | tr -d '\n '))"
if [ "$PRINT" = 1 ]; then
  printf '\n  %-14s %-26s %-12s %s\n' SYSTEM SUBDOMAIN LIVE CODE
  jq -r '.systems[] | "  \(.name)\t\(.subdomain)\t\(.live)\t\(.httpCode)"' "$OUT" \
    | while IFS=$'\t' read -r n s l c; do printf '  %-14s %-26s %-12s %s\n' "$n" "$s" "$l" "$c"; done
fi
