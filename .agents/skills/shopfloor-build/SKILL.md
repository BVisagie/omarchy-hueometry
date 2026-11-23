---
name: shopfloor-build
description: Use in T3 Code when the user says "execute the plan" or close wording. Builds the plan agreed in this thread, proves it works, gets it reviewed, and opens a pull request.
---

# Build the plan

This skill is for work in T3 Code, which tells you in your instructions when you are running in it. In any other session, do not follow it. Say in one line that it needs T3 Code, and carry on as you would without it.

The user agreed a plan and wants it built without approving each step. Work through the steps in order, then stop.

1. **Find the plan.** It is the plan agreed in this thread. If you cannot see all of it, which happens after a switch of provider, read it from this thread with `t3_thread_read` before anything else. `orchestrator_capabilities` gives this thread's id as `parentThreadId`. If there is no plan, or it leaves open a choice that changes the result, ask. If the plan says the advisor has not read it, ask the advisor now with the `shopfloor-advise` skill. If its answer changes the plan, stop and tell the user before you build.
2. **Check the model.** These models may build, preferred first: Opus 5.5 (`claudeAgent` · `claude-opus-5-5` · `effort: high`). If this thread runs a model that is not on the list, or a listed model with other options, name what it runs and ask whether to continue or switch. Never switch it yourself. `orchestrator_capabilities` reports this thread's model as `inheritedModel` and its options as `inheritedOptions`.
3. **Start clean.** Fetch the remote and branch from its default branch. If the working tree holds changes you did not make, ask before you touch them.
4. **Build** the smallest change that delivers the plan. Commit in logical steps.
5. **Prove it.** Run the checks the repository's CI runs. For a reported problem, reproduce it first, then watch the same reproduction pass. Note anything you could not prove. When the same check or fix has failed twice, ask the advisor with the `shopfloor-advise` skill before a third try.
6. **Read your own diff** against the plan and cut what the plan did not ask for.
7. **Review.** Run the `shopfloor-review` skill. Continue only when it finds every reviewer done, or the user settles a disagreement.
8. **Open a pull request** that says what changed and how it was tested. Never merge it.
9. **Stop and report:** the review state first, then the link, what you proved, what you could not, and each decision you made for the user.
