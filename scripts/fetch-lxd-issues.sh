#!/usr/bin/env bash
set -euo pipefail

# Fetch LXD issues from GitHub and normalize them to local JSON test fixtures.
# Requirements: gh, jq

REPO="canonical/lxd"
STATE="open"
LIMIT="20"
OUT_DIR="testdata/issues/lxd-real"
LABEL=""
SINCE=""
UNTIL=""
BUGS_ONLY="false"

usage() {
  cat <<EOF
Usage:
  $0 [--limit N] [--out-dir DIR] [--label LABEL] [--state open|closed|all] [--since YYYY-MM-DD] [--until YYYY-MM-DD] [--bugs-only] [--repo OWNER/REPO]

Examples:
  $0 --limit 50 --out-dir testdata/issues/lxd-may --since 2026-05-01 --until 2026-05-13 --bugs-only
  $0 --label kind/bug --state all
EOF
}

# Flag parser.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    --label)
      LABEL="$2"
      shift 2
      ;;
    --state)
      STATE="$2"
      shift 2
      ;;
    --since)
      SINCE="$2"
      shift 2
      ;;
    --until)
      UNTIL="$2"
      shift 2
      ;;
    --bugs-only)
      BUGS_ONLY="true"
      shift
      ;;
    --repo)
      REPO="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI not found. Install it with: sudo apt install -y gh" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq not found. Install it with: sudo apt install -y jq" >&2
  exit 1
fi

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  echo "Error: limit must be an integer, got '$LIMIT'" >&2
  exit 1
fi

if [[ "$STATE" != "open" && "$STATE" != "closed" && "$STATE" != "all" ]]; then
  echo "Error: state must be one of open|closed|all" >&2
  exit 1
fi

since_ts=""
until_ts=""
if [[ -n "$SINCE" ]]; then
  since_ts="${SINCE}T00:00:00Z"
fi
if [[ -n "$UNTIL" ]]; then
  until_ts="${UNTIL}T23:59:59Z"
fi

mkdir -p "$OUT_DIR"

echo "Fetching up to $LIMIT issues from $REPO"
echo "  state=$STATE label=${LABEL:-<none>} bugs_only=$BUGS_ONLY since=${SINCE:-<none>} until=${UNTIL:-<none>}"

# Pull a wider candidate set, then filter locally.
SOURCE_LIMIT="$LIMIT"
if (( SOURCE_LIMIT < 200 )); then
  SOURCE_LIMIT=200
fi

# Get issue numbers first to keep the flow simple and robust.
LIST_JSON=$(gh issue list \
  -R "$REPO" \
  --state "$STATE" \
  --limit "$SOURCE_LIMIT" \
  --json number,labels,createdAt)

ISSUE_NUMBERS=$(jq -r \
  --arg label "$LABEL" \
  --arg since "$since_ts" \
  --arg until "$until_ts" \
  --arg bugsOnly "$BUGS_ONLY" '
    .[]
    | select(($label == "") or (any(.labels[]?.name; . == $label)))
    | select(($bugsOnly != "true") or (any(.labels[]?.name; test("bug"; "i"))))
    | select(($since == "") or (.createdAt >= $since))
    | select(($until == "") or (.createdAt <= $until))
    | .number
  ' <<< "$LIST_JSON" | head -n "$LIMIT")

if [[ -z "$ISSUE_NUMBERS" ]]; then
  echo "No issues found for the current filters." >&2
  echo "Try one of these:" >&2
  echo "  - remove --label" >&2
  echo "  - remove --bugs-only" >&2
  echo "  - widen --since/--until" >&2
  exit 0
fi

count=0
for n in $ISSUE_NUMBERS; do
  out="$OUT_DIR/$n.json"
  echo "- Downloading issue #$n -> $out"

  gh issue view "$n" \
    -R "$REPO" \
    --json number,title,body,labels,comments,url,createdAt,updatedAt,author \
    | jq '{
        id: (.number|tostring),
        title: .title,
        description: (.body // ""),
        author: (.author.login // "unknown"),
        labels: [(.labels[]?.name)],
        comments: [(.comments[]? | {author: (.author.login // "unknown"), body: (.body // ""), created_at: (.createdAt // "")})],
        created_at: (.createdAt // ""),
        updated_at: (.updatedAt // ""),
        source_url: (.url // "")
      }' > "$out"

  count=$((count + 1))
done

echo "Done. Saved $count issue files in $OUT_DIR"
