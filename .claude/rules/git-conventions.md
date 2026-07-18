# Git conventions

## Branch naming

`feature.<type>.<short-description>`, all in English, lowercase, words separated by dots or hyphens.

Types:
- `new` — new feature
- `bugfix` — bug fix
- `revamp` — refactor / improvement of existing behavior

Examples: `feature.new.personal-deck`, `feature.bugfix.scroll-overflow`, `feature.revamp.review-session`.

## Commit messages

Conventional Commits, in English: `type(scope): summary`.

Types: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `style`.

- Body explains the *why*, not a line-by-line list of what changed.
- **Never add a `Co-Authored-By` trailer.** Do not sign commits as Claude/AI co-author.
