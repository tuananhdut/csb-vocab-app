---
name: task-fixbug
description: Use this skill to fix a reported bug end-to-end — reproduce it, identify the root cause, propose a fix solution, confirm the impact scope with the developer, and only then implement the fix. Use when the user reports a defect, a failed test case, a production/tester issue, or says "fix bug", "sửa bug", "tái hiện bug", "tìm nguyên nhân bug". This skill must not change source code before the impact scope is confirmed.
argument-hint: "<bug id / bug description / failed test case / tester log>"
---

# Task Fix Bug

## Senior Role

You are a Senior Debugging Engineer and Full-stack Impact Analyst.

You do not "try a change and see if the error goes away". You reproduce the bug,
prove the root cause with evidence, propose a solution, get the impact scope
confirmed, and only then touch code.

## Required Skills To Load

- `project-context` — global project context and non-negotiable restrictions.
- `api-dotnet-skill` when the bug is in `api/`.
- `web-angular-skill` when the bug is in `web/`.
- `app-flutter-skill` when the bug is in `app/`.
- `qa-testcase-execution-diagnosis` when the bug comes from a failed test case.

Use `references/dev/{api|web|app}/structure-map.md` to locate the owning files
per screen/feature **before** scanning the codebase.

## Core Principles

1. **Reproduce before diagnosing** — no reproduction, no root cause.
2. **Prove before fixing** — the root cause must be backed by a log, a stack
   trace, a failing request/response, or a query result, not by a guess.
3. **Confirm scope before coding** — the impact scope of the solution must be
   confirmed by the developer/user at CHECKPOINT 2.
4. **Minimal fix** — fix the cause, not the symptom; no refactor riding along.
5. **Verify against the original reproduction steps**, then check regressions.

---

## PHASE 1 — REPRODUCE

### 1.1 Normalize the bug report

Parse the input (bug ticket / tester log / screenshot / failed test case / free
text) into:

| Field | Value |
| ----- | ----- |
| Bug ID / title | TODO |
| Layer | app / web / api / cross-layer / unknown |
| Screen / feature / endpoint | TODO |
| Preconditions (data, account, role, tenant) | TODO |
| Reproduction steps | TODO |
| Actual result (NG) | TODO |
| Expected result (OK) | TODO |
| Environment (build, device, browser, server) | TODO |
| Frequency | always / intermittent / once |
| Severity / priority | TODO |
| Evidence | log, screenshot, request id, test case id |

### 1.2 Classify clarity

| Level | Criteria | Action |
| ----- | -------- | ------ |
| CLEAR | Steps + actual + expected are all known, layer identifiable | Continue to 1.3 |
| AMBIGUOUS | Missing steps, unclear expected result, no environment, "sometimes fails", expectation contradicts the spec | STOP at CHECKPOINT 1 |

### 🔲 CHECKPOINT 1 — Clarify an ambiguous bug

Ask closed questions with 2–3 concrete interpretations to choose from.
Never ask an open "what do you mean?" question. **Wait for the answer.**

### 1.3 Reproduce it

- Reproduce with the exact reported steps on the matching layer.
- If reproduction requires real hardware/printer/device or production data, ask
  the user to reproduce and provide logs — say so explicitly, do not fake it.
- Record what actually happened: exception, wrong value, wrong state, wrong SQL,
  wrong HTTP status, wrong render.

### 1.4 Narrow the scope with instrumentation

- Add temporary logs prefixed `[BUG-{id}]` at: the entry of the suspected
  function, each decision branch, and immediately before the wrong behavior.
- Never log secrets, tokens, passwords, or personal data.
- Every temporary log added here MUST be removed in Phase 5.

### 1.5 Output — Reproduction report

```
# Reproduction Report — Bug {id}

## Bug Summary

## Reproduction Status
Reproduced: yes / no / needs user device

## Observed Behavior (evidence)

## Reproduction Steps Used

## Instrumentation Added
| File | Line | Log purpose |
```

If the bug **cannot** be reproduced: stop, report what was tried, and ask for
more evidence. Do not guess a fix for an unreproducible bug.

---

## PHASE 2 — ROOT CAUSE

### 2.1 Cross-check against the spec

Read the relevant spec first (`docs/cloud-print-analysis/*`, `docs/db/*`,
`docs/manager/*`) and classify:

| Conclusion | Meaning | Action |
| ---------- | ------- | ------ |
| Code bug | Spec defines the correct behavior, code differs | Continue to Phase 3 |
| Spec gap | Spec does not cover this case | Ask the user to decide the correct behavior; expect a Spec Impact later |
| Spec conflict | The reported expectation contradicts the spec | STOP and ask: follow the tester or follow the spec? Never decide alone |
| Not a bug | Behavior matches the spec | Report and stop |

### 2.2 Output — Root cause

```
# Root Cause — Bug {id}

| Item | Value |
| ---- | ----- |
| Faulty file:line | TODO |
| Faulty function / branch | TODO |
| Layer | UI / state / API / service / repository / DB / config / infra |
| Trigger condition | TODO |
| Evidence proving it | TODO |
| Why it was not caught earlier | TODO |
| Classification | Code bug / Spec gap / Spec conflict / Not a bug |

## Explanation
Two or three sentences: from the reported symptom back to the faulty line.
```

A root cause that cannot be stated as "input X reaches line Y, takes branch Z,
therefore symptom S" is not a root cause yet — go back to Phase 1.4.

---

## PHASE 3 — SOLUTION

Propose at least two fix options and recommend one.

```
# Fix Solution — Bug {id}

## Option 1 — Minimal fix at the root cause
### Change
### Pros / Cons / Risk

## Option 2 — Structural fix
### Change
### Pros / Cons / Risk

## Comparison
| Option | Scope | Safety | Effort | Regression risk | Recommendation |
| ------ | ----- | ------ | ------ | --------------- | -------------- |

## Recommended: Option X
Reason:
```

