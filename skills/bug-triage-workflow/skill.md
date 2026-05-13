---
name: bug-triage-workflow
description: Complete bug triage workflow from GitHub issues to prioritized Jira backlog
trigger: /triage-bugs
---

# Bug Triage Workflow Skill

This skill orchestrates the complete bug triage pipeline from GitHub issue ingestion to Jira backlog creation with automated prioritization.

## What This Skill Does

Executes a complete AI-powered bug triage workflow:

1. **Fetch issues** from GitHub using the gh CLI
2. **Classify & score** each issue using the `unified-triage` agent
3. **Apply policy gates** using the `jira-decision-gate` agent
4. **Generate Jira payloads** using the `jira-writer` agent
5. **Create Jira issues** with automated ranking
6. **Generate summary report** with prioritized backlog view

## Usage

```
/triage-bugs [--limit N] [--bugs-only] [--since YYYY-MM-DD] [--until YYYY-MM-DD] [--dry-run] [--epic-key KEY]
```

### Options

- `--limit N`: Number of issues to fetch (default: 20)
- `--bugs-only`: Only fetch issues labeled as bugs
- `--since YYYY-MM-DD`: Fetch issues created after this date
- `--until YYYY-MM-DD`: Fetch issues created before this date
- `--dry-run`: Run analysis but don't create Jira issues
- `--epic-key KEY`: Jira Epic key to link bugs to (e.g., LXD-100)

### Examples

```
/triage-bugs --limit 10 --dry-run
/triage-bugs --bugs-only --since 2026-05-01 --epic-key LXD-200
/triage-bugs --limit 5 --until 2026-05-13
```

## Workflow Steps

### Step 1: Fetch Issues from GitHub

Run `scripts/fetch-lxd-issues.sh` with the specified parameters to download issues from canonical/lxd repository.

Expected output: JSON files in `scripts/testdata/issues/lxd-real/`

### Step 2: Triage Each Issue (Agent 1)

For each issue JSON file:
- Launch the `unified-triage` agent via Task tool
- Agent analyzes the issue and LXD source code
- Returns JSON with:
  - Component classification
  - Severity score (1-10)
  - Priority level (P0-P4)
  - Readiness assessment

### Step 3: Policy Gate Decision (Agent 2)

For each triage result:
- Launch the `jira-decision-gate` agent
- Agent applies policy rules:
  - Check if issue is complete enough
  - Determine if Jira creation is required
  - Calculate ranking score for backlog ordering
- Returns JSON with eligibility decision and rank score

### Step 4: Generate Jira Payload (Agent 3)

For issues where `jira_required = true`:
- Launch the `jira-writer` agent
- Agent generates properly formatted Jira payload
- Returns JSON ready for Jira API

### Step 5: Create Jira Issues

