# PERFORMANCE.md — Performance Evaluation Tests

> Performance testing ≠ stress testing.
> Goal: establish a baseline and catch regressions before they reach production.
> Tool: k6 (Grafana). Run: `pnpm test:perf` before each release.

---

## What Performance Tests Are For

| Purpose | What it catches |
|---|---|
| Baseline measurement | "How fast is this endpoint today?" |
| Regression detection | "Did my last change make it slower?" |
| Index verification | "Does this query use the index I added?" |
| Memory leak detection | "Does memory grow unbounded under load?" |
| N+1 query detection | "Am I making 100 DB calls for 20 items?" |

They are NOT for:
- Finding the breaking point under extreme load (that's stress testing)
- Simulating DDoS attacks
- Capacity planning (different tool: wrk or locust)

---

## N+1 Query Prevention — Most Important Performance Rule

The most common performance bug in Prisma apps. Always use `include` or `select` to fetch relations, never loop and query.

```typescript
// WRONG — N+1: 1 query for notes + N queries for tags
const notes = await prisma.note.findMany({ where: { userId } })
for (const note of notes) {
  note.tags = await prisma.tagEntity.findMany({ where: { entityId: note.id } })
}

// CORRECT — 2 queries total regardless of note count
const notes = await prisma.note.findMany({
  where: { userId },
  include: {
    tags: {
      include: { tag: { select: { id: true, name: true, color: true } } }
    }
  },
})

// ALSO CORRECT — using select for better control
const notes = await prisma.note.findMany({
  where: { userId },
  select: {
    id: true, title: true, isPinned: true, createdAt: true, updatedAt: true,
    tags: {
      select: { tag: { select: { id: true, name: true, color: true } } }
    }
  },
})
```

### Detecting N+1 in tests

```typescript
// Install: pnpm add -D prisma-query-inspector (or use Prisma's built-in logging)
// apps/api/src/lib/prisma.ts (test mode)
const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'test'
    ? [{ emit: 'event', level: 'query' }]
    : [],
})

// In integration tests:
it('list notes uses at most 2 DB queries', async () => {
  const queries: string[] = []
  prisma.$on('query', (e) => queries.push(e.query))

  await app.inject({
    method: 'GET', url: '/api/v1/notes?limit=20',
    headers: { authorization: `Bearer ${token}` },
  })

  // Should be: 1 for notes + 1 for tags (via JOIN) = 2 max
  expect(queries.length).toBeLessThanOrEqual(2)
})
```

---

## Required PostgreSQL Indexes

These must exist — verify with `EXPLAIN ANALYZE` that they are used:

```prisma
// Already in schema — confirm before any list query
@@index([userId])                       // every table — all user-scoped queries
@@index([userId, deletedAt])            // soft-delete filter
@@index([userId, status])               // tasks filtered by status
@@index([userId, dueDate])              // tasks sorted by due date
@@index([userId, folderId])             // notes by folder
@@index([scheduledAt, status])          // reminders: find pending in time range

// Full-text search index (run manually in migration)
// CREATE INDEX notes_search_idx ON notes USING GIN(to_tsvector('english', title || ' ' || content::text));
```

### Checking index usage

```sql
-- Run in Prisma Studio or psql
EXPLAIN ANALYZE
SELECT * FROM notes
WHERE user_id = 'cuid_123'
  AND deleted_at IS NULL
ORDER BY updated_at DESC
LIMIT 20;

-- Look for: "Index Scan using..." — good
-- Avoid: "Seq Scan" — missing index, add one
```

---

## k6 Test Scenarios

### Scenario 1: Baseline (runs on every release)

```javascript
// tests/performance/baseline.k6.js
export const options = {
  scenarios: {
    baseline: {
      executor: 'constant-vus',
      vus: 10,          // 10 concurrent users
      duration: '60s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<200'],   // p95 under 200ms
    http_req_failed: ['rate<0.01'],     // less than 1% errors
  },
}
```

### Scenario 2: Ramp-up (pre-release only)

```javascript
export const options = {
  stages: [
    { duration: '30s', target: 10 },   // ramp up to 10 users
    { duration: '60s', target: 50 },   // ramp up to 50 users
    { duration: '30s', target: 0 },    // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],   // more lenient under load
    http_req_failed: ['rate<0.05'],
  },
}
```

### Scenario 3: Soak test (weekly only — detects memory leaks)

```javascript
export const options = {
  scenarios: {
    soak: {
      executor: 'constant-vus',
      vus: 5,
      duration: '30m',    // 30 minutes — memory leaks show up over time
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.01'],
  },
}
```

---

## Performance Acceptance Thresholds

| Endpoint | p95 | p99 | Error rate |
|---|---|---|---|
| `GET /notes` (20 items) | < 100ms | < 200ms | < 0.1% |
| `POST /notes` | < 150ms | < 300ms | < 0.1% |
| `PUT /notes/:id` | < 150ms | < 300ms | < 0.1% |
| `DELETE /notes/:id` | < 100ms | < 200ms | < 0.1% |
| `GET /tasks` | < 100ms | < 200ms | < 0.1% |
| Full-text search | < 300ms | < 500ms | < 0.1% |
| `POST /auth/login` | < 300ms | < 500ms | < 0.1% |
| File upload (5MB PDF) | < 2000ms | < 5000ms | < 1% |

If a threshold fails: check EXPLAIN ANALYZE, check for N+1, check missing indexes. Do not raise the threshold to make the test pass.

---

## Monitoring in Production (Hetzner VPS)

```bash
# Install on VPS: Prometheus + Grafana + Node Exporter
# Or simpler: use Hetzner's built-in metrics + Sentry for application errors

# Key metrics to watch:
# - API response time p95 (alert if > 500ms)
# - PostgreSQL: slow queries > 100ms (enable pg_stat_statements)
# - Redis: memory usage (alert if > 200MB)
# - CPU: alert if > 80% sustained
# - Disk: alert if > 75% (Docker volumes grow)

# Fastify plugin for Prometheus metrics:
# @fastify/metrics — exposes /metrics endpoint for Prometheus scraping
```

---

## Running Performance Tests Locally

```bash
# Install k6: https://k6.io/docs/get-started/installation/
# macOS: brew install k6

# Run baseline (requires dev server running)
pnpm dev &
k6 run tests/performance/baseline.k6.js \
  -e API_URL=http://localhost:4000 \
  -e TEST_EMAIL=perf@test.com \
  -e TEST_PASSWORD=PerfTest1234!

# View results in terminal — look for thresholds: ✓ or ✗
# Failed threshold = regression introduced by recent changes
```
