# Contributing to TestProject

## Local Setup

```bash
git clone https://github.com/test/test-project
cd test-project
cp .env.example .env
# Fill in .env values
pnpm install
pnpm dev
```

## Branch Strategy

```
main        — production ready, protected
dev         — integration branch, PRs merge here
feat/<n> — new feature
fix/<n>  — bug fix
chore/<n>— maintenance, deps, config
```

## Before Opening a PR

```bash
tsc --noEmit
pnpm lint
pnpm test
```

All three must pass with zero errors.

## Commit Format

[Conventional Commits](https://www.conventionalcommits.org/):

```
feat(module): add thing
fix(module): fix thing
chore: update deps
docs: update readme
refactor(module): extract helper
```

## License

MIT — contributions welcome.
