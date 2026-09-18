# ADVERSARIAL.md — Adversarial & Security Test Patterns

> Adversarial testing = deliberately acting like an attacker or broken client.
> The goal is to prove the app cannot be exploited, not just that it works correctly.
> Run: `pnpm test:adversarial` — weekly in CI, always before a release.

---

## What is Adversarial Testing?

Normal tests prove: "when given valid input, the app behaves correctly."
Adversarial tests prove: "when given malicious/broken input, the app does NOT break or leak data."

You are testing the **blast radius** of bad input.
The acceptance criterion is always: "the server returns 4xx, never 500, never leaks data."

---

## Attack Category 1 — IDOR (Insecure Direct Object Reference)

The most common vulnerability in personal apps. User A accesses User B's data by guessing IDs.

```typescript
// tests/adversarial/idor.adversarial.test.ts
describe('IDOR attacks', () => {

  let user1Token: string, user2Token: string
  let user1NoteId: string, user1TaskId: string

  beforeEach(async () => {
    // Setup two users
    const u1 = await createTestUser()
    const u2 = await createTestUser()
    user1Token = await loginUser(app, u1)
    user2Token = await loginUser(app, u2)

    // User1 creates resources
    const noteRes = await app.inject({
      method: 'POST', url: '/api/v1/notes',
      headers: { authorization: `Bearer ${user1Token}` },
      payload: { title: 'User1 private note' },
    })
    user1NoteId = JSON.parse(noteRes.body).id
  })

  // Test IDOR for every module's GET, PUT, DELETE endpoints
  const iderTargets = [
    { method: 'GET',    url: () => `/api/v1/notes/${user1NoteId}` },
    { method: 'PUT',    url: () => `/api/v1/notes/${user1NoteId}` },
    { method: 'DELETE', url: () => `/api/v1/notes/${user1NoteId}` },
  ]

  it.each(iderTargets)('$method $url cannot be accessed by user2', async ({ method, url }) => {
    const res = await app.inject({
      method: method as any,
      url: url(),
      headers: { authorization: `Bearer ${user2Token}` },
      payload: method === 'PUT' ? { title: 'Hacked' } : undefined,
    })
    expect(res.statusCode).toBe(404)  // 404, not 403 — don't reveal existence
  })
})
```

---

## Attack Category 2 — Mass Assignment

Trying to set fields that should only be set by the server.

```typescript
describe('Mass assignment attacks', () => {
  const forbiddenFields = [
    { userId: 'another-user-id' },
    { id: 'custom-id-i-want' },
    { createdAt: '2020-01-01' },
    { deletedAt: null },         // trying to un-delete
    { isPinned: true, userId: 'other' },
    { __proto__: { admin: true } },
    { constructor: { prototype: { admin: true } } },
  ]

  it.each(forbiddenFields)('ignores forbidden field: %j', async (extra) => {
    const res = await app.inject({
      method: 'POST', url: '/api/v1/notes',
      headers: { authorization: `Bearer ${token}` },
      payload: { title: 'Note', ...extra },
    })
    expect([200, 201, 400]).toContain(res.statusCode)
    if (res.statusCode === 201) {
      const body = JSON.parse(res.body)
      const note = await prisma.note.findUnique({ where: { id: body.id } })
      expect(note?.userId).toBe(userId)         // must be current user
      // id should be server-generated, not 'custom-id-i-want'
      if (extra.id) expect(note?.id).not.toBe(extra.id)
    }
  })
})
```

---

## Attack Category 3 — Injection Attacks

```typescript
describe('Injection attacks', () => {
  const injectionPayloads = [
    // SQL injection attempts
    "'; DROP TABLE notes; --",
    "' OR '1'='1",
    "1; SELECT * FROM users",
    "UNION SELECT password FROM users",

    // NoSQL injection (less relevant with Prisma but test anyway)
    '{"$gt": ""}',
    '{"$where": "1==1"}',

    // Template injection
    '{{7*7}}',
    '${7*7}',
    '<%= 7*7 %>',

    // Command injection (for file name fields)
    '; ls -la',
    '| cat /etc/passwd',
    '`whoami`',
  ]

  it.each(injectionPayloads)('note search handles injection: %s', async (payload) => {
    const res = await app.inject({
      method: 'GET', url: '/api/v1/notes',
      headers: { authorization: `Bearer ${token}` },
      query: { search: payload },
    })
    // Must return 200 (query executed safely and returned 0 results)
    // or 400 (rejected by validation)
    // NEVER 500 (which would indicate an unhandled error from the injection)
    expect([200, 400]).toContain(res.statusCode)
    expect(res.statusCode).not.toBe(500)
  })
})
```

---

## Attack Category 4 — File Upload Attacks

