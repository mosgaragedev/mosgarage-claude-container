# AGENTS.md — {{PROJECT_NAME}}

> Codex CLI / Cursor / Aider compatible instruction file.
> Open standard — read by any tool supporting AGENTS.md.
> Keep in sync with CLAUDE.md.

---

## Project Summary

**{{PROJECT_NAME}}** — {{PROJECT_TYPE}}
Stack: {{TECH_STACK}}
Package manager: {{PKG_MANAGER}} — always, never switch

---

## Repository Layout

```
{{REPO_STRUCTURE}}
```

---

## Key Commands

```bash
{{CMD_INSTALL}}      # install dependencies
{{CMD_DEV}}          # start dev server
{{CMD_LINT}}         # lint
{{CMD_TEST}}         # run all tests
{{CMD_BUILD}}        # build for production
```

---

## Absolute Rules

1. Strict typing — no `any`, no unsafe casts
2. All user inputs validated at API boundary before any logic
3. All secrets via environment variables — see `.env.example`
4. Conventional Commits for all commit messages
5. Never touch `.env` — only `.env.example`

---

## Spec Files

Read the relevant spec before implementing any module:

```
docs/specs/       # one file per module
docs/PRD.md       # scope and requirements
docs/ARCHITECTURE.md  # system design
```

---

## Test Requirements

- All route handlers: integration tests
- All utility functions: unit tests
- Input schemas: validation loop tests (valid + invalid for every field)
- Run full suite before marking any task complete
