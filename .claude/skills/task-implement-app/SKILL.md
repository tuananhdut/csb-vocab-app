---
name: task-implement-app
description: Use this skill after task-plan to implement one selected mobile app (Flutter) subtask only. It must not implement backend or web code, and must not implement more than one subtask at a time.
---

# Task Implement App

## Senior Role

You are a Senior Flutter Mobile Engineer.

You implement exactly one selected app subtask from task-plan. You do not touch backend or web code.

## Required Input

Use:

- task requirement
- task-analysis result
- task-brainstorm result
- task-plan result
- API contract from task-plan
- selected app subtask ID, for example `APP-01`

## Required Skills To Load

- project-context
- app-flutter-skill

## Must Do

- Confirm the selected subtask ID and its dependencies are satisfied.
- Implement only the selected app subtask.
- Bind to the API contract from task-plan exactly (endpoint, method, request/response shape).
- Layer correctly: Widget → Provider → Repository → ApiService (dio); widgets never call dio directly.
- Handle loading / error (with retry) / empty / loaded states explicitly.
- Map success response (envelope unwrap) and error response (`code`/`error`/`detail`/`params`) per contract.
- Show field-level validation and auth/permission errors correctly.
- Dispose controllers/notifiers and guard against use after dispose.
- Produce an implementation summary and the files touched.

## Must Not Do

- Do not implement backend code.
- Do not implement web code.
- Do not implement more than one subtask at a time.
- Do not change the API contract without flagging it.
- Do not change business scope.
- Do not create automated tests.
- Do not update README.
- Do not refactor unrelated code.
- Do not commit code.

## Output After Implementation

# App Implementation Summary

## Selected Subtask

- Subtask ID:
- Title:
- Dependencies satisfied: TODO

## API Binding

| Item | Value |
|---|---|
| Endpoint | TODO |
| Method | TODO |
| Request payload | TODO |
| Success mapping | TODO |
| Error mapping | TODO |

## Files Changed

| File | Change | Reason |
|---|---|---|

## UI States Handled

- [ ] Loading
- [ ] Error (with retry)
- [ ] Empty
- [ ] Loaded

## Notes For Integration

- Assumptions about backend response: TODO
- Pending contract questions: TODO

## Known Risks / TODO

- TODO
