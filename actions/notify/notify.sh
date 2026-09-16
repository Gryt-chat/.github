#!/usr/bin/env bash
# Posts NOTIFY_PAYLOAD (Discord's shape) to NOTIFY_DISCORD_URL, and as cards to NOTIFY_GRYT_URL.
# Always exits 0: a broken alert path shouldn't turn the run it reports on red.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
payload="${NOTIFY_PAYLOAD:-}"
discord_url="${NOTIFY_DISCORD_URL:-}"
gryt_url="${NOTIFY_GRYT_URL:-}"

if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$payload"; then
  echo "::warning::The notification payload isn't a JSON object, so nothing was posted."
  exit 0
fi

# post <name> <url> <body>
post() {
  local name="$1" url="$2" body="$3" reply code
  reply="$(mktemp)"
  code="$(printf '%s' "$body" | curl -sS -o "$reply" -w '%{http_code}' --max-time 30 \
    -H 'Content-Type: application/json' --data-binary @- "$url")" || true

  if [[ "$code" == 2* ]]; then
    echo "$name: posted (HTTP $code)."
    # Gryt answers 200 even when it leaves part of a message out, and says what in `warnings`.
    NAME="$name" jq -r '.warnings[]? | "::warning::\(env.NAME): \(.path) \(.code): \(.message)"' \
      "$reply" 2>/dev/null
  else
    echo "::warning::$name: the post failed (HTTP ${code:-000}). $(head -c 500 "$reply" | tr '\n' ' ')"
  fi
  rm -f "$reply"
}

if [[ -n "$discord_url" ]]; then
  post Discord "$discord_url" "$payload"
else
  echo "Discord: no webhook URL, skipped."
fi

if [[ -n "$gryt_url" ]]; then
  if gryt_payload="$(jq -c -f "$here/to-gryt.jq" <<<"$payload")"; then
    post Gryt "$gryt_url" "$gryt_payload"
  else
    echo "::warning::Gryt: the payload couldn't be turned into cards, so nothing was posted."
  fi
else
  echo "Gryt: no webhook URL, skipped."
fi

exit 0
