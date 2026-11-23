---
name: shopfloor-review
description: Use in T3 Code before opening a pull request or pushing to a default branch, when the user asks for a review, and from shopfloor-build. Other models read the change one at a time until each approves.
---

# Review the change

This skill is for work in T3 Code, which tells you in your instructions when you are running in it. In any other session, do not follow it. Say in one line that it needs T3 Code, and carry on as you would without it.

Reviewers read; you fix. Each reviewer runs as a child task on its own model, so it reads the change cold.

## Reviewers, in order

Each line gives the reviewer and its `target` for `delegate_task`.

1. GPT-6.2 Astra: `{"providerInstanceId":"codex","model":"gpt-6.2-astra","options":{"reasoningEffort":"ultra"}}`
2. Fable 5.2: `{"providerInstanceId":"claudeAgent","model":"claude-fable-5-2","options":{"effort":"high"}}`

## Rules

- A model never reviews its own work. Skip a reviewer that is the model running this thread, and say that you did. If that leaves no reviewer, stop and ask the user.
- One reviewer runs at a time. Do not edit files while it runs.
- One round is one run of one reviewer. Use at most 12 rounds in total, counted across all reviewers.
- A reviewer is done when it approves, or when all it has left are nits that you fixed or declined. A clean first read needs no second round. It stays done when a later reviewer leads to changes.
- When the rounds run out before every reviewer is done, stop and ask the user.
- If `delegate_task` is not available, stop and tell the user. Do not skip the review, and do not review the change yourself.

## Each round

1. Before the first round, call `orchestrator_capabilities` and check that every reviewer's provider is listed. Its list of models is short, so pass a model's id as `search` before you call that model missing. If one is missing, tell the user. Do not swap in another model.
2. Start the reviewer with `delegate_task`: `mode: "wait"`, its `target` from the list above, and the brief below as `task`.
3. Answer its findings. Fix a real problem with the smallest change. Decline a nit, or anything outside the change's intent, and say why.
4. Run the same reviewer again if you changed behaviour, or if you disagree with a finding it marked blocker or should. Fill in the last line of the brief, so that it reads what you fixed and your reasons. Otherwise move to the next reviewer, who reads the fixed code and not the earlier findings.
5. If a reviewer still holds a blocker or should after it has read your reasons, ask the advisor with the `shopfloor-advise` skill before you ask the user.

## Brief

```text
Review only. Do not edit files, commit, push, or start subagents.
Repository: <absolute path>
Base: <the commit the change started from>
Intent: <what the change is for, in one or two sentences>
Out of scope: <what the change leaves alone>
Read the diff from the base, any untracked files, and the code around the change.
Report bugs, callers the change breaks, and places where it does not match the intent.
Leave style alone unless it hides a bug.
blocker: the change does not do what it is for. should: a real bug within that intent. nit: everything else.
Reply with one line, VERDICT: APPROVE or VERDICT: CHANGES, then one line per finding:
[blocker|should|nit] <file>:<line> <what is wrong>. Fix: <suggestion>
Earlier round: <leave this line out on a first read. On a second, what you fixed, and each finding you disagree with and why>
```

## When it ends

Report the reviewers that ran, the rounds used, each verdict, and every finding you declined with its reason.
