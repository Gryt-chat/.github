#!/usr/bin/env bash
# Discord receives its native payload. Gryt receives NOTIFY_GRYT_PAYLOAD when
# supplied, otherwise the Discord payload is translated to Gryt cards.
# Notification failures warn but never turn the workflow being reported on red.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
payload="${NOTIFY_PAYLOAD:-}"
gryt_payload="${NOTIFY_GRYT_PAYLOAD:-}"
discord_url="${NOTIFY_DISCORD_URL:-}"
gryt_url="${NOTIFY_GRYT_URL:-}"

valid_object() {
  jq -e 'type == "object"' >/dev/null 2>&1 <<<"$1"
}

post() {
  local name="$1" url="$2" body="$3" reply code
  reply="$(mktemp)"
  code="$(printf '%s' "$body" | curl -sS --location --post301 --post302 --post303 --max-redirs 5 -o "$reply" -w '%{http_code}' --max-time 30     -H 'Content-Type: application/json' --data-binary @- "$url")" || true

  if [[ "$code" == 2* ]]; then
    echo "$name: posted (HTTP $code)."
    NAME="$name" jq -r '.warnings[]? | "::warning::\(env.NAME): \(.path) \(.code): \(.message)"'       "$reply" 2>/dev/null
  else
    echo "::warning::$name: the post failed (HTTP ${code:-000}). $(head -c 500 "$reply" | tr '\n' ' ')"
  fi
  rm -f "$reply"
}

if [[ -n "$discord_url" ]]; then
  if valid_object "$payload"; then
    post Discord "$discord_url" "$payload"
  else
    echo "::warning::Discord: the payload isn't a JSON object, so nothing was posted."
  fi
else
  echo "Discord: no webhook URL, skipped."
fi

if [[ -n "$gryt_url" ]]; then
  if [[ -n "$gryt_payload" ]]; then
    if valid_object "$gryt_payload"; then
      post Gryt "$gryt_url" "$gryt_payload"
    else
      echo "::warning::Gryt: the native payload isn't a JSON object, so nothing was posted."
    fi
  elif valid_object "$payload"; then
    if translated="$(jq -c -f "$here/to-gryt.jq" <<<"$payload")"; then
      post Gryt "$gryt_url" "$translated"
    else
      echo "::warning::Gryt: the Discord payload couldn't be turned into cards."
    fi
  else
    echo "::warning::Gryt: there is no valid payload to post."
  fi
else
  echo "Gryt: no webhook URL, skipped."
fi

exit 0
