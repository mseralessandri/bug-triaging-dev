# AI-Powered Bug Triage System

**Automated bug triage from GitHub to prioritized Jira backlog using specialized AI agents.**

Transform unstructured GitHub issues into a prioritized Jira backlog in seconds. This system uses three specialized AI agents to analyze, classify, score, and rank bugs automatically.

---

## 🎯 What It Does

This system automatically:

1. ✅ **Fetches** bugs from GitHub (canonical/lxd)
2. 🤖 **Analyzes** each issue using AI agents that read source code
3. 🏷️ **Classifies** component, severity (1-10), and priority (P0-P4)
4. 🚦 **Applies policy gates** to determine Jira eligibility
5. 📝 **Generates** properly formatted Jira tickets
6. 📊 **Ranks** issues by criticality for backlog ordering
7. 🎯 **Creates** Jira issues automatically with proper linking

**Result**: Developers see a prioritized backlog where the first issue is always the most critical.

---

## 🚀 Quick Start (One Command!)

```bash
# In OpenCode, run:
/triage-bugs --limit 10 --epic-key LXD-100
```

That's it! The skill orchestrates everything automatically.

---

## 📁 Repository Structure

```
bug-triaging-dev/
├── agents/                          # AI agent definitions
│   ├── unified-triage/
│   │   └── agent.md                 # Agent 1: Technical analysis
│   ├── jira-decision-gate/
│   │   └── agent.md                 # Agent 2: Policy & ranking
│   └── jira-writer/
│       └── agent.md                 # Agent 3: Jira payload generation
│
├── skills/                          # OpenCode skills
│   └── bug-triage-workflow/
│       └── skill.md                 # Orchestrator skill (ONE COMMAND)
│
├── scripts/
│   ├── fetch-lxd-issues.sh          # GitHub issue fetcher
│   ├── run-pipeline.sh              # Pipeline orchestrator
│   ├── jira-auth.sh                 # Jira authentication setup
│   ├── jira-create-issue.sh         # Jira issue creator (idempotent)
│   └── testdata/issues/lxd-real/    # Downloaded GitHub issues
│
├── TRIAGE_RESULTS.md                # Example triage outputs
├── SAMPLE_OUTPUTS.md                # Agent JSON examples
├── VIDEO_SCRIPT.md                  # Video recording guide
└── README.md                        # This file
```

---

## 🤖 The Three AI Agents

### Agent 1: unified-triage
**Responsibility**: Technical analysis and classification

**What it does**:
- Reads issue description, logs, and comments
- Searches LXD source code at `/project/git/lxd`
- Classifies component (storage, networking, compute, etc.)
- Scores severity using 14 dimensions:
  - Data loss, system stability, accessibility
  - Blocked operations, information integrity
  - Networking, storage, security vulnerabilities
  - Regressions, upgrade issues, system impact
  - Cluster-wide blast radius, workarounds
- Assigns priority (P0-P4)
- Checks issue completeness

**Output**: JSON with classification, severity score, priority, readiness

### Agent 2: jira-decision-gate
**Responsibility**: Policy enforcement and ranking

**What it does**:
- Consumes Agent 1 output (never re-reads raw issue)
- Applies hard eligibility rules:
  - Must have reproducer
  - Must have complete information
- Determines Jira creation requirement:
  - All issues with complete information are created in Jira
- Calculates deterministic rank score:
  - `rank_score = 0.60*severity + 0.30*priority + 0.10*confidence`
- Provides machine-readable blocking reasons if not eligible

**Output**: JSON with eligibility decision, rank score, next steps

### Agent 3: jira-writer
**Responsibility**: Jira payload generation

**What it does**:
- Consumes Agent 1 + Agent 2 outputs
- If `jira_required = false`, returns skip with reason
- If `jira_required = true`, generates complete Jira payload:
  - Summary: Clean title without prefixes
  - Structured description with original GitHub issue + triage analysis table
  - Labels: `lxd`, `triage-bot`, `automated-triage`, `priority-p1`, `severity-7`
  - Links to Epic
  - GitHub link formatted in description with emoji and clickable URL
  - Custom fields: component, severity, priority, rank score

**Output**: JSON with Jira-ready payload (or skip reason)

---

## 🎯 Agent Pipeline Flow

