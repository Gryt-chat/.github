# A Discord webhook payload in, the same message as a Gryt webhook payload out.
# Gryt refuses empty strings and nulls where Discord shrugs, so those are dropped rather than sent.

def nonblank: if type == "string" and test("\\S") then . else null end;
def compact: with_entries(select(.value != null));

def card:
  {
    title: (.title | nonblank),
    url: (.url | nonblank),
    description: (.description | nonblank),
    color: (.color | if type == "number" then . else null end),
    author: (.author
      | if type == "object" and (.name | nonblank) != null
        then { name, url: (.url | nonblank), icon_url: (.icon_url | nonblank) } | compact
        else null end),
    fields: ([.fields[]?
        | select((.name | nonblank) != null and (.value | nonblank) != null)
        | { name, value, inline: (.inline == true) }]
      | if length > 0 then . else null end),
    image_url: (.image.url? | nonblank),
    thumbnail_url: (.thumbnail.url? | nonblank),
    footer: (.footer
      | if type == "object" and (.text | nonblank) != null
        then { text, icon_url: (.icon_url | nonblank) } | compact
        else null end),
    timestamp: (.timestamp | nonblank)
  }
  | compact;

{
  text: (.content | nonblank),
  display_name: (.username | nonblank),
  avatar_url: (.avatar_url | nonblank),
  cards: ([.embeds[]? | card | select(.title or .description or .fields or .image_url or .author)]
    | if length > 0 then . else null end)
}
| compact
