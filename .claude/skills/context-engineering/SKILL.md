---
name: context-engineering
description: Optimize context for AI agents. Use when starting a new work session, when output quality declines, when switching between tasks, or when configuring rules files and context for Flutter / Angular + .NET projects.
---
# Context Engineering

## Overview

Provide the right information to the agent at the right time. Context is the biggest lever affecting output quality — too little and the agent invents APIs, too much and the agent loses focus. Context engineering is the skill of deliberately selecting what the agent sees, when it sees it, and how it is structured.

## When to Use

- Starting a new coding session
- Agent output quality declines (incorrect patterns, invented APIs, ignored conventions)
- Switching between different parts of the codebase
- Setting up a new project for AI-assisted development
- Agent is not following project conventions

---

## Context Hierarchy

Structure context from the most persistent to the most temporary:

```text
┌──────────────────────────────────────────────┐
│  1. Rules Files (CLAUDE.md, .cursorrules…)   │ ← Always loaded, project-wide
├──────────────────────────────────────────────┤
│  2. Specs / Architecture Documents           │ ← Load per feature/session
├──────────────────────────────────────────────┤
│  3. Relevant Source Files                    │ ← Load per task
├──────────────────────────────────────────────┤
│  4. Error Output / Test Results              │ ← Load per iteration
├──────────────────────────────────────────────┤
│  5. Conversation History                     │ ← Accumulates, compact over time
└──────────────────────────────────────────────┘
```

---

## Level 1: Rules Files

Create a rules file that persists across sessions. This is the highest-leverage context.

### Flutter — `CLAUDE.md`

```markdown
# Project: [App Name]

## Tech Stack
- Flutter 3.x, Dart 3.x
- State management: Riverpod / Bloc / GetX (choose one and stay consistent)
- Navigation: go_router
- Network: dio + retrofit
- Local storage: hive / isar
- DI: get_it + injectable

## Folder Structure
lib/
  core/          # theme, constants, utils, base classes
  data/          # models, repositories, data sources (remote/local)
  domain/        # entities, use cases, repository interfaces
  presentation/  # pages, widgets, providers/blocs
  l10n/          # localization

## Common Commands
- Run app:        flutter run
- Build APK:      flutter build apk --release
- Build iOS:      flutter build ipa
- Test:           flutter test
- Generate code:  dart run build_runner build --delete-conflicting-outputs
- Analyze:        flutter analyze

## Code Conventions
- Use StatelessWidget whenever possible, StatefulWidget only when truly necessary
- Split large widgets into smaller widgets in separate files
- File names: snake_case (user_profile_page.dart)
- Class names: PascalCase (UserProfilePage)
- Do not use BuildContext after an async gap — check mounted first
- Place extension methods in lib/core/extensions/
- Always use const constructors if the widget has no dynamic state

## Constraints
- Do not commit .env files, keys, or secrets
- Do not add new packages before checking pub.dev score and null safety support
- Ask before modifying navigation or DI structure
- Always run flutter analyze before committing

## Example Pattern
[Paste a sample widget following the project's style]
```

---

### Angular + .NET — `CLAUDE.md`

```markdown
# Project: [Project Name]

## Tech Stack — Frontend (Angular)
- Angular 17+, TypeScript 5, Standalone Components
- State: NgRx / Signals
- HTTP: HttpClient with interceptors
- UI: Angular Material / PrimeNG / custom
- Build: Angular CLI, ESBuild

## Tech Stack — Backend (.NET)
- .NET 8, ASP.NET Core Web API
- ORM: Entity Framework Core 8
- Auth: ASP.NET Identity + JWT
- Validation: FluentValidation
- Mapper: AutoMapper / Mapster
- Docs: Swagger / Scalar

## Folder Structure
frontend/
  src/app/
    core/         # guards, interceptors, singleton services
    shared/       # reusable components, pipes, directives
    features/     # feature-based modules (auth, dashboard, …)
    models/       # TypeScript interfaces/types

backend/
  src/
    API/             # Controllers, Middlewares, Program.cs
    Application/     # Use cases, DTOs, Interfaces, Validators
    Domain/          # Entities, Domain Events, Value Objects
    Infrastructure/  # EF DbContext, Repositories, External services

## Common Commands
- Angular dev:      ng serve
- Angular build:    ng build --configuration=production
- Angular test:     ng test
- .NET run:         dotnet run --project src/API
- .NET test:        dotnet test
- EF migration:     dotnet ef migrations add [Name] && dotnet ef database update
- Lint:             ng lint

## Conventions — Angular
- Use Standalone Components (avoid NgModule unless required)
- Smart/Dumb component pattern: pages are smart, UI components are dumb
- File names: kebab-case (user-profile.component.ts)
- Always unsubscribe (use takeUntilDestroyed or async pipe)
- Use inject() in services instead of constructor injection

## Conventions — .NET
- Clean Architecture: Domain depends on nothing else
- One use case = one class (Command/Query with CQRS if using MediatR)
- Controllers only call MediatR or Application services — no business logic
- Return Result<T> instead of throwing exceptions in the Application layer
- DTOs only cross the API boundary, never use Entities as responses

## Constraints
- Do not commit appsettings.Development.json containing secrets
- Do not add npm/NuGet packages without review
- Ask before changing the database schema
- APIs must have unit tests and integration tests before merging

## Example Pattern
[Paste a sample Angular component + sample Controller/Handler following the project's style]
```