```
GitHub Issue (JSON)
       ↓
┌──────────────────────────────────────┐
│ Agent 1: unified-triage              │
│ - Reads source code                  │
│ - Classifies component               │
│ - Scores severity (14 dimensions)    │
│ - Assigns priority                   │
└──────────────────────────────────────┘
       ↓ (JSON: classification, severity, priority)
┌──────────────────────────────────────┐
│ Agent 2: jira-decision-gate          │
│ - Applies eligibility rules          │
│ - Calculates rank score              │
│ - Decides: create-jira or need-info  │
└──────────────────────────────────────┘
       ↓ (JSON: eligibility, rank_score)
┌──────────────────────────────────────┐
│ Agent 3: jira-writer                 │
│ - Generates Jira payload             │
│ - Formats description                │
│ - Sets labels and custom fields      │
└──────────────────────────────────────┘
       ↓ (JSON: Jira-ready payload)
┌──────────────────────────────────────┐
│ scripts/jira-create-issue.sh         │
│ - Idempotent creation                │
│ - Links to Epic                      │
│ - Returns Jira issue key             │
└──────────────────────────────────────┘
       ↓
   Jira Backlog (ranked by score)
```

---

## 💻 Usage

### Option 1: Full Automated Workflow (Recommended)

```bash
# In OpenCode terminal
/triage-bugs --limit 20 --bugs-only --epic-key LXD-100
```

**What happens**:
1. Fetches 20 bug issues from GitHub
2. Processes each through agents 1→2→3
3. Creates Jira issues for eligible bugs
4. Shows summary report with ranking

### Option 2: Dry Run (Test Without Creating Jira Issues)

```bash
/triage-bugs --limit 10 --dry-run
```

Shows what would be created without actually calling Jira API.

### Option 3: Manual Step-by-Step (For Understanding)

```bash
# 1. Fetch issues
./scripts/fetch-lxd-issues.sh --limit 5 --bugs-only

# 2. Run agents manually (in OpenCode)
/agent unified-triage
# (provide issue JSON, get triage output)

/agent jira-decision-gate  
# (provide triage JSON, get gate decision)

/agent jira-writer
# (provide gate JSON, get Jira payload)

# 3. Create in Jira
./scripts/jira-create-issue.sh --payload output.json --epic-key LXD-100 --confirm
```

### Option 4: Batch Processing Script

```bash
# Process all issues in a directory
./scripts/run-pipeline.sh --limit 50 --epic-key LXD-100
```

---

## 📊 Example Output

### Agent 1 Output (unified-triage)

```json
{
  "issue_id": "18150",
  "classification": {
    "component": "storage",
    "confidence": 0.98,
    "evidence": [
      "lxd/storage/drivers/driver_lvm_utils.go:742"
    ],
    "reasoning": "Bug in LVM driver's thinPoolVolumeUsage() function"
  },
  "severity": {
    "score": 7,
    "confidence": 0.90,
    "dimensions": {
      "data_loss": {"applies": false},
      "information_integrity": {"applies": true, "evidence": "Reports 4.85 TiB vs actual 2.87 TiB"},
      "storage": {"applies": true, "evidence": "Storage pool reporting affected"},
      "no_workaround": {"applies": true}
    }
  },
  "priority": {
    "level": "P1",
    "points": 4,
    "reasoning": "High severity (7) affecting monitoring"
  }
}
```

### Agent 2 Output (jira-decision-gate)

```json
{
  "issue_id": "18150",
  "jira_gate": {
    "jira_eligible": true,
    "jira_required": true,
    "triage_action": "create-jira",
    "blocked_by": []
  },
  "ranking": {
    "rank_score": 0.57,
    "severity_norm": 0.50,
    "priority_norm": 0.40
  }
}
```

### Final Summary Report

```
╔════════════════════════════════════════════════════════════╗
║          Bug Triage Workflow Complete                      ║
╚════════════════════════════════════════════════════════════╝

📊 Summary:
   Total issues processed: 20
   Jira created: 12
   Skipped/Need info: 8

🏷️  Component Distribution:
   compute: 2
   clustering: 2
   Storage: 2
   api-server: 2
   networking: 1
   Images: 1
   Packaging: 1
   projects: 1

🎯 Priority Distribution:
   P1 (High): 3
   P2 (Medium): 5
   P3 (Low): 2
   P4 (Lowest): 2

📋 Top Priority Issues (by rank_score):
   1. #18205 - Replicator fails second run [P1, score: 0.75] → LXD-3918
   2. #18187 - EDK2 NX protection breaks guests [P1, score: 0.75] → LXD-3915
   3. #18194 - DevLXD socket removed on snap refresh [P1, score: 0.74] → LXD-3916
   4. #18204 - Replicator fails remote instances [P2, score: 0.63] → LXD-3917
   5. #18132 - OVN ACL selectors fail cross-host [P2, score: 0.62] → LXD-3911

✅ Jira backlog ready!
```

---

## ⚙️ Configuration

### GitHub Authentication

```bash
gh auth login
# Follow prompts to authenticate
```

### Jira Authentication