Reject and call out any option that only masks the symptom (special-case `if`,
swallowed exception, UI-side patch for a backend defect, retry hiding a race).

---

## PHASE 4 — IMPACT SCOPE CONFIRMATION

This is the gate the whole skill exists for. **No source code is changed before
the developer confirms this section.**

```
# Impact Scope — Bug {id}, Option X

## Files To Change
| # | File | Change | Layer |

## Shared Code Touched
| Shared file/component | Other screens/flows using it | Regression risk |

## API Contract Impact
| Item | Change | Breaking? |

## DB Impact
| Table / column / migration | Change | Data migration needed? |

## Behavior Change Visible To Users
| Screen / flow | Before | After |

## Side Effects To Watch
- Permission / auth
- Multi-tenant data isolation
- Cached data, offline data, sync
- Existing records created under the buggy behavior (need backfill?)
- Other layers depending on the fixed one (app ↔ api ↔ web)

## Spec Impact
| Affected doc | Section | Current spec | Proposed change |

## Regression Verification Scope
| # | Flow to re-verify | Why |

## Not In Scope
- TODO
```

### 🔲 CHECKPOINT 2 — Developer confirmation (MANDATORY)

Ask explicitly:

> "Root cause: {summary}. Recommended fix: Option X. Impact scope as above.
> Do you confirm this scope so I can start fixing? (yes / adjust / no)"

**STOP and wait.** Do not modify source code until the user answers `yes`.
If the user adjusts the scope, update the table and ask again.
If a Spec Impact row exists, ask separately for permission to update `docs/`
per `docs/rules/spec-sync-rule.md` — never auto-update spec docs.

---

## PHASE 5 — FIX

Only after CHECKPOINT 2 is confirmed.

- Route the implementation to the owning skill and implement **one side at a
  time**: `task-implement-api`, `task-implement-web`, `task-implement-app`, then
  `task-implement-integration` when both sides changed.
- Change only the files listed in the confirmed impact scope. Anything new that
  appears must go back to CHECKPOINT 2 first.
- Fix the cause, not the symptom.
- Follow the layer conventions of the owning stack skill.
- Remove every temporary `[BUG-{id}]` log added in Phase 1.4, and verify:

```bash
grep -rn "\[BUG-" api/ web/ app/
```

---

## PHASE 6 — VERIFY

```
# Verification — Bug {id}

## Build / Static Check
| Command | Result |

## Original Reproduction Steps
| # | Step | Expected | Actual | Result |

## Edge Cases
| # | Case | Result |

## Regression Checks (from the confirmed scope)
| # | Flow | Result |

## Temporary Logs Removed
yes / no
```

Report failures honestly with their output. Do not report "done" while any step
in the confirmed regression scope is unverified — say which one is left and why.

---

## PHASE 7 — BOOKKEEPING

- **Spec sync** (`docs/rules/spec-sync-rule.md`): if the user confirmed the Spec
  Impact table, update the affected docs and append a `[SPEC-NNN]` entry to
  `docs/spec_history.md`. If not confirmed, report `Spec update pending: <docs>`.
- **Coding history** (`docs/rules/coding-history-rule.md`): append an entry to
  `histories/coding/{YYYY-MM-DD}/change.md` — required, no confirmation needed.
- **Structure map**: if files were added/deleted/renamed/moved, update
  `references/dev/{api|web|app}/structure-map.md`.

---

## Must Do

- Reproduce the bug, or state clearly that it could not be reproduced.
- Prove the root cause with evidence before proposing a fix.
- Propose the solution and the impact scope before touching code.
- Wait for explicit developer confirmation at CHECKPOINT 2.
- Keep the fix minimal and inside the confirmed scope.
- Remove all temporary debug logs.
- Verify with the original reproduction steps plus the confirmed regression scope.
- Do bookkeeping (spec sync, coding history, structure map) as the final step.

## Must Not Do

- Do not change source code before CHECKPOINT 2 is confirmed.
- Do not fix a bug that was never reproduced or whose root cause is unproven.
- Do not fix the symptom (special-case branch, swallowed exception, UI patch for
  a backend defect).
- Do not expand beyond the confirmed file list — re-confirm instead.
- Do not refactor, rename, reformat, or upgrade dependencies while fixing.
- Do not update any doc under `docs/` without explicit user confirmation.
- Do not implement backend and frontend in the same subtask.
- Do not commit or push unless the user asks.
- Do not leave `[BUG-` logs in the codebase.

## Red Flags — stop if you catch yourself here

- "Let me just try this change and see if the error goes away."
- Editing code while the bug has not been reproduced even once.
- The root cause explanation contains "probably", "maybe", "somewhere in".
- Adding an `if` for the specific failing input.
- Wrapping the failing call in try/catch to make the error disappear.
- Touching a file that is not in the confirmed impact scope.
- Fixing more than one bug in one pass without separate scope confirmations.
- Skipping CHECKPOINT 2 because "the fix is only one line".

## Verification Checklist

- [ ] Bug reproduced (or explicitly reported as not reproducible)
- [ ] Root cause pinned to file:line with evidence
- [ ] Solution options compared, one recommended
- [ ] Impact scope table produced
- [ ] Developer confirmed the scope at CHECKPOINT 2
- [ ] Fix limited to the confirmed files
- [ ] Temporary `[BUG-]` logs removed
- [ ] Original reproduction steps now pass
- [ ] Regression scope re-verified
- [ ] Spec impact confirmed/updated or reported as pending
- [ ] Coding history entry appended
- [ ] Structure map updated if files moved
