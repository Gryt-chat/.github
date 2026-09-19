#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export RELEASE_BODY=$'Gryt v1.2.3\n\nChannel: beta\n\n## What changed since v1.2.2\n\n### Client\n\n* Fix voice reconnect in https://github.com/Gryt-chat/client/pull/1\n* Keep dialogs in the viewport in https://github.com/Gryt-chat/ui/pull/2\n* Fix microphone acquisition in https://github.com/Gryt-chat/voice/pull/3\n* Improve release cards in https://github.com/Gryt-chat/gryt/pull/4\n* This fifth item must not appear\n\n**Full changelogs**\n\n* Client: compare-url'

payload="$(bash "$here/build-payloads.sh" Client 1.2.3-beta.1 beta Gryt-chat/gryt v1.2.3-beta.1 https://github.com/Gryt-chat/gryt/releases/tag/v1.2.3-beta.1 "" "")"

jq -e '.gryt.display_name == "Gryt Releases"' <<<"$payload" >/dev/null
jq -e '.gryt.cards[0].title == "Client v1.2.3-beta.1"' <<<"$payload" >/dev/null
jq -e '.gryt.cards[0].color == "#f5a524"' <<<"$payload" >/dev/null
jq -e '.gryt.cards[0].description | contains("**Highlights**")' <<<"$payload" >/dev/null
jq -e '.gryt.cards[0].description | contains("Fix voice reconnect")' <<<"$payload" >/dev/null
jq -e '.gryt.cards[0].description | contains("This fifth item") | not' <<<"$payload" >/dev/null
jq -e '.gryt.cards[0].fields | length == 3' <<<"$payload" >/dev/null
jq -e '.discord.embeds[0].description == .gryt.cards[0].description' <<<"$payload" >/dev/null

echo "release-notify payload tests passed"
