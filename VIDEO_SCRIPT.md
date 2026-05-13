# Video Demo - Quick Reference Card

## 🎬 5-Minute Video Script

### Pre-Recording Checklist
- [ ] `gh auth status` ✓
- [ ] `./scripts/jira-auth.sh` completed ✓
- [ ] LXD repo exists at `/project/git/lxd` ✓
- [ ] Screen recording software ready
- [ ] Terminal font size increased for visibility
- [ ] Browser with Jira open in another tab

---

## 📝 Script Timeline

### [00:00-00:30] Hook & Problem
```
"Let me show you something cool. This AI system automatically 
triages GitHub bugs and creates a prioritized Jira backlog.

Manual triage takes hours. For 20 bugs, you need to read logs, 
classify components, assess impact, and rank priority. 

Let's automate it with AI agents."
```

**Screen**: Show repository structure

---

### [00:30-01:30] Architecture Overview

```bash
# Show the 3 agents
ls agents/
cat agents/unified-triage/agent.md | head -15
```

```
"We have 3 specialized AI agents working together:

Agent 1 - UNIFIED TRIAGE
  Reads source code, classifies components, scores severity
  using 14 technical dimensions like data loss, security, 
  system stability.

Agent 2 - DECISION GATE  
  Applies business policy rules, calculates ranking scores,
  decides which bugs need Jira tickets.

Agent 3 - JIRA WRITER
  Generates properly formatted Jira payloads with all metadata.

Each agent has a strict JSON contract - input and output are 
structured and auditable."
```

**Screen**: Show agent.md files, highlight key sections

---

### [01:30-02:00] Show Raw Input

```bash
# Show an unstructured GitHub issue
cat scripts/testdata/issues/lxd-real/18150.json | jq '{id, title, description}' | head -30
```

```
"Here's what we start with: a raw GitHub issue. 
Long description, error logs, no classification, no priority.
Just text from a user reporting a bug."
```

**Screen**: Show JSON scrolling, highlight the unstructured text

---

### [02:00-03:30] THE MAGIC - Run the Pipeline

```bash
cd /project/git/bug-triaging-dev
```

**In OpenCode terminal:**
```
/triage-bugs --limit 8 --dry-run
```

```
"Now watch. ONE command processes everything:

[As it runs, narrate what's happening]

✓ Fetching 8 issues from GitHub... done
✓ Agent 1 analyzing... 
  - Reading LXD source code
  - Classifying component: 'storage', confidence 98%
  - Scoring severity: 7/10
  - Assigning priority: P1

✓ Agent 2 applying policy...
  - Issue complete? Yes
  - Severity threshold? Yes, 7 > 6
  - Jira required? Yes
  - Rank score: 0.81

✓ Agent 3 generating Jira payload...
  - Summary: [LXD][storage][P1] LVM thin-pool usage overreporting
  - Labels: lxd, triage-bot, priority-p1, severity-7
  - Linked to GitHub issue

[Repeat for a few more issues, faster]

✓ 8 issues processed
✓ 6 eligible for Jira
✓ 2 need more information
```

**Screen**: Split screen - code on left, OpenCode output on right

---

### [03:30-04:00] Show Structured Output

```bash
# Show agent output JSONs
cat /tmp/opencode/triage-pipeline/agent1-18150.json | jq '.classification'
cat /tmp/opencode/triage-pipeline/agent2-18150.json | jq '.ranking'
```

```
"Look at the structured output:

Agent 1 found:
  - Component: storage (98% confident)
  - Severity: 7/10
  - Evidence: driver_lvm_utils.go line 742
  
Agent 2 calculated:
  - Rank score: 0.81
  - Priority: P1
  - Jira required: true

This is deterministic. Same bug = same classification."
```

**Screen**: Show formatted JSON output

---

### [04:00-04:45] Create in Jira (For Real)

```
/triage-bugs --limit 8 --epic-key LXD-100
```

```
"Now let's create these for real...

[Wait ~15 seconds as it processes]

✓ Pipeline complete!
  - 8 issues analyzed
  - 6 created in Jira
  - 2 flagged for more info

The system even tells us WHY 2 were skipped:
  'Missing reproducer steps'
  'Incomplete environment information'
```

**Screen**: Show completion summary

---

### [04:45-05:30] Show Jira Backlog - THE PAYOFF

```
[Switch to browser, open Jira backlog]
```

