<!-- shopfloor:start -->
## Workflow: Untitled

These rules come from a shopfloor recipe and apply to work in T3 Code, which tells you in your instructions when you are running in it. In any other session, ignore them. To change them, change the recipe and install it again.

### Plan

- Models that plan, preferred first: Opus 5.5 (`claudeAgent` · `claude-opus-5-5` · `effort: high`).
- If this thread runs a model that is not on that list, say so once and plan all the same.
- When asked to plan, research, diagnose or design, change no files. End with a written plan, then stop and wait for the user.
- End every plan by naming the build model: `Build model: Opus 5.5 with effort high. Switch to it if this thread runs a model or a setting that is not listed under Build, then say "execute the plan".`

### Build

- Models that build, preferred first: Opus 5.5 (`claudeAgent` · `claude-opus-5-5` · `effort: high`).
- "Execute the plan", or close wording, starts the `shopfloor-build` skill.

### Review

- Before you open a pull request or push to a default branch, run the `shopfloor-review` skill. Only the user can skip it, in their current message.

### Advisor

- The advisor is Fable 5.2 (`claudeAgent` · `claude-fable-5-2` · `effort: high`). It gives a second opinion. It reads and answers, and never edits.
- Ask it with the `shopfloor-advise` skill:
  - before you show a plan to the user, once for each plan
  - when the same check or fix has failed twice, before a third try
  - when a reviewer still holds a finding after it has read your reasons, before you ask the user
  - when the user asks for it
- While you plan, your tools may be read-only and refuse to start it. Then write in the plan that the advisor has not read it. The build asks it first.
- Ask at most 5 times in one task. A task is one plan and its build.
- Its answer is advice. Weigh it and decide yourself. Tell the user what it said, and say so when you did not follow it.

### Limits

- Run at most one subagent at a time. Wait for it to finish before you start another.
- Tell every subagent that it may not start subagents of its own.
<!-- shopfloor:end -->

## Hueometry

A colour-sorting puzzle for Omarchy 4.5+. `docs/plan.md` is the design;
`docs/decisions.md` overrides it where they differ.

### Layers

- The Bend engine (`engine/*.bend`) owns every rule: legal moves, undo,
  victory, generation. It imports only Base, other engine files and
  `SPEC.bend`, never anything about layout, theme or platform.
- QML (`qml/Hueometry/`) draws the state the engine returns. It never decides
  whether a move is legal; legal-target highlights come from the engine.
- The shared QML module imports nothing from Quickshell or the Omarchy shell.
  Host services (storage, quit, fullscreen, language) come through the `Host`
  object that `src/` (standalone app) or `plugin/` (shell plugin) provides.
- Saves go to `$XDG_DATA_HOME/hueometry` and `$XDG_CONFIG_HOME/hueometry`,
  never inside the plugin folder: the shell reloads a plugin on any write
  there.

### Laws

- `LAWS.bend` and `SPEC.bend` are the owner's specification. Change them only
  when the owner asks, and put a `Laws-Change: <reason>` trailer on the
  commit; `bin/check` fails otherwise. Never weaken, delete or trivialise a
  law, or change gameplay, to make a proof pass. Report a law you cannot
  prove instead.
- No `@unsafe`, `def f?` or foreign code in anything `PROOF.bend` reaches:
  `--verdict` rejects it.

### Commands

- `bin/setup` installs the pinned Bend and Lean into your home folder.
- `bin/proof` runs `bend PROOF.bend --verdict`; it must print ALL PROOFS
  CHECK. Run it after any change under `engine/` or to a `.bend` file.
- `bin/engine` rebuilds `qml/Hueometry/js/engine.mjs` from `engine/api.bend`.
  Commit the result; never edit that file by hand. Only
  `qml/Hueometry/js/rules.mjs` imports it.
- `tools/audio/synth.py` regenerates `assets/audio/`. Commit the output and
  update `ASSETS.md`.
- `bin/check` runs everything CI runs. Run it before every commit you push.
