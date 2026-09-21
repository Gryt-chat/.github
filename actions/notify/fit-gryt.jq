# Cuts a Gryt webhook payload to the server's limits, since one field over them loses the whole message.
# Counted in UTF-16 units after trimming, never fewer than zod's code points. Blank strings are dropped.

def u16: explode | map(if . > 65535 then 2 else 1 end) | add // 0;
def trim: sub("^[\\s\\x{FEFF}]+"; "") | sub("[\\s\\x{FEFF}]+$"; "");
def cut($n):
  trim
  | if u16 <= $n then .
    else [foreach explode[] as $c (0; . + (if $c > 65535 then 2 else 1 end); select(. < $n) | $c)]
      | implode | trim | . + "…"
    end;
def text($n): if type == "string" then cut($n) | if . == "" then null else . end else null end;
def link: if type == "string" and test("^https?://\\S+$") and u16 <= 2048 then . else null end;
def compact: with_entries(select(.value != null));
def items: if type == "array" then .[] | select(type == "object") else empty end;

def card:
  {
    title: (.title | text(256)),
    url: (.url | link),
    description: (.description | text(4000)),
    color: (.color
      | if (type == "string" and test("^#[0-9a-fA-F]{6}$"))
          or (type == "number" and . >= 0 and . <= 16777215 and . == floor)
        then . else null end),
    author: (.author
      | if type == "object" and (.name | text(256))
        then {name: (.name | text(256)), url: (.url | link), icon_url: (.icon_url | link)} | compact
        else null end),
    fields: ([.fields | items
        | {name: (.name | text(256)), value: (.value | text(1024)), inline: (.inline == true)}
        | select(.name and .value)][:25]
      | if length > 0 then . else null end),
    image_url: (.image_url | link),
    thumbnail_url: (.thumbnail_url | link),
    footer: (.footer
      | if type == "object" and (.text | text(2048))
        then {text: (.text | text(2048)), icon_url: (.icon_url | link)} | compact
        else null end),
    timestamp: (.timestamp
      | if type == "string" and test("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[+-]\\d{2}:\\d{2})$")
        then . else null end)
  }
  | compact
  | select(.title or .description or .fields or .image_url or .author);

def size: [.title, .description, .author.name, .footer.text, (.fields[]? | .name, .value)]
  | map(select(type == "string") | u16) | add // 0;

# All cards share 6000 units. Descriptions give way, last card first.
def shared($limit):
  reduce range(length - 1; -1; -1) as $i (.;
    ((map(size) | add // 0) - $limit) as $over
    | if $over > 0 and .[$i].description
      then .[$i].description |= cut([u16 - $over, 1] | max)
      else . end);

{
  text: (.text | text(4000)),
  display_name: (.display_name | if type == "string" and test("\\S") then . else null end),
  avatar_url: (.avatar_url | link),
  cards: ([.cards | items | card][:10] | shared(6000) | if length > 0 then . else null end)
}
| compact
| select(.text or .cards)