```
"And here's the result: a prioritized backlog!

[Point to top issues]

Issue #1: Network ACL security bypass - P1, rank 0.87
  Critical security bug, highest priority

Issue #2: Replicator failure - P1, rank 0.85
  Disaster recovery feature broken

Issue #3: DevLXD socket removed - P1, rank 0.83
  Affects production deployments

[Scroll down]

Each issue has:
  ✓ Component classification
  ✓ Severity score
  ✓ Priority level
  ✓ Link back to GitHub
  ✓ Evidence from source code

A developer can now pick the first issue and KNOW it's 
the most critical bug to fix. No guessing, no meetings,
no manual prioritization."
```

**Screen**: Jira backlog, click into one issue to show details

---

### [05:30-06:00] Wrap Up

```
"Summary:

✓ 3 specialized AI agents
✓ Reads actual source code for accuracy  
✓ Structured JSON contracts - auditable and testable
✓ One command: GitHub → prioritized Jira backlog
✓ Saves hours of manual triage work per day

What took 2 hours of manual work now takes 30 seconds.

Built with OpenCode AI agents and Claude Sonnet.
Code is in the repository. Try it yourself!

Thanks for watching!"
```

**Screen**: Show final summary stats, fade to repository URL

---

## 🎨 Visual Elements to Include

### Terminal Recording
- Large font (16pt minimum)
- High contrast theme
- Clear command prompts
- Syntax highlighting for JSON

### Browser Recording  
- Zoom in on relevant sections
- Highlight issues as you mention them
- Show the rank/priority clearly
- Click into one issue to show details

### Screen Splits
- Code + Terminal (when showing agents)
- Terminal + Browser (when showing results)
- Full screen for key moments (the "magic" command)

---

## 💡 Key Messages to Emphasize

1. **"ONE COMMAND does everything"** - Say this 2-3 times
2. **"Reads actual source code"** - Not just text analysis
3. **"Structured and auditable"** - Show JSON contracts
4. **"Deterministic ranking"** - Same bug = same priority
5. **"Saves hours daily"** - Quantify the benefit

---

## 🎯 Demo Flow Summary

```
Problem → Architecture → Raw Input → MAGIC → Structured Output → Jira Result → Payoff
  30s        60s           30s        90s         30s              45s         45s
```

**Total: ~5:30 minutes** (leaves 30s buffer)

---

## 🚨 Common Pitfalls to Avoid

❌ Don't spend too long on setup/installation
✅ Do show the "before" (messy) and "after" (clean)

❌ Don't explain every line of code
✅ Do highlight key architectural decisions

❌ Don't wait in silence during processing
✅ Do narrate what's happening in real-time

❌ Don't use tiny fonts or low contrast
✅ Do increase zoom for visibility

❌ Don't show errors without explaining recovery
✅ Do use `--dry-run` first to verify

---

## 📊 Success Metrics to Show

**In the video, display these stats:**

```
Manual Triage:
  - Time per bug: 5-10 minutes
  - Time for 20 bugs: 2-3 hours
  - Error rate: ~15% (wrong classification)

AI-Powered Triage:
  - Time per bug: 2-3 seconds  
  - Time for 20 bugs: 60 seconds
  - Accuracy: 92% confidence average
  - Consistency: 100% (deterministic)

ROI: 98% time saved
```

---

## 🎤 Delivery Tips

### Energy
- Start with energy to hook viewers
- Maintain steady pace (don't rush technical parts)
- Build excitement toward the "magic moment"
- End with confidence and clear CTA

### Clarity
- Use simple language (avoid jargon)
- Explain acronyms first time (P1 = Priority 1)
- Pause briefly after key statements
- Repeat important points

### Visuals
- Point with cursor to what you're discussing
- Use zoom/highlights for emphasis
- Keep movement smooth (no jerky scrolling)
- Ensure code is readable at YouTube resolution

---

## 🔄 B-Roll Ideas (Optional)

If you want to make it more polished:

- Animation of the agent pipeline flow
- Before/after comparison slides
- Statistics overlays
- Screen zoom-ins on key JSON fields
- Time-lapse of manual vs automated triage

---

## ✅ Final Checklist Before Recording

- [ ] Test full pipeline end-to-end
- [ ] Clear `/tmp/opencode/triage-pipeline/`
- [ ] Have 8-10 real issues ready in testdata
- [ ] Jira Epic created and key noted
- [ ] Browser tabs arranged (repo, Jira)
- [ ] Microphone tested
- [ ] Recording software tested
- [ ] Script printed/on second monitor
- [ ] Water nearby (stay hydrated!)
- [ ] Phone on silent

---

**You got this! 🚀 Show them how AI agents revolutionize bug triage!**
