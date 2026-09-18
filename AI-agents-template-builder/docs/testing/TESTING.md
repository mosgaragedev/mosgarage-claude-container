# TESTING.md — LifeOps Testing Strategy

> Agent instruction file. Read this before writing any test.
> All five test layers are mandatory. Do not skip layers.

---

## Test Stack

| Layer | Tool | Location | Run command |
|---|---|---|---|
| Unit + Validation | Vitest | `*.test.ts` colocated | `pnpm test:unit` |
| Integration | Vitest + supertest | `*.integration.test.ts` | `pnpm test:integration` |
| Security | Custom Vitest suite | `tests/security/` | `pnpm test:security` |
| Adversarial | Vitest + fast-check | `tests/adversarial/` | `pnpm test:adversarial` |
| Performance | k6 | `tests/performance/` | `pnpm test:perf` |
| All (CI) | — | — | `pnpm test` |

---

## Layer 1 — Unit Tests + Validation Loops

### What to test

Every function that:
- Transforms data
- Validates input (Zod schemas)
- Computes a value (date calculations, position/ordering)
- Has branching logic

### Validation loop pattern

"Validation loop" means: test that Zod rejects bad data AND accepts good data for every schema.
This prevents schema drift where a field becomes optional accidentally.

```typescript
// packages/types/src/notes.schema.test.ts
import { describe, it, expect } from 'vitest'
import { CreateNoteSchema } from './notes.schema'

describe('CreateNoteSchema', () => {
  // Valid cases
  it('accepts valid note with title only', () => {
    const result = CreateNoteSchema.safeParse({ title: 'My note' })
    expect(result.success).toBe(true)
  })

  it('accepts note with all optional fields', () => {
    const result = CreateNoteSchema.safeParse({
      title: 'Note',
      folderId: 'cuid_abc123',
      tagIds: ['cuid_tag1', 'cuid_tag2'],
    })
    expect(result.success).toBe(true)
  })

  // Invalid cases — one test per rule
  it('rejects empty title', () => {
    const result = CreateNoteSchema.safeParse({ title: '' })
    expect(result.success).toBe(false)
    expect(result.error?.issues[0].path).toContain('title')
  })

  it('rejects title over 255 chars', () => {
    const result = CreateNoteSchema.safeParse({ title: 'a'.repeat(256) })
    expect(result.success).toBe(false)
  })

  it('rejects invalid cuid for folderId', () => {
    const result = CreateNoteSchema.safeParse({ title: 'Note', folderId: 'not-a-cuid' })
    expect(result.success).toBe(false)
  })

  it('rejects more than 20 tags', () => {
    const result = CreateNoteSchema.safeParse({
      title: 'Note',
      tagIds: Array(21).fill('cuid_tag'),
    })
    expect(result.success).toBe(false)
  })

  it('strips whitespace from title', () => {
    const result = CreateNoteSchema.safeParse({ title: '  My note  ' })
    expect(result.success).toBe(true)
    expect(result.data?.title).toBe('My note')
  })
})
```

### Coverage requirements

- All Zod schemas: 100% — every field validated, every constraint tested
- Utility functions: 100%
- Service layer functions: 80% minimum
- Run `pnpm test:unit --coverage` and fail build if below thresholds

---

## Layer 2 — Integration Tests

### What to test

Every API route end-to-end: auth → route → DB → response.
Use a real test database (separate from dev) reset before each test file.

### Setup pattern

```typescript
// tests/integration/setup.ts
import { execSync } from 'child_process'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient({
  datasourceUrl: process.env.TEST_DATABASE_URL,
})

export const cleanDb = async () => {
  // Delete in reverse dependency order
  await prisma.$transaction([
    prisma.tagEntity.deleteMany(),
    prisma.tag.deleteMany(),
    prisma.note.deleteMany(),
    prisma.task.deleteMany(),
    prisma.reminder.deleteMany(),
    prisma.session.deleteMany(),
    prisma.user.deleteMany(),
  ])
}

export const createTestUser = async () => {
  return prisma.user.create({
    data: {
      email: `test-${Date.now()}@example.com`,
      password: await bcrypt.hash('Test1234!', 12),
      name: 'Test User',
    },
  })
}

export const loginUser = async (app: FastifyInstance, user: User) => {
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    payload: { email: user.email, password: 'Test1234!' },
  })
  return JSON.parse(res.body).accessToken as string
}
```

### Route test pattern

