#!/usr/bin/env bash
# Orchestrator script for the complete bug triage pipeline.
# Called by the bug-triage-workflow skill.
# Usage: ./scripts/run-pipeline.sh [--limit N] [--bugs-only] [--since DATE] [--until DATE] [--dry-run] [--epic-key KEY]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

LIMIT="20"
BUGS_ONLY=""
SINCE=""
UNTIL=""
DRY_RUN="false"
EPIC_KEY=""
ISSUE_DIR="scripts/testdata/issues/lxd-real"
TEMP_DIR="/tmp/opencode/triage-pipeline"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
Usage:
  $0 [OPTIONS]

Options:
  --limit N          Number of issues to fetch (default: 20)
  --bugs-only        Only fetch bug-labeled issues
  --since YYYY-MM-DD Fetch issues created after this date
  --until YYYY-MM-DD Fetch issues created before this date
  --dry-run          Run analysis but don't create Jira issues
  --epic-key KEY     Jira Epic key to link bugs to (required unless --dry-run)
  --help, -h         Show this help

Examples:
  $0 --limit 10 --dry-run
  $0 --bugs-only --epic-key LXD-200
  $0 --limit 5 --since 2026-05-01 --epic-key LXD-100
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit)     LIMIT="$2"; shift 2 ;;
    --bugs-only) BUGS_ONLY="--bugs-only"; shift ;;
    --since)     SINCE="--since $2"; shift 2 ;;
    --until)     UNTIL="--until $2"; shift 2 ;;
    --dry-run)   DRY_RUN="true"; shift ;;
    --epic-key)  EPIC_KEY="$2"; shift 2 ;;
    --help|-h)   usage; exit 0 ;;
    *) echo "Error: Unknown argument '$1'" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ "$DRY_RUN" != "true" && -z "$EPIC_KEY" ]]; then
  echo "Error: --epic-key is required unless --dry-run is specified" >&2
  usage >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

