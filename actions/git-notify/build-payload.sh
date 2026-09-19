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
repo_url="$(jq_raw '.repository.html_url')"
[[ -n "$repo_url" ]] || repo_url="https://github.com/$repo"

title=""
url="$repo_url"
description=""
context=""
event_label="Git activity"
color="#968ff8"

case "$event_name" in
  push)
    ref="$(jq_raw '.ref')"
    created="$(jq -r '.created // false' "$event_path")"
    deleted="$(jq -r '.deleted // false' "$event_path")"
    [[ "$created" != "true" && "$deleted" != "true" && "$ref" == refs/heads/* ]] || exit 0
    branch="${ref#refs/heads/}"
    count="$(jq '.commits | length' "$event_path")"
    if [[ "$count" -eq 1 ]]; then
      title="1 commit pushed to $branch"
    elif [[ "$count" -gt 1 ]]; then
      title="$count commits pushed to $branch"
    else
      title="$branch updated"
    fi
    url="$(jq_raw '.compare')"
    [[ -n "$url" ]] || url="$repo_url"
    description="$(jq -r --arg repo_url "$repo_url" '
      [.commits[:6][] |
        ("- [" + (.id[0:7]) + "](" + $repo_url + "/commit/" + .id + ") " +
         ((.message // "") | split("\n")[0]) + " — " +
         (.author.username // .author.name // "unknown"))
      ] | join("\n") | .[0:1800]
    ' "$event_path")"
    context="$branch"
    event_label="Push"
    ;;

  pull_request|pull_request_target)
    number="$(jq_raw '.pull_request.number')"
    pr_title="$(jq_raw '.pull_request.title')"
    url="$(jq_raw '.pull_request.html_url')"
    merged="$(jq -r '.pull_request.merged // false' "$event_path")"
    case "$action" in
      opened)             title="PR #$number opened" ;;
      reopened)           title="PR #$number reopened" ;;
      synchronize)        title="PR #$number updated" ;;
      ready_for_review)   title="PR #$number ready for review" ;;
      converted_to_draft) title="PR #$number converted to draft" ;;
      review_requested)   title="Review requested on PR #$number" ;;
      closed)
        if [[ "$merged" == "true" ]]; then
          title="PR #$number merged"
          color="#3fb27f"
        else
          title="PR #$number closed"
          color="#e5484d"
        fi
        ;;
      *) title="PR #$number ${action:-changed}" ;;
    esac
    body="$(jq -r '(.pull_request.body // "")[0:900]' "$event_path")"
    description="**$pr_title**"
    [[ -z "$body" ]] || description="$description"$'\n\n'"$body"
    context="$(jq -r '.pull_request.base.ref + " ← " + .pull_request.head.ref' "$event_path")"
    event_label="Pull request"
    ;;

  issues)
    number="$(jq_raw '.issue.number')"
    issue_title="$(jq_raw '.issue.title')"
    url="$(jq_raw '.issue.html_url')"
    case "$action" in
      opened)     title="Issue #$number opened" ;;
      reopened)   title="Issue #$number reopened" ;;
      closed)     title="Issue #$number closed"; color="#3fb27f" ;;
      labeled)    title="Issue #$number labeled" ;;
      unlabeled)  title="Issue #$number unlabeled" ;;
      assigned)   title="Issue #$number assigned" ;;
      unassigned) title="Issue #$number unassigned" ;;
      *) title="Issue #$number ${action:-changed}" ;;
    esac
    body="$(jq -r '(.issue.body // "")[0:900]' "$event_path")"
    description="**$issue_title**"
    [[ -z "$body" ]] || description="$description"$'\n\n'"$body"
    context="#$number"
    event_label="Issue"
    ;;

  issue_comment)
    number="$(jq_raw '.issue.number')"
    url="$(jq_raw '.comment.html_url')"
    if jq -e '.issue.pull_request != null' "$event_path" >/dev/null; then
      title="Comment on PR #$number"
      event_label="Pull request comment"
    else
      title="Comment on issue #$number"
      event_label="Issue comment"
    fi
    description="$(jq -r '(.comment.body // "")[0:1800]' "$event_path")"
    context="#$number"
    ;;

  pull_request_review)
    number="$(jq_raw '.pull_request.number')"
    state="$(jq_raw '.review.state')"
    url="$(jq_raw '.review.html_url')"
    case "$state" in
      approved)          title="PR #$number approved"; color="#3fb27f" ;;
      changes_requested) title="Changes requested on PR #$number"; color="#f5a524" ;;
      *)                 title="Review submitted on PR #$number" ;;
    esac
    description="$(jq -r '(.review.body // "")[0:1800]' "$event_path")"
    context="#$number"
    event_label="Pull request review"
    ;;

  pull_request_review_comment)
    number="$(jq_raw '.pull_request.number')"
    title="Review comment on PR #$number"
    url="$(jq_raw '.comment.html_url')"
    description="$(jq -r '(.comment.body // "")[0:1800]' "$event_path")"
    context="#$number"
    event_label="Review comment"
    ;;

  commit_comment)
    sha="$(jq_raw '.comment.commit_id')"
    short="${sha:0:7}"
    title="Comment on commit $short"
    url="$(jq_raw '.comment.html_url')"
    description="$(jq -r '(.comment.body // "")[0:1800]' "$event_path")"
    context="$short"
    event_label="Commit comment"
    ;;

  create)
    ref_type="$(jq_raw '.ref_type')"
    ref="$(jq_raw '.ref')"
    title="${ref_type^} created: $ref"
    context="$ref"
    event_label="Create"
    ;;

  delete)
    ref_type="$(jq_raw '.ref_type')"
    ref="$(jq_raw '.ref')"
    title="${ref_type^} deleted: $ref"
    context="$ref"
    event_label="Delete"
    color="#e5484d"
    ;;

  discussion)
    number="$(jq_raw '.discussion.number')"
    discussion_title="$(jq_raw '.discussion.title')"
    url="$(jq_raw '.discussion.html_url')"
    case "$action" in
      created)  title="Discussion #$number created" ;;
      answered) title="Discussion #$number answered"; color="#3fb27f" ;;
      closed)   title="Discussion #$number closed"; color="#3fb27f" ;;
      reopened) title="Discussion #$number reopened" ;;
      *)        title="Discussion #$number ${action:-changed}" ;;
    esac
    description="**$discussion_title**"
    context="#$number"
    event_label="Discussion"
    ;;

  discussion_comment)
    number="$(jq_raw '.discussion.number')"
    title="Comment on discussion #$number"
    url="$(jq_raw '.comment.html_url')"
    description="$(jq -r '(.comment.body // "")[0:1800]' "$event_path")"
    context="#$number"
    event_label="Discussion comment"
    ;;

  *)
    exit 0
    ;;
esac

[[ -n "$title" ]] || exit 0
[[ -n "$url" ]] || url="$repo_url"

actor_value="${actor:-unknown}"
if [[ -n "$actor" ]]; then
  actor_value="[@$actor](https://github.com/$actor)"
fi

jq -cn   --arg title "$title"   --arg url "$url"   --arg description "$description"   --arg repo "$repo"   --arg repo_url "$repo_url"   --arg actor "$actor_value"   --arg context "$context"   --arg event_label "$event_label"   --arg color "$color"   '{
    display_name: "GitHub",
    cards: [
      ({
        author: {name: $repo, url: $repo_url},
        title: $title,
        url: $url,
        description: (if $description == "" then null else $description end),
        color: $color,
        fields: (
          [{name: "Actor", value: $actor, inline: true}] +
          (if $context == "" then [] else [{name: "Context", value: $context, inline: true}] end)
        ),
        footer: {text: ("GitHub · " + $event_label)},
        timestamp: (now | todate)
      } | with_entries(select(.value != null)))
    ]
  }'