```bash
cd /project/git/bug-triaging-dev
./scripts/jira-auth.sh
```

You'll be prompted for:
- Jira base URL (e.g., `https://your-org.atlassian.net`)
- Project key (e.g., `LXD`)
- User email
- API token (generate at https://id.atlassian.com/manage/api-tokens)

Credentials saved to `~/.config/jira/credentials`

---

## 🔧 Advanced Options

### Fetch Options

```bash
./scripts/fetch-lxd-issues.sh \
  --limit 50 \
  --state all \
  --label kind/bug \
  --since 2026-05-01 \
  --until 2026-05-13 \
  --bugs-only \
  --out-dir custom/path
```

### Pipeline Options

```bash
./scripts/run-pipeline.sh \
  --limit 20 \
  --bugs-only \
  --since 2026-05-01 \
  --dry-run \
  --epic-key LXD-100
```

### Skill Options

```
/triage-bugs --limit 10 --bugs-only --since 2026-05-01 --epic-key LXD-100 --dry-run
```

---

## 🐛 Troubleshooting

### "gh CLI not found"
```bash
# Ubuntu/Debian
sudo apt install gh

# macOS
brew install gh
```

### "jq not found"
```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

### "Not authenticated with GitHub"
```bash
gh auth status
gh auth login
```

### "Jira credentials not found"
```bash
./scripts/jira-auth.sh
```

### "No issues fetched"
- Check filters aren't too restrictive
- Try without `--bugs-only`
- Widen date range
- Verify GitHub token has repo access

### "Agent failed"
- Check LXD repo exists at `/project/git/lxd`
- Verify agent definitions in `agents/*/agent.md`
- Try running single agent manually

---

## 📚 Architecture Details

### Why Three Agents?

**Separation of Concerns**:
- **Agent 1**: Technical analysis (reads code, understands bugs)
- **Agent 2**: Business policy (enforces rules, no technical interpretation)
- **Agent 3**: Output formatting (generates Jira payloads)

**Benefits**:
- Each agent has a single responsibility
- Easy to debug (clear JSON contracts)
- Modular (swap agents independently)
- Auditable (see each decision point)

### Why JSON Contracts?

- **Deterministic**: Same input = same output
- **Testable**: Can create regression fixtures
- **Parseable**: Easy to validate and debug
- **Portable**: Works with any tool/language

### Why Ranking Score?

Formula: `rank_score = 0.60*severity + 0.30*priority + 0.10*confidence`

**Rationale**:
- **60% weight on severity**: Technical impact matters most
- **30% weight on priority**: Operational urgency matters
- **10% weight on confidence**: Penalize uncertain classifications
- **Deterministic**: Same scores always rank the same
- **Explainable**: Can show why issue X ranks above Y

---

## 🎓 Learning Resources

### Documentation Files
- `VIDEO_SCRIPT.md` - Step-by-step video recording guide
- `TRIAGE_RESULTS.md` - Real triage results from 8 issues
- `SAMPLE_OUTPUTS.md` - Agent JSON examples

### Agent Definitions
- `agents/unified-triage/agent.md` - Component taxonomy, severity rubric
- `agents/jira-decision-gate/agent.md` - Policy rules, ranking formula
- `agents/jira-writer/agent.md` - Jira formatting standards

### Scripts
- `scripts/fetch-lxd-issues.sh` - GitHub API integration
- `scripts/jira-create-issue.sh` - Jira REST API v3 usage
- `scripts/run-pipeline.sh` - Orchestration pattern

---

## 🚀 Future Enhancements

- [ ] JSON Schema validation for agent outputs
- [ ] CI/CD integration (auto-triage on new issues)
- [ ] Regression test fixtures
- [ ] Multi-repository support (not just LXD)
- [ ] Custom severity rubrics per project
- [ ] Jira backlog auto-reordering via API
- [ ] Slack notifications for P0/P1 bugs
- [ ] Dashboard with triage metrics

---

## 📜 License

This project follows the same license as LXD.

---

## 🙏 Credits

Built for AI Agents Hackathon 2026

**Technologies**:
- OpenCode (AI agent orchestration)
- Claude Sonnet 4.5 (LLM)
- GitHub CLI (issue fetching)
- Jira REST API v3 (ticket creation)

---

## 📞 Support

For questions or issues:
1. Check `TRIAGE_RESULTS.md` for examples
2. Run with `--dry-run` to debug
3. Review agent definitions in `agents/*/agent.md`
4. Check script help: `./scripts/<script>.sh --help`
5. See `VIDEO_SCRIPT.md` for demo walkthrough

---

**Ready to triage some bugs? Run `/triage-bugs --help` in OpenCode!** 🚀
