#!/usr/bin/env bash
set -euo pipefail

event_name="${1:-}"
event_path="${2:-}"
repo="${3:-}"
fallback_actor="${4:-}"

if [[ -z "$event_name" || -z "$event_path" || ! -f "$event_path" ]]; then
  echo "git-notify: missing event name or payload" >&2
  exit 1
fi

jq_raw() {
  jq -r "$1 // empty" "$event_path"
}

action="$(jq_raw '.action')"
actor="$(jq_raw '.sender.login')"
[[ -n "$actor" ]] || actor="$fallback_actor"
[[ -n "$repo" ]] || repo="$(jq_raw '.repository.full_name')"

title=""
url="$(jq_raw '.repository.html_url')"
description=""
context=""
color=5793266

case "$event_name" in
  push)
    ref="$(jq_raw '.ref')"
    deleted="$(jq -r '.deleted // false' "$event_path")"
    [[ "$deleted" != "true" && "$ref" == refs/heads/* ]] || exit 0
    branch="${ref#refs/heads/}"
    count="$(jq '.commits | length' "$event_path")"
    if [[ "$count" -eq 1 ]]; then
      title="⬆️ 1 commit pushed to $branch"
    elif [[ "$count" -gt 1 ]]; then
      title="⬆️ $count commits pushed to $branch"
    else
      title="⬆️ $branch updated"
    fi
    url="$(jq_raw '.compare')"
    [[ -n "$url" ]] || url="$(jq_raw '.head_commit.url')"
    description="$(jq -r '
      [.commits[:6][] |
        ("[" + (.id[0:7]) + "] " +
         ((.message // "") | split("\n")[0]) + " — " +
         (.author.username // .author.name // "unknown"))
      ] | join("\n") | .[0:1800]
    ' "$event_path")"
    context="$branch"
    ;;

  pull_request|pull_request_target)
    number="$(jq_raw '.pull_request.number')"
    pr_title="$(jq_raw '.pull_request.title')"
    url="$(jq_raw '.pull_request.html_url')"
    merged="$(jq -r '.pull_request.merged // false' "$event_path")"
    case "$action" in
      opened)             title="🔀 PR #$number opened" ;;
      reopened)           title="🔀 PR #$number reopened" ;;
      synchronize)        title="🔄 PR #$number updated" ;;
      ready_for_review)   title="👀 PR #$number ready for review" ;;
      converted_to_draft) title="📝 PR #$number converted to draft" ;;
      review_requested)   title="👀 Review requested on PR #$number" ;;
      closed)
        if [[ "$merged" == "true" ]]; then
          title="✅ PR #$number merged"
          color=5763719
        else
          title="❌ PR #$number closed"
          color=9807270
        fi
        ;;
      *) title="🔀 PR #$number ${action:-changed}" ;;
    esac
    body="$(jq -r '(.pull_request.body // "")[0:1200]' "$event_path")"
    description="$pr_title"
    [[ -z "$body" ]] || description="$description"$'\n\n'"$body"
    context="$(jq -r '.pull_request.base.ref + " ← " + .pull_request.head.ref' "$event_path")"
    ;;

  issues)
    number="$(jq_raw '.issue.number')"
    issue_title="$(jq_raw '.issue.title')"
    url="$(jq_raw '.issue.html_url')"
    case "$action" in
      opened)     title="📌 Issue #$number opened" ;;
      reopened)   title="📌 Issue #$number reopened" ;;
      closed)     title="✅ Issue #$number closed"; color=5763719 ;;
      labeled)    title="🏷️ Issue #$number labeled" ;;
      unlabeled)  title="🏷️ Issue #$number unlabeled" ;;
      assigned)   title="👤 Issue #$number assigned" ;;
      unassigned) title="👤 Issue #$number unassigned" ;;
      *) title="📌 Issue #$number ${action:-changed}" ;;
    esac
    body="$(jq -r '(.issue.body // "")[0:1200]' "$event_path")"
    description="$issue_title"
    [[ -z "$body" ]] || description="$description"$'\n\n'"$body"
    context="#$number"
    ;;

  issue_comment)
    number="$(jq_raw '.issue.number')"
    url="$(jq_raw '.comment.html_url')"
    if jq -e '.issue.pull_request != null' "$event_path" >/dev/null; then
      title="💬 Comment on PR #$number"
    else
      title="💬 Comment on issue #$number"
    fi
    description="$(jq -r '(.comment.body // "")[0:1800]' "$event_path")"
    context="#$number"
    ;;

  pull_request_review)
    number="$(jq_raw '.pull_request.number')"
    state="$(jq_raw '.review.state')"
    url="$(jq_raw '.review.html_url')"
    case "$state" in
      approved)          title="✅ PR #$number approved"; color=5763719 ;;
      changes_requested) title="🛠️ Changes requested on PR #$number"; color=16750848 ;;
      *)                 title="💬 Review submitted on PR #$number" ;;
    esac
    description="$(jq -r '(.review.body // "")[0:1800]' "$event_path")"
    context="#$number"
    ;;

  pull_request_review_comment)
    number="$(jq_raw '.pull_request.number')"
    title="💬 Review comment on PR #$number"
    url="$(jq_raw '.comment.html_url')"
    description="$(jq -r '(.comment.body // "")[0:1800]' "$event_path")"
    context="#$number"
    ;;

  commit_comment)
    sha="$(jq_raw '.comment.commit_id')"
    short="${sha:0:7}"
    title="💬 Comment on commit $short"
    url="$(jq_raw '.comment.html_url')"
    description="$(jq -r '(.comment.body // "")[0:1800]' "$event_path")"
    context="$short"
    ;;

  create)
    ref_type="$(jq_raw '.ref_type')"
    ref="$(jq_raw '.ref')"
    title="➕ ${ref_type^} created: $ref"
    context="$ref"
    ;;

  delete)
    ref_type="$(jq_raw '.ref_type')"
    ref="$(jq_raw '.ref')"
    title="➖ ${ref_type^} deleted: $ref"
    context="$ref"
    color=9807270
    ;;

  discussion)
    number="$(jq_raw '.discussion.number')"
    discussion_title="$(jq_raw '.discussion.title')"
    url="$(jq_raw '.discussion.html_url')"
    case "$action" in
      created)  title="💬 Discussion #$number created" ;;
      answered) title="✅ Discussion #$number answered"; color=5763719 ;;
      closed)   title="✅ Discussion #$number closed"; color=5763719 ;;
      reopened) title="💬 Discussion #$number reopened" ;;
      *)        title="💬 Discussion #$number ${action:-changed}" ;;
    esac
    description="$discussion_title"
    context="#$number"
    ;;

  discussion_comment)
    number="$(jq_raw '.discussion.number')"
    title="💬 Comment on discussion #$number"
    url="$(jq_raw '.comment.html_url')"
    description="$(jq -r '(.comment.body // "")[0:1800]' "$event_path")"
    context="#$number"
    ;;

  *)
    exit 0
    ;;
esac

[[ -n "$title" ]] || exit 0
[[ -n "$url" ]] || url="https://github.com/$repo"

jq -cn   --arg title "$title"   --arg url "$url"   --arg description "$description"   --arg repo "$repo"   --arg actor "${actor:-unknown}"   --arg context "$context"   --argjson color "$color"   '{
    embeds: [{
      title: $title,
      url: $url,
      description: $description,
      color: $color,
      fields: (
        [
          {name: "Repository", value: $repo, inline: true},
          {name: "Actor", value: $actor, inline: true}
        ] +
        (if $context == "" then [] else [{name: "Context", value: $context, inline: true}] end)
      ),
      footer: {text: "Gryt Git"},
      timestamp: (now | todate)
    }]
  }'