mkdir -p "$TEMP_DIR"
rm -f "$TEMP_DIR"/*.json

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          AI Bug Triage Pipeline                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Limit: $LIMIT"
echo "  Bugs only: ${BUGS_ONLY:-no}"
echo "  Date range: ${SINCE:-any} to ${UNTIL:-any}"
echo "  Dry run: $DRY_RUN"
echo "  Epic key: ${EPIC_KEY:-N/A}"
echo ""

# ---------------------------------------------------------------------------
# Step 1: Fetch issues from GitHub
# ---------------------------------------------------------------------------

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📥 STEP 1: Fetching issues from GitHub"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

./scripts/fetch-lxd-issues.sh \
  --limit "$LIMIT" \
  --out-dir "$ISSUE_DIR" \
  $BUGS_ONLY \
  $SINCE \
  $UNTIL

ISSUE_FILES=($(ls "$ISSUE_DIR"/*.json 2>/dev/null || true))
ISSUE_COUNT=${#ISSUE_FILES[@]}

if [[ $ISSUE_COUNT -eq 0 ]]; then
  echo ""
  echo "❌ No issues found. Try adjusting filters."
  exit 0
fi

echo ""
echo "✓ Fetched $ISSUE_COUNT issues"
echo ""

# ---------------------------------------------------------------------------
# Step 2-4: Process each issue through the agent pipeline
# ---------------------------------------------------------------------------

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🤖 STEP 2-4: Processing issues through AI agent pipeline"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "NOTE: In OpenCode skill mode, agents are invoked via Task tool"
echo "      This script saves agent output JSONs for Jira creation"
echo ""
echo "Expected agent outputs will be saved to:"
echo "  - $TEMP_DIR/agent1-<id>.json (unified-triage)"
echo "  - $TEMP_DIR/agent2-<id>.json (jira-decision-gate)"
echo "  - $TEMP_DIR/agent3-<id>.json (jira-writer)"
echo ""
echo "Agent pipeline must be executed by OpenCode skill."
echo "This script handles pre/post processing only."
echo ""

# Create a manifest file for the skill to process
MANIFEST="$TEMP_DIR/issues-manifest.json"
jq -n \
  --arg dir "$ISSUE_DIR" \
  --argjson files "$(printf '%s\n' "${ISSUE_FILES[@]}" | jq -R . | jq -s .)" \
  '{
    issue_dir: $dir,
    issue_files: $files,
    total_count: ($files | length)
  }' > "$MANIFEST"

echo "✓ Created issue manifest: $MANIFEST"
echo ""
echo "⚠️  SKILL ORCHESTRATION REQUIRED:"
echo "   The OpenCode skill should now:"
echo "   1. Read manifest from $MANIFEST"
echo "   2. For each issue file, run agents 1→2→3"
echo "   3. Save outputs to $TEMP_DIR/agent{1,2,3}-<id>.json"
echo "   4. Continue to Step 5 (Jira creation)"
echo ""

# ---------------------------------------------------------------------------
# Step 5: Create Jira issues (executed after agent outputs are ready)
# ---------------------------------------------------------------------------

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 STEP 5: Creating Jira issues"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# This section will be executed by the skill after agents complete
# For now, create a helper script that can be called

cat > "$TEMP_DIR/create-jira-issues.sh" <<'JIRA_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

TEMP_DIR="/tmp/opencode/triage-pipeline"
DRY_RUN="$1"
EPIC_KEY="${2:-}"

cd /project/git/bug-triaging-dev

CREATED=0
SKIPPED=0

for payload in "$TEMP_DIR"/agent3-*.json; do
  [[ -f "$payload" ]] || continue
  
  ISSUE_ID=$(basename "$payload" | sed 's/agent3-\(.*\)\.json/\1/')
  MODE=$(jq -r '.mode // "skip"' "$payload")
  
  if [[ "$MODE" != "create" ]]; then
    SKIP_REASON=$(jq -r '.skip_reason // "unknown"' "$payload")
    echo "  ⊘ Issue $ISSUE_ID: $SKIP_REASON"
    ((SKIPPED++))
    continue
  fi
  
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  ○ Issue $ISSUE_ID: Would create (DRY RUN)"
    ((CREATED++))
  else
    echo "  ⟳ Issue $ISSUE_ID: Creating in Jira..."
    if ./scripts/jira-create-issue.sh --payload "$payload" --epic-key "$EPIC_KEY" --confirm; then
      echo "  ✓ Issue $ISSUE_ID: Created successfully"
      ((CREATED++))
    else
      echo "  ✗ Issue $ISSUE_ID: Failed to create"
      ((SKIPPED++))
    fi
  fi
done

echo ""
echo "Jira creation summary:"
echo "  Created: $CREATED"
echo "  Skipped: $SKIPPED"
echo ""

echo "$CREATED" > "$TEMP_DIR/created-count.txt"
echo "$SKIPPED" > "$TEMP_DIR/skipped-count.txt"
JIRA_SCRIPT

chmod +x "$TEMP_DIR/create-jira-issues.sh"

echo "✓ Jira creation script ready: $TEMP_DIR/create-jira-issues.sh"
echo "  (Will be executed by skill after agent processing)"
echo ""

# ---------------------------------------------------------------------------
# Step 6: Generate summary report (template)
# ---------------------------------------------------------------------------

cat > "$TEMP_DIR/generate-report.sh" <<'REPORT_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

TEMP_DIR="/tmp/opencode/triage-pipeline"

# Collect statistics from agent outputs
TOTAL=$(ls "$TEMP_DIR"/agent1-*.json 2>/dev/null | wc -l)
CREATED=$(cat "$TEMP_DIR/created-count.txt" 2>/dev/null || echo "0")
SKIPPED=$(cat "$TEMP_DIR/skipped-count.txt" 2>/dev/null || echo "0")

# Component distribution
COMPONENTS=$(jq -r '.classification.component' "$TEMP_DIR"/agent1-*.json 2>/dev/null | sort | uniq -c | sort -rn)

# Severity distribution  
SEVERITIES=$(jq -r '.severity.score' "$TEMP_DIR"/agent1-*.json 2>/dev/null | sort -rn | uniq -c)

# Priority distribution
PRIORITIES=$(jq -r '.priority.level' "$TEMP_DIR"/agent1-*.json 2>/dev/null | sort | uniq -c)

# Top issues by rank score
TOP_ISSUES=$(
  for f in "$TEMP_DIR"/agent2-*.json; do
    [[ -f "$f" ]] || continue
    ISSUE_ID=$(basename "$f" | sed 's/agent2-\(.*\)\.json/\1/')
    RANK_SCORE=$(jq -r '.ranking.rank_score' "$f")
    PRIORITY=$(jq -r '.ranking.priority_norm' "$f")
    echo "$RANK_SCORE|$ISSUE_ID|$PRIORITY"
  done | sort -t'|' -k1 -rn | head -5
)

cat <<EOF

╔════════════════════════════════════════════════════════════╗
║          Bug Triage Workflow Complete                      ║
╚════════════════════════════════════════════════════════════╝

📊 Summary:
   Total issues processed: $TOTAL
   Jira created: $CREATED
   Skipped/Need info: $SKIPPED

🏷️  Component Distribution:
$COMPONENTS

📊 Severity Distribution:
$SEVERITIES

🎯 Priority Distribution:
$PRIORITIES

📋 Top Priority Issues (by rank_score):
EOF

RANK=1
while IFS='|' read -r score id priority; do
  TITLE=$(jq -r 'select(.issue_id=="'"$id"'") | .classification.component' "$TEMP_DIR"/agent1-*.json 2>/dev/null | head -1)
  PRIORITY_LEVEL=$(jq -r 'select(.issue_id=="'"$id"'") | .priority.level' "$TEMP_DIR"/agent1-*.json 2>/dev/null | head -1)
  echo "   $RANK. #$id - [$PRIORITY_LEVEL, score: $score]"
  ((RANK++))
done <<< "$TOP_ISSUES"

echo ""
echo "✅ Pipeline complete!"
echo ""
REPORT_SCRIPT

chmod +x "$TEMP_DIR/generate-report.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 STEP 6: Report generation script ready"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✓ Report script: $TEMP_DIR/generate-report.sh"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Pipeline preparation complete!"
echo ""
echo "Next steps (executed by OpenCode skill):"
echo "  1. Process each issue through agents 1→2→3"
echo "  2. Run: $TEMP_DIR/create-jira-issues.sh $DRY_RUN ${EPIC_KEY:-}"
echo "  3. Run: $TEMP_DIR/generate-report.sh"
echo "════════════════════════════════════════════════════════════"
echo ""