```typescript
describe('File upload attacks', () => {

  it('rejects files over 50MB', async () => {
    const largeFile = Buffer.alloc(51 * 1024 * 1024) // 51MB
    const res = await uploadFile(app, token, largeFile, 'large.pdf', 'application/pdf')
    expect(res.statusCode).toBe(413) // Payload Too Large
  })

  it('rejects disallowed MIME types', async () => {
    const exeContent = Buffer.from('MZ') // PE header
    const res = await uploadFile(app, token, exeContent, 'virus.exe', 'application/octet-stream')
    expect(res.statusCode).toBe(400)
  })

  it('sanitizes path traversal in filename', async () => {
    const res = await uploadFile(app, token, Buffer.from('content'), '../../../etc/passwd', 'text/plain')
    if (res.statusCode === 201) {
      const body = JSON.parse(res.body)
      // Stored filename must not contain path traversal
      expect(body.filename).not.toContain('..')
      expect(body.filename).not.toContain('/')
    } else {
      expect(res.statusCode).toBe(400)
    }
  })

  it('user cannot access another user\'s file via direct URL', async () => {
    // Upload as user1, try to access as user2
    const uploadRes = await uploadFile(app, token, Buffer.from('secret'), 'doc.pdf', 'application/pdf')
    const fileId = JSON.parse(uploadRes.body).id

    const accessRes = await app.inject({
      method: 'GET', url: `/api/v1/documents/${fileId}`,
      headers: { authorization: `Bearer ${user2Token}` },
    })
    expect(accessRes.statusCode).toBe(404)
  })
})
```

---

## Attack Category 5 — Auth Attacks

```typescript
describe('Auth attacks', () => {

  it('refresh token can only be used once (rotation check)', async () => {
    // Login and get refresh token
    const loginRes = await app.inject({
      method: 'POST', url: '/api/v1/auth/login',
      payload: { email: user.email, password: 'Test1234!' },
    })
    const { refreshToken } = JSON.parse(loginRes.body)

    // Use refresh token once — succeeds
    const refresh1 = await app.inject({
      method: 'POST', url: '/api/v1/auth/refresh',
      payload: { refreshToken },
    })
    expect(refresh1.statusCode).toBe(200)

    // Use same refresh token again — must fail (rotation)
    const refresh2 = await app.inject({
      method: 'POST', url: '/api/v1/auth/refresh',
      payload: { refreshToken },
    })
    expect(refresh2.statusCode).toBe(401)
  })

  it('password reset token cannot be used twice', async () => {
    // Request reset
    await app.inject({
      method: 'POST', url: '/api/v1/auth/forgot-password',
      payload: { email: user.email },
    })
    const { token: resetToken } = await getLastResetToken(user.id)

    // Use once — succeeds
    const reset1 = await app.inject({
      method: 'POST', url: '/api/v1/auth/reset-password',
      payload: { token: resetToken, password: 'NewPassword1!' },
    })
    expect(reset1.statusCode).toBe(200)

    // Use again — must fail
    const reset2 = await app.inject({
      method: 'POST', url: '/api/v1/auth/reset-password',
      payload: { token: resetToken, password: 'AnotherPassword1!' },
    })
    expect(reset2.statusCode).toBe(401)
  })

  it('timing attack: login response time is consistent for valid vs invalid email', async () => {
    const iterations = 10

    const timesValidEmail = []
    const timesInvalidEmail = []

    for (let i = 0; i < iterations; i++) {
      const start = Date.now()
      await app.inject({
        method: 'POST', url: '/api/v1/auth/login',
        payload: { email: user.email, password: 'WrongPassword1!' },
      })
      timesValidEmail.push(Date.now() - start)

      const start2 = Date.now()
      await app.inject({
        method: 'POST', url: '/api/v1/auth/login',
        payload: { email: 'nonexistent@example.com', password: 'WrongPassword1!' },
      })
      timesInvalidEmail.push(Date.now() - start2)
    }

    const avgValid = timesValidEmail.reduce((a, b) => a + b) / iterations
    const avgInvalid = timesInvalidEmail.reduce((a, b) => a + b) / iterations

    // Response times should be within 100ms of each other
    // Large difference reveals whether email exists (timing oracle)
    expect(Math.abs(avgValid - avgInvalid)).toBeLessThan(100)
  })
})
```

---

## Attack Category 6 — Property-Based Fuzzing

```typescript
// tests/adversarial/fuzz.adversarial.test.ts
import fc from 'fast-check'

describe('Property-based: server never returns 500', () => {

  // Property: for any string inputs, server returns 4xx or 2xx, never 5xx
  const endpoints = [
    { method: 'GET', url: '/api/v1/notes', getQuery: fc.record({ search: fc.string(), limit: fc.integer() }) },
    { method: 'POST', url: '/api/v1/notes', getBody: fc.record({ title: fc.string(), folderId: fc.string() }) },
  ]

  for (const endpoint of endpoints) {
    it(`${endpoint.method} ${endpoint.url} never returns 500 on any input`, async () => {
      const arbitrary = endpoint.getBody ?? endpoint.getQuery ?? fc.constant({})

      await fc.assert(
        fc.asyncProperty(arbitrary, async (data) => {
          const res = await app.inject({
            method: endpoint.method as any,
            url: endpoint.url,
            headers: { authorization: `Bearer ${token}` },
            [endpoint.getBody ? 'payload' : 'query']: data,
          })
          return res.statusCode < 500
        }),
        { numRuns: 100, verbose: true }
      )
    })
  }
})
```

---

## Adversarial Test Checklist — Per Module

For each new module, add tests covering:

- [ ] IDOR: GET, PUT, DELETE with another user's IDs return 404
- [ ] Mass assignment: forbidden fields (userId, id, createdAt) ignored
- [ ] Injection: search/filter fields handle SQL injection payloads
- [ ] Boundary: pagination handles negative, zero, huge, NaN, Infinity values
- [ ] Unicode: titles handle null bytes, surrogates, emoji, RTL text
- [ ] Length bomb: very long strings are rejected (not truncated silently)
- [ ] Type confusion: string fields reject objects, arrays, null
- [ ] Fuzz: property-based test proves no 500s on random input