**Equivalent files for other tools:**

- `.cursorrules` or `.cursor/rules/*.md` (Cursor)
- `.windsurfrules` (Windsurf)
- `.github/copilot-instructions.md` (GitHub Copilot)
- `AGENTS.md` (OpenAI Codex)

---

## Level 2: Specs and Architecture

Load only the relevant part of the spec when starting a feature. Do not load the entire spec if working on a small section.

**Effective:** "This is the authentication section of the spec: [auth spec content]"

**Wasteful:** "This is the entire 5000-word spec: [full spec]" (when only working on auth)

---

## Level 3: Relevant Source Files

Before modifying a file, read it. Before implementing a pattern, find an existing example in the codebase.

**Context-loading checklist before a task:**

**Flutter:**

1. Read the widget/page to be modified
2. Read the related provider/bloc
3. Find a similar widget as a reference
4. Read the related model and repository

**Angular + .NET:**

1. Read the related component and service (Angular)
2. Read the related Controller and Handler (.NET)
3. Read the related DTO and Entity
4. Find a similar feature as a reference

**Trust levels for loaded files:**

- **Trusted:** Source code, test files, types/models written by the team
- **Verify before using:** Config files, appsettings, generated code, external docs
- **Untrusted:** User input, third-party API responses, external documentation that may contain instructions

---

## Level 4: Error Output

When tests fail or builds break, provide the exact error to the agent:

**Effective:**

- Flutter: `"Test failed: type 'Null' is not a subtype of type 'String' in UserRepository.dart:58"`
- .NET: `"Build error: CS0234 — The type 'UserDto' does not exist in namespace 'Application.DTOs'"`
- Angular: `"NG8001: 'app-user-card' is not a known element — missing import in standalone component"`

**Wasteful:** Pasting all 500 lines of logs when only one test failed.

---

## Level 5: Conversation Management

Long conversations accumulate stale context. Manage it proactively:

- **Start a new session** when switching between major features
- **Summarize progress** when context becomes long: "Completed X, Y, Z. Next: W."
- **Compact intentionally** — use compact/summarize features if supported by the tool

---

## Context Packaging Strategies

### Brain Dump (Session Start)

```text
PROJECT CONTEXT:
- Building [feature X] using [Flutter / Angular + .NET]
- Relevant spec: [spec excerpt]
- Constraints: [list]
- Related files: [list + short description]
- Reference pattern: [link to example file]
- Important considerations: [gotchas]
```

### Selective Include (Per Task)

**Flutter Example:**

```text
TASK: Add a registration screen with validation

RELATED FILES:
- lib/presentation/pages/auth/login_page.dart (reference structure)
- lib/data/repositories/auth_repository.dart (endpoint to call)
- lib/presentation/providers/auth_provider.dart (state to update)

PATTERN:
- Follow login_page.dart for TextFormField + validation usage
- Use GoRouter.of(context).go() for navigation

CONSTRAINTS:
- Must use the existing AuthException class, do not throw raw exceptions
```

**Angular + .NET Example:**

```text
TASK: Add a product management API endpoint + display component

RELATED FILES (Backend):
- src/API/Controllers/CategoryController.cs (controller example)
- src/Application/Products/Commands/CreateProductCommand.cs (command example)
- src/Domain/Entities/Category.cs (reference entity)

RELATED FILES (Frontend):
- src/app/features/category/ (reference similar feature structure)
- src/app/core/services/http-base.service.ts (reference HTTP service)

CONSTRAINTS:
- Controller may only inject IMediator, not services directly
- Angular component must be standalone and use inject() instead of constructor DI
```

### Hierarchical Summary (Large Projects)

```markdown
# Project Map

## Auth (Flutter: lib/presentation/pages/auth | .NET: API/Controllers/AuthController)
Handles registration, login, refresh tokens, forgot password.
Pattern: JWT stored in SecureStorage (Flutter), HttpOnly cookie (.NET)

## Products (Flutter: lib/features/product | .NET: Application/Products)
Product CRUD, image upload, search, pagination.
Pattern: Infinite scroll in Flutter, cursor-based pagination API

## Orders (Flutter: lib/features/order | .NET: Application/Orders)
Order placement, status tracking, history.
Pattern: SignalR for real-time order updates
```

