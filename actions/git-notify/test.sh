#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

check() {
  local name="$1"
  local event="$2"
  local expected="$3"
  local file="$tmp/$name.json"
  cat > "$file"
  payload="$(bash "$here/build-payload.sh" "$event" "$file" "Gryt-chat/example" "fallback")"
  jq -e --arg expected "$expected" '.embeds[0].title | contains($expected)' <<<"$payload" >/dev/null
  jq -e '.embeds[0].fields | length >= 2' <<<"$payload" >/dev/null
}

check push push "2 commits pushed" <<'JSON'
{"ref":"refs/heads/main","deleted":false,"compare":"https://github.com/Gryt-chat/example/compare/a...b","sender":{"login":"alice"},"repository":{"full_name":"Gryt-chat/example","html_url":"https://github.com/Gryt-chat/example"},"commits":[{"id":"1111111aaaa","message":"one","author":{"username":"alice"}},{"id":"2222222bbbb","message":"two","author":{"name":"Bob"}}]}
JSON

check merged pull_request_target "PR #42 merged" <<'JSON'
{"action":"closed","sender":{"login":"alice"},"repository":{"full_name":"Gryt-chat/example","html_url":"https://github.com/Gryt-chat/example"},"pull_request":{"number":42,"title":"Ship it","body":"Done","html_url":"https://github.com/Gryt-chat/example/pull/42","merged":true,"base":{"ref":"main"},"head":{"ref":"feature"}}}
JSON

check comment issue_comment "Comment on issue #7" <<'JSON'
{"action":"created","sender":{"login":"bob"},"repository":{"full_name":"Gryt-chat/example","html_url":"https://github.com/Gryt-chat/example"},"issue":{"number":7,"title":"Bug","html_url":"https://github.com/Gryt-chat/example/issues/7"},"comment":{"body":"I can reproduce this.","html_url":"https://github.com/Gryt-chat/example/issues/7#issuecomment-1"}}
JSON

check branch create "Branch created: next" <<'JSON'
{"ref":"next","ref_type":"branch","sender":{"login":"carol"},"repository":{"full_name":"Gryt-chat/example","html_url":"https://github.com/Gryt-chat/example"}}
JSON

echo "git-notify payload tests passed"