For each "create" mode payload:
- Run `scripts/jira-create-issue.sh`
- Script handles idempotency (won't create duplicates)
- Links to specified Epic if provided

### Step 6: Generate Report

Collect results from all steps and display:
- Total issues processed
- Classification breakdown by component
- Severity distribution
- Priority distribution
- Jira creation summary
- Top priority issues ranked by score

## Output Format

The skill produces a structured report like:

```
=== Bug Triage Workflow Complete ===

📊 Summary:
   Total issues processed: 20
   Jira-eligible: 15
   Jira created: 12
   Need more info: 8

🏷️  Component Distribution:
   storage: 4
   networking: 3
   compute: 5
   clustering: 2
   auth: 1

🎯 Severity Distribution:
   P1 (Critical): 4
   P2 (High): 5
   P3 (Medium): 3

📋 Top Priority Issues (by rank_score):
   1. #18066 - Network ACL security bypass [P1, score: 0.87] → LXD-301
   2. #18205 - Replicator fails second run [P1, score: 0.85] → LXD-302
   3. #18194 - DevLXD socket removed on snap refresh [P1, score: 0.83] → LXD-303
   4. #18150 - LVM storage usage overreporting [P1, score: 0.81] → LXD-304
   5. #18119 - CentOS VM unreachable after snapd [P2, score: 0.71] → LXD-305

✅ Jira backlog ready: https://your-jira.atlassian.net/jira/software/projects/LXD/boards/1/backlog
```

## Implementation Instructions

When the user invokes this skill:

1. **Parse arguments** from the user's command
2. **Run fetch script**:
   ```bash
   cd /project/git/bug-triaging-dev
   ./scripts/fetch-lxd-issues.sh --limit <N> [--bugs-only] [--since <date>] [--until <date>]
   ```

3. **Get list of downloaded issues**:
   ```bash
   ls scripts/testdata/issues/lxd-real/*.json
   ```

4. **For each issue file**, execute the agent pipeline:
   
   a. **Launch Agent 1** (unified-triage):
   ```
   Use Task tool with subagent_type="general"
   Command: /agent unified-triage
   Prompt: Read issue from <file>, analyze against /project/git/lxd, return JSON
   ```
   
   b. **Launch Agent 2** (jira-decision-gate):
   ```
   Use Task tool with subagent_type="general"
   Command: /agent jira-decision-gate
   Prompt: Process the triage JSON from Agent 1, apply policy gates, return JSON
   ```
   
   c. **Launch Agent 3** (jira-writer):
   ```
   Use Task tool with subagent_type="general"
   Command: /agent jira-writer
   Prompt: Generate Jira payload from Agent 1 + Agent 2 outputs, return JSON
   ```
   
   d. **Save Agent 3 output** to temporary file:
   ```bash
   echo '<json>' > /tmp/opencode/jira-payload-<issue_id>.json
   ```

5. **Create Jira issues** (if not --dry-run):
   ```bash
   for payload in /tmp/opencode/jira-payload-*.json; do
     if [[ "$(jq -r '.mode' $payload)" == "create" ]]; then
       ./scripts/jira-create-issue.sh --payload $payload --epic-key <KEY> --confirm
     fi
   done
   ```

6. **Collect statistics**:
   - Count total issues processed
   - Group by component, severity, priority
   - Sort by rank_score descending
   - Format summary report

7. **Display results** to user in the format shown above

## Error Handling

- If `scripts/fetch-lxd-issues.sh` fails: Show error, suggest checking gh auth
- If agent fails: Log the issue ID, continue with next issue
- If Jira creation fails: Show dry-run payload, suggest manual review
- If no issues eligible for Jira: Explain why (missing info, low severity, etc.)

## Dependencies

Required tools (check before running):
- `gh` CLI (authenticated)
- `jq`
- `curl`
- LXD repository at `/project/git/lxd`
- Jira credentials configured (via `scripts/jira-auth.sh`)

## Success Criteria

The workflow is successful when:
- ✅ All issues are processed by the 3-agent pipeline
- ✅ Eligible issues are created in Jira with correct priority
- ✅ Jira backlog shows issues ordered by rank_score (highest first)
- ✅ Each Jira issue has proper labels, component, and linking to source GitHub issue
- ✅ Summary report clearly shows what was triaged and created

## Notes for Demo/Video

When demonstrating this skill:

1. **Start with clean state**: Show empty or existing Jira backlog
2. **Run the command**: `/triage-bugs --limit 10 --epic-key LXD-100`
3. **Watch the progress**: Agents running in sequence
4. **Show the results**: Open Jira backlog, verify issues are there and properly ranked
5. **Highlight automation**: "From 10 GitHub bugs to prioritized Jira backlog in one command"
6. **Show agent outputs**: Open one of the saved JSON files to show technical analysis depth

## Troubleshooting

**Issue: No issues fetched**
- Check GitHub authentication: `gh auth status`
- Verify filters aren't too restrictive
- Try without `--bugs-only` or widen date range

**Issue: Agent fails**
- Check LXD repo exists at `/project/git/lxd`
- Verify agent definitions in `agents/*/agent.md`
- Try running single agent manually to debug

**Issue: Jira creation fails**
- Run `scripts/jira-auth.sh` to configure credentials
- Check Epic key exists in your Jira project
- Try with `--dry-run` first to verify payloads

**Issue: Issues not ranked in Jira**
- Verify `rank_score` is being calculated by Agent 2
- Check if Jira custom fields are configured
- Create a Jira filter sorted by `rank_score` field
