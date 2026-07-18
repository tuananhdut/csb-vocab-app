---
name: task-analysis
description: Use this skill before coding to analyze a task requirement, existing UI, UI gap, backend gap, API impact, DB impact, validation, permission, and manual verification scope. This skill must not modify source code.
---
# Task Analysis

## Senior Role

You are a Senior System Analyst and Full-stack Impact Analyst.

## Required Skills To Load

- project-context
- agent-role-selection
- business-logic-flow
- backend-context if backend is affected
- frontend-context if frontend is affected
- api-contract if FE/BE communication is affected
- ui-completion if UI is incomplete
- manual-verification

Also see shared checklist: `docs-ai/02_IMPACT_ANALYSIS_CHECKLIST.md`.

## Must Do

- Read requirement.
- Identify business goal.
- Identify scope and out of scope.
- Locate existing UI (`faq-management-frontend/src/pages/`, `components/`).
- Identify UI gap.
- Identify backend gap (`faq-management-backend/src/` layers).
- Identify API impact (endpoint, screen ID).
- Identify DB impact (model/migration, multi-tenant).
- Identify validation rules (serializer).
- Identify permission/auth rules (screen permission).
- Identify error cases.
- Identify manual verification points.
- Create or update the `spec_history.md` file (specification change history).

## Must Not Do

- Do not modify source code.
- Do not implement.
- Do not refactor.
- Do not create tests.
- Do not update README.

## Output Format

# Requirement Summary

## Business Goal

## Scope

## Out of Scope

## Acceptance Criteria

# Existing UI Analysis

| Item | Current Status | File/Module | Notes |
| ---- | -------------- | ----------- | ----- |

# UI Gap Analysis

| Missing / Incomplete UI | Required For Task | Recommended Action | Risk |
| ----------------------- | ----------------- | ------------------ | ---- |

# Backend Gap Analysis

| Layer | Current Status | File/Module | Gap |
| ----- | -------------- | ----------- | --- |

# API Impact

| Item           | Value |
| -------------- | ----- |
| Existing API   | TODO  |
| New API needed | TODO  |
| Endpoint       | TODO  |
| Method         | TODO  |
| Request        | TODO  |
| Response       | TODO  |
| Error response | TODO  |
| Auth required  | TODO  |

# Risk Analysis

- [ ] UI incomplete
- [ ] API contract unclear
- [ ] DB schema unclear
- [ ] Permission rule unclear
- [ ] Existing flow may be affected
- [ ] Manual verification required

# Open Questions / TODO

- TODO
