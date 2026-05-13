# Sample Outputs

## Sample 1: Jira-Eligible Issue (18205 - Replicator fails second run)

### Unified Triage Output
```json
{
  "issue_id": "18205",
  "classification": {
    "component": "clustering",
    "confidence": 0.90,
    "evidence": [
      "lxd/api_replicators.go",
      "lxd/cluster/cluster_link.go",
      "lxd/db/cluster/replicators.go"
    ],
    "ambiguous_with": "storage",
    "reasoning": "Replicator entity fails during instance refresh with backup.yaml and storage pool errors. Cross-cluster synchronization is a clustering component."
  },
  "severity": {
    "score": 8,
    "confidence": 0.85,
    "dimensions": {
      "data_loss": { "applies": false, "evidence": null },
      "system_stability": { "applies": false, "evidence": null },
      "accessibility": { "applies": false, "evidence": null },
      "blocked_operations": { "applies": true, "evidence": "Replicator completely unusable after first run" },
      "information_integrity": { "applies": false, "evidence": null },
      "networking": { "applies": false, "evidence": null },
      "storage": { "applies": true, "evidence": "Failed writing backup file, Instance storage pool not found" },
      "security_vulnerability": { "applies": false, "evidence": null },
      "regression": { "applies": false, "evidence": null },
      "upgrade_migration": { "applies": false, "evidence": null },
      "system_impact": { "applies": false, "evidence": null },
      "latency": { "applies": false, "evidence": null },
      "blast_radius_cluster_wide": { "applies": true, "evidence": "affects all replicator users" },
      "no_workaround": { "applies": true, "evidence": "no workaround mentioned" }
    },
    "reasoning": "Replicator completely unusable after first run, blocking disaster recovery workflows. Storage pool errors during refresh suggest potential data integrity issues. No workaround available."
  },
  "priority": {
    "level": "P1",
    "points": 4,
    "reasoning": "High severity (8) blocking disaster recovery feature. Default P1 for severity 7-8."
  },
  "readiness": {
    "reproducer_present": true,
    "issue_complete": true,
    "missing_information": []
  }
}
```

### Jira Gate Output
```json
{
  "issue_id": "18205",
  "jira_gate": {
    "jira_eligible": true,
    "jira_required": true,
    "triage_action": "create-jira",
    "blocked_by": []
  },
  "ranking": {
    "severity_norm": 0.80,
    "priority_norm": 0.80,
    "rank_score": 0.725,
    "tie_breakers": [
      "severity_score_desc",
      "priority_points_desc",
      "severity_confidence_desc",
      "issue_id_asc"
    ]
  },
  "next_step": {
    "missing_information": [],
    "request_template": ""
  },
  "decision_explanation": {
    "jira_why": "Eligible (has reproducer, issue complete) and required (severity 8 > 7, confidence 0.85 >= 0.70). Action: create-jira.",
    "ranking_why": "rank_score = 0.60*(8/10) + 0.30*(4/5) + 0.10*0.85 = 0.725"
  }
}
```

---

## Sample 2: Need-Info Issue (18274 - Empty docs feedback)

### Unified Triage Output
```json
{
  "issue_id": "18274",
  "classification": {
    "component": "documentation",
    "confidence": 0.98,
    "evidence": [
      "doc/conf.py",
      "doc/guest-os-compatibility.md",
      "doc/requirements.txt"
    ],
    "ambiguous_with": null,
    "reasoning": "Empty documentation feedback form submitted for Guest OS compatibility page. Documentation system issue."
  },
  "severity": {
    "score": 1,
    "confidence": 0.95,
    "dimensions": {
      "data_loss": { "applies": false, "evidence": null },
      "system_stability": { "applies": false, "evidence": null },
      "accessibility": { "applies": false, "evidence": null },
      "blocked_operations": { "applies": false, "evidence": null },
      "information_integrity": { "applies": false, "evidence": null },
      "networking": { "applies": false, "evidence": null },
      "storage": { "applies": false, "evidence": null },
      "security_vulnerability": { "applies": false, "evidence": null },
      "regression": { "applies": false, "evidence": null },
      "upgrade_migration": { "applies": false, "evidence": null },
      "system_impact": { "applies": false, "evidence": null },
      "latency": { "applies": false, "evidence": null },
      "blast_radius_cluster_wide": { "applies": false, "evidence": null },
      "no_workaround": { "applies": false, "evidence": null }
    },
    "reasoning": "Empty feedback form with no actual technical content. Not a functional bug."
  },
  "priority": {
    "level": "P4",
    "points": 1,
    "reasoning": "Trivial severity (1) maps to P4. No operational urgency."
  },
  "readiness": {
    "reproducer_present": false,
    "issue_complete": false,
    "missing_information": [
      "actual_question_or_issue",
      "expected_behavior",
      "steps_to_reproduce"
    ]
  }
}
```

### Jira Gate Output
```json
{
  "issue_id": "18274",
  "jira_gate": {
    "jira_eligible": false,
    "jira_required": false,
    "triage_action": "need-info",
    "blocked_by": [
      "missing_reproducer",
      "missing_issue_information"
    ]
  },
  "ranking": {
    "severity_norm": 0.10,
    "priority_norm": 0.20,
    "rank_score": 0.155,
    "tie_breakers": [
      "severity_score_desc",
      "priority_points_desc",
      "severity_confidence_desc",
      "issue_id_asc"
    ]
  },
  "next_step": {
    "missing_information": [
      "actual_question_or_issue",
      "expected_behavior",
      "steps_to_reproduce"
    ],
    "request_template": "Thank you for your feedback. To help us address this issue, please provide:\n- The actual question or issue you're experiencing\n- What behavior you expected\n- Steps to reproduce the problem (if applicable)\n\nWithout this information, we cannot proceed with this issue."
  },
  "decision_explanation": {
    "jira_why": "Not eligible: missing reproducer and issue incomplete. Action: need-info.",
    "ranking_why": "rank_score = 0.60*(1/10) + 0.30*(1/5) + 0.10*0.95 = 0.155 (low priority, ranked for cleanup)"
  }
}
```