```typescript
// apps/api/src/routes/notes/notes.integration.test.ts
import { describe, it, expect, beforeEach, afterAll } from 'vitest'
import { buildApp } from '../../app'
import { cleanDb, createTestUser, loginUser } from '../../../tests/integration/setup'

describe('Notes API', () => {
  let app: FastifyInstance
  let token: string
  let userId: string

  beforeEach(async () => {
    app = await buildApp()
    await cleanDb()
    const user = await createTestUser()
    userId = user.id
    token = await loginUser(app, user)
  })

  afterAll(async () => {
    await app.close()
  })

  describe('POST /api/v1/notes', () => {
    it('creates a note and returns 201', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/api/v1/notes',
        headers: { authorization: `Bearer ${token}` },
        payload: { title: 'My note', content: {} },
      })
      expect(res.statusCode).toBe(201)
      const body = JSON.parse(res.body)
      expect(body.id).toBeDefined()
      expect(body.title).toBe('My note')
      expect(body.userId).toBeUndefined()      // NEVER return userId
      expect(body.deletedAt).toBeUndefined()   // NEVER return deletedAt
    })

    it('returns 401 without token', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/api/v1/notes',
        payload: { title: 'Note' },
      })
      expect(res.statusCode).toBe(401)
    })

    it('returns 400 for empty title', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/api/v1/notes',
        headers: { authorization: `Bearer ${token}` },
        payload: { title: '' },
      })
      expect(res.statusCode).toBe(400)
      const body = JSON.parse(res.body)
      expect(body.code).toBe('VALIDATION_ERROR')
    })
  })

  describe('GET /api/v1/notes/:id', () => {
    it('cannot access another user\'s note (IDOR check)', async () => {
      // Create note as user1
      const createRes = await app.inject({
        method: 'POST',
        url: '/api/v1/notes',
        headers: { authorization: `Bearer ${token}` },
        payload: { title: 'Private note' },
      })
      const noteId = JSON.parse(createRes.body).id

      // Create user2 and try to access user1's note
      const user2 = await createTestUser()
      const token2 = await loginUser(app, user2)

      const res = await app.inject({
        method: 'GET',
        url: `/api/v1/notes/${noteId}`,
        headers: { authorization: `Bearer ${token2}` },
      })
      // Must be 404, not 403 (don't reveal existence)
      expect(res.statusCode).toBe(404)
    })
  })
})
```

### Required integration tests per route

Every route must test:
- [ ] Happy path (201/200 with correct response shape)
- [ ] Missing auth (401)
- [ ] Invalid input (400 with VALIDATION_ERROR)
- [ ] Not found (404 — both truly missing and wrong user)
- [ ] IDOR: other user cannot access this resource (404)
- [ ] Soft delete: deleted resources not returned in list

---

## Layer 3 — Security Tests