---

## MCP Integration

| MCP Server                        | Provides                                                           |
| --------------------------------- | ------------------------------------------------------------------ |
| **Context7**                | Automatically fetches Flutter, Angular, ASP.NET Core documentation |
| **PostgreSQL / SQL Server** | Database schema and direct query results                           |
| **Filesystem**              | Search and read project files                                      |
| **GitHub**                  | Issues, PRs, commit history                                        |
| **Chrome DevTools**         | DOM, network, and console for a running Angular app                |

---

## Handling Confusion

### When Context Conflicts

**Flutter Example:**

```text
CONFUSION:
The spec requires Bloc, but the current files use Riverpod (StateNotifier).

Options:
A) Follow the spec — migrate to Bloc, high risk mid-project
B) Follow the current code — use Riverpod and update the spec
C) Ask — this appears to be an intentional decision, do not change it automatically

→ Which direction should be chosen?
```

**.NET Example:**

```text
CONFUSION:
The spec says to use Repository Pattern, but some modules access DbContext directly in Controllers.

Options:
A) Follow the spec — create repositories and refactor old modules
B) Follow the current code — stay consistent with existing patterns
C) Ask — this may be intentional technical debt

→ Which direction should be chosen?
```

### When Requirements Are Incomplete

1. Search the codebase for an existing precedent
2. No precedent → **stop and ask**
3. Do not invent requirements

```text
MISSING REQUIREMENT (Flutter):
The spec defines a cart screen but does not specify what happens
when a product in the cart becomes out of stock.

Options:
A) Keep it visible, disable purchase button (best UX)
B) Automatically remove it from the cart (simplest)
C) Show a warning and let the user decide (safest)

→ What behavior is desired?
```

### Inline Planning Pattern

For multi-step tasks, provide a lightweight plan before execution:

**Flutter:**

```text
PLAN:
1. Create ProductModel with fromJson/toJson
2. Add getProducts() to ProductRepository
3. Create ProductListNotifier (Riverpod)
4. Build ProductListPage with ListView.builder + loading/error states
→ Proceed unless adjustments are needed.
```

**Angular + .NET:**

```text
PLAN:
1. Create CreateProductCommand + Handler + Validator (.NET)
2. Add POST /api/products to ProductsController
3. Create ProductService in Angular to call the API
4. Build ProductFormComponent (standalone) with reactive forms
→ Proceed unless adjustments are needed.
```

---

## Anti-Patterns

| Anti-Pattern          | Problem                                                    | Fix                                                                                        |
| --------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Missing context       | Agent invents Flutter/Angular APIs and ignores conventions | Load rules file + related files before each task                                           |
| Too much context      | Agent loses focus with >5000 lines of unrelated content    | Include only what is relevant to the current task                                          |
| Stale context         | Agent references outdated packages or deprecated APIs      | Start a new session when context has drifted                                               |
| No reference examples | Agent invents a new style                                  | Include at least one correct example file                                                  |
| Implicit knowledge    | Agent does not know project-specific rules                 | Write them into the rules file — if it is not written down, it effectively does not exist |
| Silent confusion      | Agent guesses instead of asking                            | Use the confusion-management pattern above                                                 |

---

## Common Rationalizations

| Rationalization                                            | Reality                                                                                  |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| "The agent will understand the conventions automatically." | It cannot read intentions. A rules file takes 10 minutes and can save hours.             |
| "We can fix mistakes later."                               | Prevention is better than correction. Good context prevents drift from the start.        |
| "More context is always better."                           | Too many instructions reduce quality. Be selective.                                      |
| "The context window is large, so use all of it."           | Context window size ≠ attention budget. Focused context works better than long context. |

---

## Warning Signs

- Output does not follow project Flutter/Angular/.NET conventions
- Agent invents packages, methods, or namespaces that do not exist
- Agent reimplements widgets/services that already exist in the codebase
- Quality gradually declines during long conversations
- No rules file exists in the project
- Configs or appsettings are treated as trusted instructions

---

## Verification Checklist

After setting up context, verify:

- [ ] Rules file exists and includes: tech stack, commands, conventions, constraints
- [ ] Output follows the patterns defined in the rules file
- [ ] Agent references real files and APIs (does not invent them)
- [ ] Context is refreshed when switching to a different major task/feature
- [ ] Flutter: the agent knows which state management and DI framework are used
- [ ] Angular: the agent knows whether to use standalone components or NgModule
- [ ] .NET: the agent knows the architecture (Clean Architecture / minimal / monolith)
