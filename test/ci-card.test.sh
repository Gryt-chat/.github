#!/usr/bin/env bash
# Runs the CI workflow's message step with a fake gh, the way a fork's failing run would look.
# Job names and the branch have to reach #ci as code, and the Gryt card has to fit the schema.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

node "$here/workflow-step.mjs" "$root/.github/workflows/discord-ci-notify.yml" notify message > "$tmp/step.sh"

cat > "$tmp/bin/gh" <<'SH'
#!/usr/bin/env bash
# Answers the jobs and runs endpoints from fixtures, through the caller's --jq filter.
filter="." path=""
while (( $# )); do
  case "$1" in
    --jq) filter="$2"; shift 2 ;;
    api) path="$2"; shift 2 ;;
    *) shift ;;
  esac
done
case "$path" in
  */jobs*) jq -r "$filter" "$FIXTURES/jobs.json" ;;
  *) jq -r "$filter" "$FIXTURES/runs.json" ;;
esac
SH
chmod +x "$tmp/bin/gh"

export FIXTURES="$tmp"
jq -n --arg tick '`' '{jobs: [
  {name: ("build [x](https://e.example) " + $tick + "oops" + $tick), conclusion: "failure"},
  {name: "lint", conclusion: "success"},
  {name: "test @everyone", conclusion: "timed_out"}
]}' > "$tmp/jobs.json"
echo '{"workflow_runs":[{"id":1,"conclusion":"failure"}]}' > "$tmp/runs.json"

failures=0
fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

# step <conclusion>: runs the step as a fork's pull_request run, outputs in $tmp/{discord,gryt}.json.
step() {
  : > "$tmp/output"
  env PATH="$tmp/bin:$PATH" GITHUB_OUTPUT="$tmp/output" HAS_DISCORD=true HAS_GRYT=true \
    CHANNEL="#ci" REPO=Gryt-chat/example WF_NAME=CI WF_ID=1 RUN_ID=2 RUN_NUMBER=7 \
    RUN_URL=https://github.com/Gryt-chat/example/actions/runs/2 CONCLUSION="$1" \
    BRANCH='patch`1' SHA=abcdef1234 ACTOR=stranger TRIGGER=pull_request \
    bash -e "$tmp/step.sh" > /dev/null
  sed -n 's/^payload=//p' "$tmp/output" > "$tmp/discord.json"
  sed -n 's/^gryt_payload=//p' "$tmp/output" > "$tmp/gryt-$1.json"
}

step failure
jq -e '.cards[0].description == "**Failed jobs**\n- `build [x](https://e.example) oops`\n- `test @everyone`"' \
  "$tmp/gryt-failure.json" >/dev/null || fail "failed job names aren't code spans: $(jq -c '.cards[0].description' "$tmp/gryt-failure.json")"
jq -e '.embeds[0].description == input.cards[0].description' "$tmp/discord.json" "$tmp/gryt-failure.json" >/dev/null \
  || fail "Discord and Gryt list the failed jobs differently"
jq -e '.cards[0].fields[] | select(.name == "Branch") | .value == "`patch1`"' "$tmp/gryt-failure.json" >/dev/null \
  || fail "the branch isn't a code span on the Gryt card"
jq -e '.embeds[0].fields[] | select(.name == "Branch") | .value == "`patch1`"' "$tmp/discord.json" >/dev/null \
  || fail "the branch isn't a code span on the Discord embed"

step success
jq -e '.cards[0].title == "✅ CI is green again"' "$tmp/gryt-success.json" >/dev/null || fail "no recovery card"

node "$here/check-gryt-payloads.mjs" "$tmp/gryt-failure.json" "$tmp/gryt-success.json" || failures=$((failures + 1))

if (( failures > 0 )); then
  echo "$failures CI card check(s) failed" >&2
  exit 1
fi
echo "CI card tests passed"
