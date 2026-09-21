#!/usr/bin/env bash
# Builds cards from recorded events and posts them through notify.sh to a fake curl.
# What would have been sent is checked here, then against the server's own schema.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
notify="$root/actions/notify/notify.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [[ ! -d "$root/test/node_modules/zod" ]]; then
  echo "Install the schema check first: yarn install --frozen-lockfile --cwd test" >&2
  exit 1
fi

export FAKE="$tmp/fake"
mkdir -p "$FAKE" "$tmp/bin" "$tmp/events" "$tmp/payloads"

cat > "$tmp/bin/curl" <<'SH'
#!/usr/bin/env bash
# Keeps the body and arguments, and answers with the next code queued in $FAKE/codes.
printf '%s\n' "$*" >> "$FAKE/calls.log"
out="" url=""
while (( $# )); do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -w|-H|--max-time|--proto|--data-binary) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
n=$(( $(find "$FAKE" -name 'sent-*.json' | wc -l) + 1 ))
cat > "$FAKE/sent-$n.json"
if [[ "$url" != https://* ]]; then
  echo "curl: (1) Protocol not supported" >&2
  printf '000'
  exit 1
fi
code="$(head -n 1 "$FAKE/codes" 2>/dev/null)"
tail -n +2 "$FAKE/codes" > "$FAKE/codes.next" 2>/dev/null && mv "$FAKE/codes.next" "$FAKE/codes"
code="${code:-200}"
case "$code" in
  2*) reply='{"message_id":"m1","conversation_id":"c1","warnings":[]}' ;;
  429) reply="$(cat "$FAKE/reply-429" 2>/dev/null || echo '{"error":"rate_limited","retry_after_ms":1500}')" ;;
  3*) reply='<html>Moved to https://gryt.example/api/webhooks/1/SECRET-TOKEN</html>' ;;
  *) reply='{"error":"invalid_payload","message":"The payload has 1 problem."}' ;;
esac
printf '%s' "$reply" > "$out"
printf '%s' "$code"
SH
cat > "$tmp/bin/sleep" <<'SH'
#!/usr/bin/env bash
echo "$1" >> "$FAKE/sleeps.log"
SH
chmod +x "$tmp/bin/curl" "$tmp/bin/sleep"

failures=0
fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

