#!/usr/bin/env bash
# Discord gets its own payload, Gryt the native one or a translation, cut to the server's limits.
# A failed post warns and never turns the workflow being reported on red.

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
  local name="$1" url="${2//[[:space:]]/}" body="$3" reply code attempt wait

  # The token is in the URL, so plain http would send it in the clear, redirect or not.
  case "${url,,}" in
    https://*) ;;
    http://*)
      url="https://${url#*://}"
      echo "::warning::$name: the webhook URL starts with http://, which would send its token unencrypted. It was posted over https:// instead. Change the secret to https://."
      ;;
    *)
      echo "::warning::$name: the webhook URL isn't an https:// address, so nothing was posted."
      return
      ;;
  esac

  reply="$(mktemp)"
  for attempt in 1 2; do
    code="$(printf '%s' "$body" | curl -sS --proto =https --max-time 30 -o "$reply" -w '%{http_code}' \
      -H 'Content-Type: application/json' --data-binary @- "$url")" || true
    [[ "$code" == 429 && "$attempt" == 1 ]] || break
    wait="$(jq -r '(.retry_after_ms // ((.retry_after // empty) * 1000)) | numbers | floor' "$reply" 2>/dev/null)"
    [[ "$wait" =~ ^[0-9]+$ ]] || break
    # Jitter, so cards held back by the same ban don't all come back in the same second.
    wait=$(( wait / 1000 + 1 + RANDOM % 10 ))
    (( wait <= 90 )) || wait=90
    echo "$name: rate limited, trying once more in ${wait}s."
    sleep "$wait"
  done

  if [[ "$code" == 2* ]]; then
    echo "$name: posted (HTTP $code)."
    NAME="$name" jq -r '.warnings[]? | "::warning::\(env.NAME): \(.path) \(.code): \(.message)"' \
      "$reply" 2>/dev/null
  elif [[ "$code" == 3* ]]; then
    echo "::warning::$name: the webhook URL answered HTTP $code, a redirect, and redirects aren't followed. Point the secret at the address it redirects to."
  else
    # Only a JSON reply is shown. An HTML error page can quote the URL, token and all.
    echo "::warning::$name: the post failed (HTTP ${code:-000}). $(jq -c . "$reply" 2>/dev/null | head -c 500)"
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

if [[ -z "$gryt_url" ]]; then
  echo "Gryt: no webhook URL, skipped."
elif [[ -n "$gryt_payload" ]] && ! valid_object "$gryt_payload"; then
  echo "::warning::Gryt: the native payload isn't a JSON object, so nothing was posted."
elif [[ -z "$gryt_payload" ]] && ! valid_object "$payload"; then
  echo "::warning::Gryt: there is no valid payload to post."
else
  if [[ -n "$gryt_payload" ]]; then
    fitted="$(jq -c -f "$here/fit-gryt.jq" <<<"$gryt_payload")"
  else
    fitted="$(jq -c -f "$here/to-gryt.jq" <<<"$payload" | jq -c -f "$here/fit-gryt.jq")"
  fi
  if valid_object "$fitted"; then
    post Gryt "$gryt_url" "$fitted"
  else
    echo "::warning::Gryt: nothing in the payload fits a Gryt message, so nothing was posted."
  fi
fi

exit 0
