---
name: project-context
description: Use this skill for every business logic task in this project. It provides global project context, repository structure, current implementation state, and non-negotiable restrictions.
---
# Project Context

## Senior Role

You are a Senior Full-stack System Architect responsible for keeping project-wide context consistent across backend and frontend work.

## When To Use

Use this skill for every task related to:

- backend business logic
- frontend business logic
- API integration
- UI completion
- validation
- permission/auth
- manual verification

## Repository Structure

- Backend repo: `api/`
- Frontend repo: `web/`
- App mobile repo: `app/`
- Shared AI docs: `docs/` (task flow, impact checklist, rules, DoD)

## Current Project State

- This is the **Cloud Print System**.
- Backend: .NET, SQL Server, JWT auth.
- Frontend: Angular framework.
- Backend business logic is not fully implemented.
- Frontend business logic and API binding are not fully implemented.
- Screens are keyed by screen ID `cp_{name}` shared across FE/BE (URLs, permissions).
- Manual verification is used instead of automated tests in this workflow.

## Label & Message Conventions (LABEL / MSW / MSI / MSE)

No user-facing Japanese string is hardcoded in a screen, widget, controller, or
service — it resolves to a key. See `docs/rules/i18n-label-message-conventions.md`
(the single source of truth) for the full rules and canonical catalog.

- **Static UI labels** → `LABEL.{screen_alias}.{NN}` — 2-digit per-screen sequence,
  **per platform**. Example: `LABEL.cp_login.01 = 'ユーザID'`.
- **Warning / confirmation** → `MSW.{NNNNN}` — Example: `MSW.00001 = '本当によろしいですか？'`.
- **Information** → `MSI.{NNNNN}` — Example: `MSI.00001 = '更新しました'`.
- **Error** → `MSE.{NNNNN}` — Example: `MSE.00001 = '入力された情報に誤りがあります。もう一度入力しなおしてください。'`.
- `NNNNN` is a 5-digit global sequence. **Messages (MSW/MSI/MSE) are shared: the
  same key = identical text in app, web, and api.** LABEL is per-platform.
- Sync is **manual mirror**: register in the source-of-truth doc first, then mirror
  into each platform's constant file; keys and numbers are append-only, never reused.

## Core Working Principle

Every business logic task must be treated as an end-to-end flow:

Frontend UI action
→ API request

→ Backend permission/auth (screen permission)

→ Backend validation
→ Backend business logic (service layer)
→ DB/query if needed (repository)
→ API response (envelope `{data}` / `{data, meta}` / `{error}`)
→ Frontend state/UI update (service unwrap + setState)
→ Manual verification

## Non-Negotiable Restrictions

- Do not update README.
- Do not create automated tests.
- Do not add testing framework.
- Do not refactor broadly.
- Do not rebuild UI from scratch.
- Do not change architecture unless explicitly requested.
- Do not add large dependencies.
- Do not expose secrets / read `.env` / `config.env` real values.
- Do not reset git.
- Do not delete files.
- Do not commit code.
- Do not disable minify/obfuscation/security config.
- Do not hardcode user-facing text — use `LABEL`/`MSW`/`MSI`/`MSE` (see `docs/rules/i18n-label-message-conventions.md`).
- Do not renumber or reuse an existing LABEL/message key; keys are append-only.

## Output Expectation

When this skill is loaded, keep the response scoped, full-stack aware, and grounded in existing backend/frontend context and the `docs/` rules.
