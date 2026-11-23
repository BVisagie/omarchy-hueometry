---
name: shopfloor-advise
description: Use in T3 Code to get a second opinion from the advisor model. Ask before you show a plan to the user, when the same check or fix has failed twice, when you and a reviewer cannot agree, and when the user says "ask the advisor". The advisor reads and answers. It never edits.
---

# Ask the advisor

This skill is for work in T3 Code, which tells you in your instructions when you are running in it. In any other session, do not follow it. Say in one line that it needs T3 Code, and carry on as you would without it.

The advisor is Fable 5.2. It runs as a child task on its own model, so it knows only what your question tells it.

Its `target` for `delegate_task`:

`{"providerInstanceId":"claudeAgent","model":"claude-fable-5-2","options":{"effort":"high"}}`

## Rules

- Ask at most 5 times in one task, counted across every reason. A task is one plan and its build. When that is used up, carry on without the advisor and say so.
- Ask one question at a time. Do not edit files while the advisor runs.
- Its answer is advice. Weigh it and decide yourself. Tell the user in a line or two what it said, and say so when you did not follow it.
- If `delegate_task` is not available, tell the user and carry on without the advisor.
- If you are not allowed to start it, which can happen while you plan with read-only tools, do not insist. Write in the plan that the advisor has not read it.

## Ask

1. Before the first question, call `orchestrator_capabilities` and check that the advisor's provider is listed. Its list of models is short, so pass the model's id as `search` before you call it missing. If it is missing, tell the user and carry on without it. Do not swap in another model.
2. Start the advisor with `delegate_task`: `mode: "wait"`, `interactionMode: "plan"`, the `target` above, and the question below as `task`.
3. Use the answer, then carry on with your own work.

## Question

```text
Advise only. Do not edit files, commit, push, or start subagents.
Repository: <absolute path>
Question: <the one decision or problem you want a second opinion on>
What I know: <the plan, or what you tried and what happened, with file paths and exact errors>
What I lean towards: <your current answer, and why>
Read what you need in the repository before you answer.
Reply briefly with: what you would do, the main risk in my current answer, and anything I have missed.
```