```typescript
// tests/security/auth.security.test.ts
describe('Security: Auth routes', () => {

  it('rejects expired JWT', async () => {
    const expiredToken = jwt.sign(
      { sub: userId, email: 'test@test.com' },
      process.env.JWT_ACCESS_SECRET!,
      { expiresIn: '-1s' }  // already expired
    )
    const res = await app.inject({
      method: 'GET', url: '/api/v1/notes',
      headers: { authorization: `Bearer ${expiredToken}` },
    })
    expect(res.statusCode).toBe(401)
    expect(JSON.parse(res.body).code).toBe('TOKEN_EXPIRED')
  })

  it('rejects JWT signed with wrong secret', async () => {
    const forgedToken = jwt.sign({ sub: userId }, 'wrong-secret')
    const res = await app.inject({
      method: 'GET', url: '/api/v1/notes',
      headers: { authorization: `Bearer ${forgedToken}` },
    })
    expect(res.statusCode).toBe(401)
  })

  it('rejects JWT with tampered payload', async () => {
    // Sign legit token, then tamper with payload
    const parts = token.split('.')
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString())
    payload.sub = 'different-user-id'  // tamper
    parts[1] = Buffer.from(JSON.stringify(payload)).toString('base64url')
    const tampered = parts.join('.')
    const res = await app.inject({
      method: 'GET', url: '/api/v1/notes',
      headers: { authorization: `Bearer ${tampered}` },
    })
    expect(res.statusCode).toBe(401)
  })

  it('enforces rate limit on login after 5 attempts', async () => {
    for (let i = 0; i < 5; i++) {
      await app.inject({
        method: 'POST', url: '/api/v1/auth/login',
        payload: { email: 'test@test.com', password: 'WrongPassword1!' },
      })
    }
    const res = await app.inject({
      method: 'POST', url: '/api/v1/auth/login',
      payload: { email: 'test@test.com', password: 'WrongPassword1!' },
    })
    expect(res.statusCode).toBe(429)
  })

  it('returns 404 (not 403) when accessing another user\'s resource', async () => {
    // See IDOR test in integration layer — must be 404
  })

  it('does not return sensitive fields in any user response', async () => {
    const res = await app.inject({
      method: 'GET', url: '/api/v1/auth/me',
      headers: { authorization: `Bearer ${token}` },
    })
    const body = JSON.parse(res.body)
    expect(body.password).toBeUndefined()
    expect(body.totpSecret).toBeUndefined()
    expect(body.refreshToken).toBeUndefined()
  })

  it('has required security headers on all responses', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/health' })
    expect(res.headers['x-content-type-options']).toBe('nosniff')
    expect(res.headers['x-frame-options']).toBe('DENY')
    expect(res.headers['x-xss-protection']).toBeDefined()
  })

  it('rejects XSS in note title', async () => {
    const res = await app.inject({
      method: 'POST', url: '/api/v1/notes',
      headers: { authorization: `Bearer ${token}` },
      payload: { title: '<script>alert("xss")</script>' },
    })
    // Either 400 (rejected) or 201 with sanitized title — never raw script tag stored
    if (res.statusCode === 201) {
      const body = JSON.parse(res.body)
      expect(body.title).not.toContain('<script>')
    } else {
      expect(res.statusCode).toBe(400)
    }
  })
})
```

---

## Layer 4 — Adversarial Tests

Adversarial tests simulate a malicious or broken client.

```typescript
// tests/adversarial/fuzz.adversarial.test.ts
import { describe, it, expect } from 'vitest'
import fc from 'fast-check'  // property-based testing

describe('Adversarial: note creation', () => {

  // Property: any string title should never crash the server (400 or 201, never 500)
  it('never returns 500 for any string input as title', async () => {
    await fc.assert(
      fc.asyncProperty(fc.string(), async (randomTitle) => {
        const res = await app.inject({
          method: 'POST', url: '/api/v1/notes',
          headers: { authorization: `Bearer ${token}` },
          payload: { title: randomTitle },
        })
        expect(res.statusCode).not.toBe(500)
      }),
      { numRuns: 200 }
    )
  })

  // Specific adversarial payloads
  const maliciousPayloads = [
    null,
    undefined,
    '',
    ' ',
    'a'.repeat(10000),                         // length bomb
    '\x00\x01\x02',                             // null bytes
    '../../../etc/passwd',                       // path traversal
    '<script>alert(1)</script>',                 // XSS
    "'; DROP TABLE notes; --",                   // SQL injection attempt
    '{"__proto__":{"admin":true}}',              // prototype pollution
    '\uFFFD\uD800\uDFFF',                        // invalid unicode
    '𝕳𝖊𝖑𝖑𝖔',                                   // unicode normalization
    Array(1000).fill('a').join(''),              // large string
    { nested: { object: 'not a string' } },      // wrong type
  ]

  it.each(maliciousPayloads)('handles malicious title: %s', async (payload) => {
    const res = await app.inject({
      method: 'POST', url: '/api/v1/notes',
      headers: { authorization: `Bearer ${token}` },
      payload: { title: payload },
    })
    // Must be 400 (rejected) or 201 (sanitized) — never 500
    expect([400, 201, 422]).toContain(res.statusCode)
  })
})

describe('Adversarial: pagination', () => {
  it('handles extreme pagination values', async () => {
    const cases = [
      { limit: -1 }, { limit: 0 }, { limit: 999999 },
      { limit: 'abc' }, { cursor: 'not-a-cuid' },
      { limit: null }, { limit: Infinity }, { limit: NaN },
    ]
    for (const query of cases) {
      const res = await app.inject({
        method: 'GET', url: '/api/v1/notes',
        headers: { authorization: `Bearer ${token}` },
        query: query as any,
      })
      expect([200, 400]).toContain(res.statusCode)
      expect(res.statusCode).not.toBe(500)
    }
  })
})

describe('Adversarial: mass assignment', () => {
  it('cannot set userId via request body', async () => {
    const otherUserId = 'some-other-user-id'
    const res = await app.inject({
      method: 'POST', url: '/api/v1/notes',
      headers: { authorization: `Bearer ${token}` },
      payload: { title: 'Note', userId: otherUserId },  // trying to set userId
    })
    if (res.statusCode === 201) {
      const body = JSON.parse(res.body)
      // Note must belong to authenticated user, not the injected userId
      const note = await prisma.note.findUnique({ where: { id: body.id } })
      expect(note?.userId).not.toBe(otherUserId)
      expect(note?.userId).toBe(userId)
    }
  })
})
```

