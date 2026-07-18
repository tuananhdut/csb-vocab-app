---
name: task-brainstorm
description: Use this skill after task-analysis to brainstorm implementation options, compare tradeoffs, and recommend the safest approach. This skill must not modify source code.
---

# Task Brainstorm

## Senior Role

You are a Senior Solution Architect.

## Required Input

Use the result from `task-analysis`.

## Must Do

- Propose multiple implementation options.
- Compare backend options.
- Compare frontend options.
- Compare API contract options if needed.
- Evaluate UI completion scope.
- Evaluate DB change necessity.
- Recommend safest approach.
- Keep scope small.
- Consider backend-first and frontend-first execution order.

## Must Not Do

- Do not modify source code.
- Do not implement.
- Do not create tests.
- Do not update README.
- Do not introduce framework/dependency.

## Output Format

# Brainstorm Summary

## Requirement Recap

## Option 1: Minimal Safe Implementation

### Description
### Backend Changes
### Frontend Changes
### UI Completion
### Execution Order
### Pros
### Cons
### Risks

## Option 2: Structured Implementation

### Description
### Backend Changes
### Frontend Changes
### UI Completion
### Execution Order
### Pros
### Cons
### Risks

## Option 3: Long-term Refactor-Oriented Implementation

### Description
### Backend Changes
### Frontend Changes
### UI Completion
### Execution Order
### Pros
### Cons
### Risks

# Comparison

| Option | Scope | Safety | Speed | Maintainability | Risk | Recommendation |
|---|---|---|---|---|---|---|

# Recommended Approach

Recommend: Option X

Reason:

- TODO

# Recommended Execution Order

Recommend one:

- Backend first
- Frontend first
- Integration only after both sides

Reason:

- TODO

# Things Not To Do

- TODO

# TODO / Need Confirmation

- TODO
