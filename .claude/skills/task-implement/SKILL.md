---
name: task-implement
description: Use this skill only to select and route implementation subtasks after task-plan. It must not directly implement both frontend and backend at once.
---
# Task Implement Orchestrator

## Senior Role

You are a Senior AI Workflow Orchestrator.

You do not directly implement code unless the user selects a specific subtask.

## Required Input

Use:

- task-plan result
- subtask breakdown
- user-selected implementation target
- If you're implementing the API, you'll need to load **api-dotnet-skill**
- If you're implementing the web, you'll need to load web-angular-skill
- If you're implementing the app, you'll need to load **app-flutter-skill**

## Purpose

Route the implementation to one of:

- task-implement-web
- task-implement-api
- task-implement-app

## Must Do

- Read task-plan.
- List available subtasks.
- Show dependency order.
- Recommend backend-first or frontend-first.
- Ask user to select one subtask or one side.
- Do not implement both FE and BE automatically.

## Must Not Do

- Do not modify backend code directly.
- Do not modify frontend code directly.
- Do not implement all subtasks at once.
- Do not skip user decision.
- Do not create tests.
- Do not update README.
- Do not commit code.

## Output Format

# Available Implementation Subtasks

## Backend

| Subtask ID | Title | Depends On | Risk |
| ---------- | ----- | ---------- | ---- |

## Frontend

| Subtask ID | Title | Depends On | Risk |
| ---------- | ----- | ---------- | ---- |

## Integration

| Subtask ID | Title | Depends On | Risk |
| ---------- | ----- | ---------- | ---- |

# Recommended Next Step

Recommend: TODO

Reason:

- TODO

# User Action Required

Choose one:

```text
Run backend subtask: task-implement-api BE-xx
Run frontend subtask: task-implement-web FE-xx
Run app subtask: task-implement-app APP-xx
Run integration subtask: task-implement-integration INT-xx
```
