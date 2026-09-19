#!/usr/bin/env bash
set -euo pipefail

component="${1:-}"
version="${2:-}"
channel="${3:-}"
repository="${4:-}"
tag="${5:-}"
release_url="${6:-}"
artifact_label="${7:-}"
artifact_value="${8:-}"
body="${RELEASE_BODY:-}"

if [[ -z "$component" || -z "$version" || -z "$channel" || -z "$repository" || -z "$tag" || -z "$release_url" ]]; then
  echo "release-notify: missing required release metadata" >&2
  exit 1
fi

case "$channel" in
  beta)
    channel_label="Beta"
    color="#f5a524"
    ;;
  latest)
    channel_label="Stable"
    color="#3fb27f"
    ;;
  *)
    channel_label="$channel"
    color="#968ff8"
    ;;
esac

case "$component" in
  Client)
    if [[ "$channel" == "beta" ]]; then
      summary="New desktop build is ready for testing."
    else
      summary="New desktop build is available."
    fi
    ;;
  Server)
    if [[ "$channel" == "beta" ]]; then
      summary="New self-hosted server build is ready for testing."
    else
      summary="New self-hosted server build is available."
    fi
    ;;
  *)
    if [[ "$channel" == "beta" ]]; then
      summary="A new $component beta is ready for testing."
    else
      summary="A new $component release is available."
    fi
    ;;
esac

highlights="$(printf '%s\n' "$body" | awk '
  /^\*\*Full changelogs\*\*/ { exit }
  /^### Checking this download/ { exit }
  /^[*-] / {
    sub(/^[*-] /, "- ")
    print
    count++
    if (count >= 4) exit
  }
')"

description="$summary"
if [[ -n "$highlights" ]]; then
  description="$description"$'\n\n'"**Highlights**"$'\n'"$highlights"
fi
description="$(printf '%s' "$description" | head -c 3000)"

discord_title="$(printf '%s %s release' "$(tr '[:lower:]' '[:upper:]' <<<"$channel_label")" "$component")"

jq -cn   --arg discord_title "$discord_title"   --arg card_title "$component $tag"   --arg release_url "$release_url"   --arg description "$description"   --arg component "$component"   --arg channel "$channel_label"   --arg version "$version"   --arg repository "$repository"   --arg artifact_label "$artifact_label"   --arg artifact_value "$artifact_value"   --arg color "$color"   '{
    discord: {
      embeds: [{
        title: $discord_title,
        url: $release_url,
        description: $description,
        color: (if $color == "#3fb27f" then 4174463 elif $color == "#f5a524" then 16098596 else 9867256 end),
        fields: (
          [
            {name: "Component", value: $component, inline: true},
            {name: "Channel", value: $channel, inline: true},
            {name: "Version", value: $version, inline: true}
          ] +
          (if $artifact_label == "" or $artifact_value == "" then [] else [{name: $artifact_label, value: $artifact_value, inline: false}] end)
        ),
        footer: {text: "Gryt Releases"},
        timestamp: (now | todate)
      }]
    },
    gryt: {
      display_name: "Gryt Releases",
      cards: [{
        author: {name: "Gryt Releases", url: "https://github.com/Gryt-chat"},
        title: $card_title,
        url: $release_url,
        description: $description,
        color: $color,
        fields: (
          [
            {name: "Component", value: $component, inline: true},
            {name: "Channel", value: $channel, inline: true},
            {name: "Version", value: $version, inline: true}
          ] +
          (if $artifact_label == "" or $artifact_value == "" then [] else [{name: $artifact_label, value: $artifact_value, inline: false}] end)
        ),
        footer: {text: ("Gryt Releases · " + $repository)},
        timestamp: (now | todate)
      }]
    }
  }'