reset_fake() {
  rm -f "$FAKE"/*
  printf '%s\n' "$@" > "$FAKE/codes"
}

# notify <gryt url> <payload>: runs notify.sh against the fake curl, output in $FAKE/log.
notify() {
  NOTIFY_GRYT_URL="$1" NOTIFY_GRYT_PAYLOAD="$2" PATH="$tmp/bin:$PATH" bash "$notify" > "$FAKE/log" 2>&1
}

calls() {
  if [[ -f "$FAKE/calls.log" ]]; then wc -l < "$FAKE/calls.log" | tr -d ' '; else echo 0; fi
}

hook="https://gryt.example/api/webhooks/1/SECRET-TOKEN"

# card <name> <event>: builds a card from the event JSON on stdin and posts it. The body that
# went out lands in $tmp/payloads/<name>.json. An event that makes no card leaves no file.
card() {
  local name="$1" event="$2" payload
  cat > "$tmp/events/$name.json"
  payload="$(bash "$here/build-payload.sh" "$event" "$tmp/events/$name.json" "Gryt-chat/example" "fallback")"
  [[ -n "$payload" ]] || return 0
  reset_fake
  notify "$hook" "$payload"
  if [[ -f "$FAKE/sent-1.json" ]]; then
    cp "$FAKE/sent-1.json" "$tmp/payloads/$name.json"
  else
    fail "$name: nothing was posted"; cat "$FAKE/log" >&2
  fi
}

# expect <name> <jq filter>: the posted card for <name> must satisfy the filter.
expect() {
  local name="$1" filter="$2"
  if [[ ! -f "$tmp/payloads/$name.json" ]]; then
    fail "$name: no card was posted, expected one where $filter"
  elif ! jq -e "$filter" "$tmp/payloads/$name.json" >/dev/null; then
    fail "$name: $filter"; jq . "$tmp/payloads/$name.json" >&2
  fi
}

no_card() {
  [[ ! -f "$tmp/payloads/$1.json" ]] || fail "$1: expected no card, got $(cat "$tmp/payloads/$1.json")"
}

repo='"repository":{"full_name":"Gryt-chat/example","html_url":"https://github.com/Gryt-chat/example"}'
base='"base":{"ref":"main","repo":{"full_name":"Gryt-chat/example"}}'
same='"head":{"ref":"feature","label":"Gryt-chat:feature","repo":{"full_name":"Gryt-chat/example"}}'
fork='"head":{"ref":"patch-1","label":"stranger:patch-1","repo":{"full_name":"stranger/example"}}'
lure='Hi! [Your account is locked, sign in here](https://phish.example) @everyone'

pr() {  # pr <association> <head> <body>
  printf '{"number":42,"title":"Ship it","body":%s,"html_url":"https://github.com/Gryt-chat/example/pull/42","merged":false,"author_association":"%s",%s,%s}' \
    "$(jq -n --arg b "$3" '$b')" "$1" "$base" "$2"
}

# ── pushes ──────────────────────────────────────────────────────────────────────

card push push <<JSON
{"ref":"refs/heads/main","created":false,"deleted":false,"compare":"https://github.com/Gryt-chat/example/compare/a...b","sender":{"login":"alice"},$repo,"commits":[{"id":"1111111aaaa","message":"one\n\nmore","author":{"username":"alice"}},{"id":"2222222bbbb","message":"two","author":{"name":"Bob"}}]}
JSON
expect push '.display_name == "GitHub" and .cards[0].title == "2 commits pushed to main"'
expect push '.cards[0].description | contains("[1111111](https://github.com/Gryt-chat/example/commit/1111111aaaa) one — alice")'
expect push '.cards[0].author.name == "Gryt-chat/example" and (.cards[0].color | test("^#[0-9a-f]{6}$"))'
expect push '.cards[0].timestamp | test("Z$")'

long_branch="feature/$(printf 'ä%.0s' {1..200})$(printf '🦉%.0s' {1..90})"
card push-long-branch push <<JSON
{"ref":"refs/heads/$long_branch","created":false,"deleted":false,"compare":"https://github.com/Gryt-chat/example/compare/a...b","sender":{"login":"alice"},$repo,"commits":[{"id":"3333333cccc","message":"three","author":{"username":"alice"}}]}
JSON
expect push-long-branch '.cards[0].title | startswith("1 commit pushed to feature/ä") and endswith("…")'
expect push-long-branch '.cards[0].title | [explode[] | if . > 65535 then 2 else 1 end] | add <= 256'

card branch create <<JSON
{"ref":"next","ref_type":"branch","sender":{"login":"carol"},$repo}
JSON
expect branch '.cards[0].title == "Branch created: next"'

# ── pull requests ───────────────────────────────────────────────────────────────

card pr-member pull_request_target <<JSON
{"action":"opened","sender":{"login":"alice"},$repo,"pull_request":$(pr MEMBER "$same" "Adds the thing.")}
JSON
expect pr-member '.cards[0].title == "PR #42 opened: Ship it" and .cards[0].description == "Adds the thing."'
expect pr-member '.cards[0].url == "https://github.com/Gryt-chat/example/pull/42"'
expect pr-member '.cards[0].fields | map(.value) | index("main ← feature") != null'

for who in NONE FIRST_TIMER FIRST_TIME_CONTRIBUTOR MANNEQUIN; do
  card "pr-$who" pull_request_target <<JSON
{"action":"opened","sender":{"login":"stranger"},$repo,"pull_request":$(pr "$who" "$fork" "$lure")}
JSON
  expect "pr-$who" '.cards[0].title == "PR #42 opened: Ship it" and (.cards[0] | has("description") | not)'
  expect "pr-$who" '.cards[0].url == "https://github.com/Gryt-chat/example/pull/42"'
  expect "pr-$who" '[.. | strings | select(contains("phish") or contains("@everyone"))] == []'
done
expect pr-NONE '.cards[0].fields | map(.value) | index("main ← \u0060stranger:patch-1\u0060") != null'

card pr-no-association pull_request_target <<JSON
{"action":"opened","sender":{"login":"stranger"},$repo,"pull_request":{"number":42,"title":"Ship it","body":"$lure","html_url":"https://github.com/Gryt-chat/example/pull/42",$base,$fork}}
JSON
expect pr-no-association '.cards[0] | has("description") | not'

card pr-merged pull_request_target <<JSON
{"action":"closed","sender":{"login":"alice"},$repo,"pull_request":$(pr MEMBER "$same" "Adds the thing." | jq -c '.merged = true')}
JSON
expect pr-merged '.cards[0].title == "PR #42 merged: Ship it" and .cards[0].color == "#3fb27f"'
expect pr-merged '.cards[0] | has("description") | not'

card pr-sync-same pull_request_target <<JSON
{"action":"synchronize","sender":{"login":"alice"},$repo,"pull_request":$(pr MEMBER "$same" "Adds the thing.")}
JSON
no_card pr-sync-same

card pr-sync-fork pull_request_target <<JSON
{"action":"synchronize","sender":{"login":"stranger"},$repo,"pull_request":$(pr NONE "$fork" "$lure")}
JSON
expect pr-sync-fork '.cards[0].title == "PR #42 updated: Ship it" and (.cards[0] | has("description") | not)'

card pr-sync-contributor pull_request_target <<JSON
{"action":"synchronize","sender":{"login":"bob"},$repo,"pull_request":$(pr CONTRIBUTOR "$fork" "Adds the thing.")}
JSON
expect pr-sync-contributor '.cards[0] | has("description") | not'

# ── issues and comments ─────────────────────────────────────────────────────────

issue() {  # issue <association> <body>
  printf '{"number":7,"title":"Bug","body":%s,"html_url":"https://github.com/Gryt-chat/example/issues/7","author_association":"%s"}' \
    "$(jq -n --arg b "$2" '$b')" "$1"
}

card issue-owner issues <<JSON
{"action":"opened","sender":{"login":"alice"},$repo,"issue":$(issue OWNER "It breaks when I click it.")}
JSON
expect issue-owner '.cards[0].title == "Issue #7 opened: Bug" and .cards[0].description == "It breaks when I click it."'

card issue-stranger issues <<JSON
{"action":"opened","sender":{"login":"stranger"},$repo,"issue":$(issue NONE "$lure")}
JSON
expect issue-stranger '.cards[0].title == "Issue #7 opened: Bug" and (.cards[0] | has("description") | not)'
expect issue-stranger '.cards[0].url == "https://github.com/Gryt-chat/example/issues/7"'

card issue-labeled issues <<JSON
{"action":"labeled","label":{"name":"bug"},"sender":{"login":"alice"},$repo,"issue":$(issue OWNER "It breaks.")}
JSON
no_card issue-labeled

card issue-closed issues <<JSON
{"action":"closed","sender":{"login":"alice"},$repo,"issue":$(issue OWNER "It breaks.")}
JSON
expect issue-closed '.cards[0].title == "Issue #7 closed: Bug" and (.cards[0] | has("description") | not)'

owls="$(printf '🦉%.0s' {1..300})"
card issue-long-title issues <<JSON
{"action":"opened","sender":{"login":"alice"},$repo,"issue":$(issue OWNER "Body." | jq -c --arg t "$owls" '.title = $t')}
JSON
expect issue-long-title '.cards[0].title | [explode[] | if . > 65535 then 2 else 1 end] | add <= 256'

comment() {  # comment <association> <body>
  printf '{"body":%s,"html_url":"https://github.com/Gryt-chat/example/issues/7#issuecomment-1","author_association":"%s"}' \
    "$(jq -n --arg b "$2" '$b')" "$1"
}

card comment-stranger issue_comment <<JSON
{"action":"created","sender":{"login":"stranger"},$repo,"issue":$(issue OWNER "It breaks."),"comment":$(comment NONE "$lure")}
JSON
expect comment-stranger '.cards[0].title == "Comment on issue #7: Bug" and (.cards[0] | has("description") | not)'
expect comment-stranger '.cards[0].url == "https://github.com/Gryt-chat/example/issues/7#issuecomment-1"'

card comment-collaborator issue_comment <<JSON
{"action":"created","sender":{"login":"bob"},$repo,"issue":$(issue OWNER "It breaks."),"comment":$(comment COLLABORATOR "I can reproduce this.")}
JSON
expect comment-collaborator '.cards[0].description == "I can reproduce this."'

card comment-on-pr issue_comment <<JSON
{"action":"created","sender":{"login":"bob"},$repo,"issue":$(issue OWNER "x" | jq -c '.title = "Ship it" | .number = 42 | .pull_request = {}'),"comment":$(comment MEMBER "Looks good.")}
JSON
expect comment-on-pr '.cards[0].title == "Comment on PR #42: Ship it"'

card discussion-comment discussion_comment <<JSON
{"action":"created","sender":{"login":"stranger"},$repo,"discussion":{"number":5,"title":"Ideas","html_url":"https://github.com/Gryt-chat/example/discussions/5"},"comment":$(comment NONE "$lure")}
JSON
expect discussion-comment '.cards[0].title == "Comment on discussion #5: Ideas" and (.cards[0] | has("description") | not)'

# ── reviews ─────────────────────────────────────────────────────────────────────

review() {  # review <state> <association> <body>
  printf '{"state":"%s","body":%s,"html_url":"https://github.com/Gryt-chat/example/pull/42#pullrequestreview-1","author_association":"%s"}' \
    "$1" "$(jq -n --arg b "$3" 'if $b == "null" then null else $b end')" "$2"
}

card review-approved-blank pull_request_review <<JSON
{"action":"submitted","sender":{"login":"alice"},$repo,"pull_request":$(pr MEMBER "$same" "x"),"review":$(review approved MEMBER $' \n\t ')}
JSON
expect review-approved-blank '.cards[0].title == "PR #42 approved: Ship it" and (.cards[0] | has("description") | not)'

card review-approved-null pull_request_review <<JSON
{"action":"submitted","sender":{"login":"alice"},$repo,"pull_request":$(pr MEMBER "$same" "x"),"review":$(review approved MEMBER null)}
JSON
expect review-approved-null '.cards[0] | has("description") | not'

card review-commented-empty pull_request_review <<JSON
{"action":"submitted","sender":{"login":"alice"},$repo,"pull_request":$(pr MEMBER "$same" "x"),"review":$(review commented MEMBER "")}
JSON
no_card review-commented-empty

card review-stranger pull_request_review <<JSON
{"action":"submitted","sender":{"login":"stranger"},$repo,"pull_request":$(pr MEMBER "$same" "x"),"review":$(review commented NONE "$lure")}
JSON
expect review-stranger '.cards[0].title == "Review submitted on PR #42: Ship it" and (.cards[0] | has("description") | not)'

card review-comment-stranger pull_request_review_comment <<JSON
{"action":"created","sender":{"login":"stranger"},$repo,"pull_request":$(pr MEMBER "$same" "x"),"comment":$(comment NONE "$lure")}
JSON
expect review-comment-stranger '.cards[0] | has("description") | not'

# ── the sender ──────────────────────────────────────────────────────────────────

small='{"display_name":"GitHub","cards":[{"title":"Hello"}]}'

reset_fake 200
notify "http://gryt.example/api/webhooks/1/SECRET-TOKEN" "$small"
grep -q ' https://gryt.example/api/webhooks/1/SECRET-TOKEN$' "$FAKE/calls.log" \
  || fail "an http:// webhook URL wasn't moved to https:// before posting"
grep -q 'http://' "$FAKE/calls.log" && fail "curl was handed an http:// URL"
grep -q '::warning::Gryt: the webhook URL starts with http://' "$FAKE/log" || fail "no warning about the http:// secret"
grep -q 'SECRET-TOKEN' "$FAKE/log" && fail "the webhook token was printed"

reset_fake 200
notify "HTTP://gryt.example/api/webhooks/1/SECRET-TOKEN"$'\n' "$small"
grep -q ' https://gryt.example/api/webhooks/1/SECRET-TOKEN$' "$FAKE/calls.log" \
  || fail "an upper-case HTTP:// URL with a trailing newline wasn't posted to https://"

grep -q -- '--proto =https' "$FAKE/calls.log" || fail "curl isn't limited to https"
grep -qE -- '(^| )(-L|--location)( |$)' "$FAKE/calls.log" && fail "curl follows redirects"

reset_fake
notify "ftp://gryt.example/api/webhooks/1/SECRET-TOKEN" "$small"
[[ "$(calls)" == 0 ]] || fail "a webhook URL that isn't http(s) was posted to"
grep -q "isn't an https:// address" "$FAKE/log" || fail "no warning about a non-https webhook URL"

reset_fake 301
notify "$hook" "$small"
[[ "$(calls)" == 1 ]] || fail "a redirect was followed"
grep -q 'a redirect' "$FAKE/log" || fail "no warning about the redirect"
grep -q 'SECRET-TOKEN' "$FAKE/log" && fail "the redirect page, token and all, was printed"

reset_fake 429 200
notify "$hook" "$small"
[[ "$(calls)" == 2 ]] || fail "a 429 wasn't retried once ($(calls) posts)"
wait="$(cat "$FAKE/sleeps.log" 2>/dev/null)"
if [[ ! "$wait" =~ ^[0-9]+$ ]] || (( wait < 2 || wait > 11 )); then
  fail "slept '$wait' after retry_after_ms 1500"
fi
grep -q 'posted (HTTP 200)' "$FAKE/log" || fail "the retry's success wasn't reported"

reset_fake 429 429 429
notify "$hook" "$small"
[[ "$(calls)" == 2 ]] || fail "a 429 was retried more than once ($(calls) posts)"
grep -q 'failed (HTTP 429)' "$FAKE/log" || fail "a second 429 wasn't reported"

reset_fake 429 200
echo '<html>Too many requests</html>' > "$FAKE/reply-429"
notify "$hook" "$small"
[[ "$(calls)" == 1 ]] || fail "a 429 without retry_after_ms was retried"

reset_fake 429 200
echo '{"error":"rate_limited","retry_after_ms":600000}' > "$FAKE/reply-429"
notify "$hook" "$small"
[[ "$(cat "$FAKE/sleeps.log")" == 90 ]] || fail "a ten-minute retry_after_ms wasn't capped at 90 s"

reset_fake
notify "$hook" '{"cards":[{"title":"  ","description":"\n"}]}'
[[ "$(calls)" == 0 ]] || fail "a card with nothing but blanks was posted"

big="$(jq -cn '{cards: [range(12) | {title: ("t" * 300), description: ("d" * 5000), fields: [range(30) | {name: " ", value: "v"}]}]}')"
reset_fake 200
notify "$hook" "$big"
cp "$FAKE/sent-1.json" "$tmp/payloads/oversized.json"
expect oversized '(.cards | length) == 10 and all(.cards[]; has("fields") | not)'
expect oversized '[.cards[].title | [explode[] | if . > 65535 then 2 else 1 end] | add] | max <= 256'

# ── the server's schema ─────────────────────────────────────────────────────────

node "$root/test/check-gryt-payloads.mjs" "$tmp"/payloads/*.json || failures=$((failures + 1))

if (( failures > 0 )); then
  echo "$failures git-notify check(s) failed" >&2
  exit 1
fi
echo "git-notify payload tests passed"