---

## Layer 5 — Performance Evaluation Tests

```javascript
// tests/performance/notes.k6.js
import http from 'k6/http'
import { check, sleep } from 'k6'
import { Rate, Trend } from 'k6/metrics'

const errorRate = new Rate('errors')
const noteCreateDuration = new Trend('note_create_duration')

export const options = {
  scenarios: {
    // Baseline: steady 10 users for 30s
    baseline: {
      executor: 'constant-vus',
      vus: 10,
      duration: '30s',
    },
  },
  thresholds: {
    // All thresholds must pass for the test to succeed
    http_req_duration: ['p(95)<200'],    // 95th percentile under 200ms
    http_req_failed: ['rate<0.01'],      // less than 1% errors
    errors: ['rate<0.01'],
    note_create_duration: ['p(99)<500'], // 99th percentile creates under 500ms
  },
}

const BASE_URL = __ENV.API_URL || 'http://localhost:4000'

export function setup() {
  // Login once and return token for all VUs
  const res = http.post(`${BASE_URL}/api/v1/auth/login`, JSON.stringify({
    email: 'perf-test@example.com',
    password: 'PerfTest1234!',
  }), { headers: { 'Content-Type': 'application/json' } })
  return { token: JSON.parse(res.body).accessToken }
}

export default function (data) {
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${data.token}`,
  }

  // Test: list notes
  const listRes = http.get(`${BASE_URL}/api/v1/notes?limit=20`, { headers })
  check(listRes, {
    'list notes status 200': (r) => r.status === 200,
    'list notes under 200ms': (r) => r.timings.duration < 200,
  })
  errorRate.add(listRes.status !== 200)

  sleep(0.5)

  // Test: create note
  const start = Date.now()
  const createRes = http.post(`${BASE_URL}/api/v1/notes`,
    JSON.stringify({ title: `Perf test note ${Date.now()}`, content: {} }),
    { headers }
  )
  noteCreateDuration.add(Date.now() - start)
  check(createRes, {
    'create note status 201': (r) => r.status === 201,
  })
  errorRate.add(createRes.status !== 201)

  sleep(1)
}
```

### Performance acceptance criteria

| Endpoint | p95 target | p99 target |
|---|---|---|
| `GET /notes` (20 items) | < 100ms | < 200ms |
| `POST /notes` | < 150ms | < 300ms |
| `GET /notes/:id` | < 50ms | < 100ms |
| `PUT /notes/:id` | < 150ms | < 300ms |
| `POST /auth/login` | < 200ms | < 400ms |
| Search (full-text) | < 300ms | < 500ms |

If any threshold fails: run `EXPLAIN ANALYZE` on the slow query, add missing indexes, re-run.

---

## CI/CD Test Pipeline

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
      - run: pnpm install
      - run: pnpm test:unit --coverage
      - run: pnpm typecheck

  integration:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: lifeops_test
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        ports: ['5432:5432']
      redis:
        image: redis:7-alpine
        ports: ['6379:6379']
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
      - run: pnpm install
      - run: pnpm db:migrate
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/lifeops_test
      - run: pnpm test:integration
        env:
          TEST_DATABASE_URL: postgresql://test:test@localhost:5432/lifeops_test
          REDIS_URL: redis://localhost:6379
          JWT_ACCESS_SECRET: test-secret-32-chars-minimum-here
          JWT_REFRESH_SECRET: test-refresh-secret-32-chars-here

  security:
    runs-on: ubuntu-latest
    # Same services as integration
    steps:
      - run: pnpm test:security

  # Adversarial and performance run weekly, not on every push
  adversarial:
    runs-on: ubuntu-latest
    if: github.event_name == 'schedule'
    steps:
      - run: pnpm test:adversarial

  performance:
    runs-on: ubuntu-latest
    if: github.event_name == 'schedule'
    steps:
      - run: pnpm test:perf
```
