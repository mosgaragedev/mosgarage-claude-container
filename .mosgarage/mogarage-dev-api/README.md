# MoGarage Dev — Control Plane API

An OpenAPI-first control-plane API for **MoGarage Dev**, a PaaS for
deploying and hosting applications. Manages teams, projects, environments,
deployments, environment variables, and custom domains — the same shape as
Vercel/Railway/Render's own APIs.

## Stack

- **Spec-first**: [`openapi.yaml`](./openapi.yaml) (OpenAPI 3.1) is the source
  of truth. Served live at `/docs` (Swagger UI) and `/openapi.json`.
- **Express + TypeScript** for the server
- **Zod** for request validation (errors map straight to OpenAPI 400 responses)
- **In-memory store** (`src/db/store.ts`) — one file to swap for a real DB
- **Vitest + Supertest** for tests
- **Docker** + docker-compose for containerized runs

## Domain model

```
Team ──< Project ──< Environment ──< Deployment
  │                        │
  │                        ├──< EnvVar
  │                        └──< Domain
  └──< TeamMember (User × Role)
```

- **Team** — top-level tenant/organization. Owns projects.
- **Project** — an app/repo. Creating one auto-provisions a `production`
  Environment.
- **Environment** — a deployable target within a project (`production`,
  `staging`, `preview-123`, ...). Holds env vars and domains.
- **Deployment** — one build+release of a project into an environment.
  Lifecycle: `queued → building → deploying → ready` (or `error` /
  `canceled`). In this reference implementation the lifecycle is *simulated*
  on a timer — wire `startDeploymentLifecycle` in `src/db/store.ts` to real
  build workers when you're ready.
- **EnvVar** — key/value pair scoped to an environment. Values are redacted
  in list/get responses; only echoed back once, on creation.
- **Domain** — custom hostname attached to an environment.

## Project layout

```
openapi.yaml            # API contract
src/
  index.ts              # entrypoint
  app.ts                # express app, middleware, swagger UI mount
  db/store.ts             # in-memory data layer + deployment lifecycle sim + seed data
  schemas/index.ts        # zod validation schemas
  middleware/             # auth + error handling
  routes/                 # one router per resource
tests/                    # vitest + supertest integration tests
```

## Getting started

```bash
npm install
cp .env.example .env
npm run dev
```

The server starts on `http://localhost:3000` with seed data already loaded
(one team, one project, production + staging environments, one in-flight
deployment):

- API base: `http://localhost:3000/api/v1`
- Interactive docs: `http://localhost:3000/docs`
- Raw spec: `http://localhost:3000/openapi.json`

Run tests:

```bash
npm test
```

Build & run for production:

```bash
npm run build
npm start
```

Or with Docker:

```bash
docker compose up --build
```

## Auth

Leave `API_TOKEN` blank in `.env` for local development (no auth enforced).
Set it to require `Authorization: Bearer <API_TOKEN>` on every `/api/v1/*`
route. Swap `src/middleware/auth.ts` for real JWT/OAuth verification (with
per-user identity resolution, since `/users/me` currently just returns the
seeded demo user) before shipping this anywhere real.

## Core flow

1. `POST /teams` → create a team
2. `POST /projects` (with `teamId`) → auto-creates a `production` environment
3. `POST /projects/:id/environments` → add `staging`, `preview-*`, etc.
4. `POST /environments/:id/env-vars` → configure secrets per environment
5. `POST /projects/:id/deployments` (with `environmentId`, `commitSha`) →
   queues a deployment; poll `GET /deployments/:id` (or `/logs`) as it
   progresses through `building` → `deploying` → `ready`
6. `POST /deployments/:id/promote` → mark a ready deployment as the
   environment's current one
7. `POST /environments/:id/domains` → attach a custom hostname

## Next steps you'll likely want

1. **Swap the store**: replace `src/db/store.ts` with Prisma/Postgres (the
   docker-compose file has a commented-out `db` service to get you started),
   keeping the same method signatures (`all`, `get`, `create`, `update`,
   `delete`) so routes don't need to change.
2. **Real auth + identity**: replace the bearer-token stub with JWT/OAuth2,
   and make `/users/me` resolve from the authenticated principal instead of
   returning the seed user.
3. **Real build/deploy workers**: replace the timer-based lifecycle
   simulation in `startDeploymentLifecycle` with actual triggers to your
   build system (queue a job, stream real logs, set the real preview URL).
4. **Generate a client/Postman collection** from `openapi.yaml` — any OpenAPI
   codegen tool, or Postman's "Import" on the file, will do it in one step.
5. **CI**: add a GitHub Actions workflow running `npm test` and validating
   `openapi.yaml` (e.g. with `@redocly/cli lint`) on every PR.
