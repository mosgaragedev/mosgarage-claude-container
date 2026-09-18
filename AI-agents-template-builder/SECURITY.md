# SECURITY.md — LifeOps Security Requirements

> This file is read by Claude Code alongside CLAUDE.md for every session.
> Every rule here is mandatory. Security is not optional or "nice to have".
> When in doubt: reject the input, return 400, log the attempt.

---

## Security Philosophy

**Assume every user is hostile until proven otherwise.**
- Validate every input — even from authenticated users
- Deny by default — if a rule doesn't explicitly allow it, deny it
- Fail closed — on error, reject the request; never silently pass
- Least privilege — every DB query filters by `userId`; no global queries
- Defense in depth — multiple layers, no single point of failure

---

## Layer 1 — Input Validation (Always On)

### Rule: All inputs validated with Zod before any business logic runs.

```typescript
// Pattern for every Fastify route — no exceptions
import { z } from 'zod'

const CreateNoteSchema = z.object({
  title: z.string().min(1).max(255).trim(),
  content: z.unknown(),                        // validated separately by Tiptap sanitizer
  folderId: z.string().cuid().optional(),
  tagIds: z.array(z.string().cuid()).max(20).optional(),
})

// In route handler:
const body = CreateNoteSchema.safeParse(request.body)
if (!body.success) {
  return reply.code(400).send({
    error: 'Validation failed',
    code: 'VALIDATION_ERROR',
    details: body.error.flatten(),
  })
}
// Now use body.data — it is typed and safe
```

### String field rules

| Field type | Max length | Additional rules |
|---|---|---|
| Title / name | 255 | `.trim()` — strip leading/trailing whitespace |
| Description / note | 10,000 | `.trim()` |
| Rich text (Tiptap JSON) | 5MB | Sanitize with `@tiptap/extension-sanitize` before storage |
| Email | 254 | `z.string().email()` |
| Password | 72 | min 8, max 72 (bcrypt limit) |
| URL | 2048 | `z.string().url()` |
| CUID / ID | — | `z.string().cuid()` — never `.string()` alone for IDs |
| Enum values | — | `z.enum([...])` — never raw string for status/type fields |
| File name | 255 | Sanitize: strip `../`, `./`, null bytes, special chars |

### Numbers

```typescript
// Always bound numeric ranges — never accept unbounded numbers
z.number().int().min(1).max(100)   // pagination limit
z.number().int().min(0)             // position/order
z.number().finite()                 // never NaN or Infinity
```

### Dates

```typescript
// Always validate date strings before parsing
z.string().datetime()               // ISO 8601 format enforced
// Then in business logic: new Date(validated.scheduledAt)
// Never: new Date(request.body.anything)
```

---

## Layer 2 — Authentication & Authorization

### JWT Verification (every protected route)

```typescript
// apps/api/src/middleware/auth.ts
// NEVER trust request.body or query params for user identity
// ONLY trust the verified JWT payload

const verifyToken = (token: string) => {
  try {
    return jwt.verify(token, process.env.JWT_ACCESS_SECRET!) as JwtPayload
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) throw new UnauthorizedError('TOKEN_EXPIRED')
    if (err instanceof jwt.JsonWebTokenError) throw new UnauthorizedError('INVALID_TOKEN')
    throw new UnauthorizedError('TOKEN_ERROR')
  }
}
```

### Authorization — IDOR Prevention

**IDOR (Insecure Direct Object Reference)** is the #1 vulnerability for personal apps.
It means user A accesses user B's data by guessing an ID.

```typescript
// WRONG — vulnerable to IDOR
const note = await prisma.note.findUnique({ where: { id: params.id } })

// CORRECT — always filter by userId from JWT, never from request
const note = await prisma.note.findUnique({
  where: {
    id: params.id,
    userId: request.user.id,   // from verified JWT — not from body/query
    deletedAt: null,
  },
})
if (!note) {
  // Return 404, not 403 — don't reveal that the resource exists
  return reply.code(404).send({ error: 'Not found', code: 'NOTE_NOT_FOUND' })
}
```

**Every single Prisma query that touches user data MUST include `userId: request.user.id`.**
Run the security test suite (`pnpm test:security`) to verify this automatically.

### Password Handling

```typescript
// Hashing — bcrypt cost 12 (never lower)
const hash = await bcrypt.hash(password, 12)

// Comparing — always use timingSafeEqual pattern via bcrypt
const valid = await bcrypt.compare(password, user.password)

// NEVER:
// - Store plain text passwords
// - Use MD5 or SHA1 for passwords
// - Return password hash in any API response
// - Log passwords even partially
```

### Refresh Token Security

```typescript
// Tokens are random bytes — store only the hash
const rawToken = crypto.randomBytes(64).toString('hex')
const hashedToken = await bcrypt.hash(rawToken, 10)  // cost 10 is fine for refresh tokens

// Store hashedToken in DB, return rawToken to client
// On verification: bcrypt.compare(incomingRaw, storedHash)

// Rotation: every /auth/refresh call MUST:
// 1. Verify the incoming token against DB hash
// 2. Delete the old session record
// 3. Create a new session with a new token pair
// 4. If token is already used (not found): invalidate ALL sessions for that user (theft indicator)
```

---

## Layer 3 — HTTP Security Headers

### Required headers (configured in Fastify via `@fastify/helmet`)

```typescript
// apps/api/src/app.ts
import helmet from '@fastify/helmet'

await fastify.register(helmet, {
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],  // needed for Tiptap
      imgSrc: ["'self'", 'data:', 'https:'],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: false,  // needed for some file previews
})
```

Headers that must be present in every response:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Strict-Transport-Security: max-age=31536000` (HTTPS only)
- `Referrer-Policy: strict-origin-when-cross-origin`

---

## Layer 4 — Rate Limiting

```typescript
// apps/api/src/app.ts
import rateLimit from '@fastify/rate-limit'

// Global: 100 req/min per user (or IP if not authenticated)
await fastify.register(rateLimit, {
  max: 100,
  timeWindow: '1 minute',
  keyGenerator: (req) => req.user?.id ?? req.ip,
})

// Strict: auth endpoints
// Applied in apps/api/src/routes/auth/login.ts
const strictLimit = {
  max: 5,
  timeWindow: '15 minutes',
  errorResponseBuilder: () => ({
    error: 'Too many attempts. Try again in 15 minutes.',
    code: 'RATE_LIMIT_EXCEEDED',
  }),
}
```

Rate limits by endpoint:
| Endpoint | Limit | Window |
|---|---|---|
| `POST /auth/login` | 5 | 15 min |
| `POST /auth/register` | 3 | 1 hour |
| `POST /auth/forgot-password` | 3 | 1 hour |
| `POST /auth/refresh` | 10 | 15 min |
| All other routes | 100 | 1 min |
| File upload | 20 | 1 hour |
| AI endpoints | 10 | 1 hour |

---

## Layer 5 — File Upload Security

```typescript
// apps/api/src/routes/documents/upload.ts

const ALLOWED_MIME_TYPES = new Set([
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'image/jpeg', 'image/png', 'image/webp', 'image/gif',
  'text/plain', 'text/markdown',
])

const MAX_FILE_SIZE = 50 * 1024 * 1024  // 50MB

// Validation on upload:
// 1. Check Content-Length header against MAX_FILE_SIZE before reading body
// 2. Check MIME type against allowlist (from magic bytes, not just extension)
// 3. Sanitize filename: strip path traversal, null bytes, special chars
// 4. Generate new UUID-based filename — never use user-supplied filename in storage
// 5. Virus scanning: if enabled, scan before committing to storage

const sanitizeFilename = (name: string): string => {
  return name
    .replace(/[^\w\s.-]/g, '')   // remove special chars
    .replace(/\.\./g, '')          // remove path traversal
    .replace(/^\./, '')            // remove leading dot
    .trim()
    .slice(0, 255)
}

// File storage: always private, never public URLs
// Serve via signed URLs with 1-hour expiry
// Never serve files directly from your domain without auth check
```

---

## Layer 6 — Database Security

```typescript
// ALWAYS use Prisma parameterized queries — never string concatenation
// CORRECT:
prisma.note.findMany({ where: { title: { contains: userInput } } })

// NEVER (SQL injection):
prisma.$queryRawUnsafe(`SELECT * FROM notes WHERE title LIKE '%${userInput}%'`)

// If you MUST use raw SQL (e.g. full-text search), use tagged template:
prisma.$queryRaw`SELECT * FROM notes WHERE to_tsvector(title) @@ to_tsquery(${userInput})`

// Sensitive fields — NEVER return in API responses:
// password, totpSecret, refreshToken hashes, internalId fields
// Use Prisma select to explicitly exclude:
prisma.user.findUnique({
  where: { id },
  select: { id: true, email: true, name: true, avatarUrl: true }
  // password and totpSecret NOT selected
})
```

---

## Layer 7 — CORS Configuration

```typescript
// apps/api/src/app.ts
import cors from '@fastify/cors'

const allowedOrigins = process.env.NODE_ENV === 'production'
  ? [process.env.NEXT_PUBLIC_APP_URL!]      // only your frontend domain
  : ['http://localhost:3000']                 // dev only

await fastify.register(cors, {
  origin: allowedOrigins,
  credentials: true,                          // needed for cookies
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
})
// NEVER: origin: true or origin: '*' in production
```

---

## Layer 8 — Logging & Monitoring

```typescript
// What to LOG (Pino logger):
// - Auth failures: userId attempt, IP, timestamp
// - Rate limit hits: IP, endpoint
// - Validation failures: endpoint (NOT the invalid data — it may contain PII)
// - 5xx errors: full stack trace (server-side only, never in response)
// - File upload events: userId, filename (sanitized), size
// - Admin operations: userId, action, target

// What NEVER to log:
// - Passwords (even hashed)
// - JWT tokens
// - Request body (may contain passwords, personal data)
// - PII fields: email in logs only when essential
// - Refresh tokens

// Log format (structured JSON):
logger.warn({
  event: 'auth.login.failed',
  ip: request.ip,
  userAgent: request.headers['user-agent'],
  timestamp: new Date().toISOString(),
})
// NEVER: logger.warn(`Login failed for ${email}`) — email in log string
```

---

## Security Checklist — Before Every Release

Run `pnpm test:security` and verify all pass. Also manually check:

- [ ] All new routes have auth middleware applied
- [ ] All new Prisma queries include `userId` filter
- [ ] No new `console.log` with user data
- [ ] No new environment variables committed
- [ ] No new dependencies with known CVEs (`pnpm audit`)
- [ ] New file upload types added to allowlist if needed
- [ ] Rate limits applied to any new public endpoints
- [ ] Error messages don't leak internal paths or stack traces

---

## Known Attack Vectors — Quick Reference

| Attack | Where it happens | Defence in LifeOps |
|---|---|---|
| SQL Injection | Search, filters | Prisma parameterized queries |
| XSS | Tiptap notes, user names | Tiptap sanitizer + CSP headers |
| IDOR | All CRUD endpoints | `userId` filter on every query |
| CSRF | State-changing requests | SameSite=Strict cookies + CORS |
| Brute force | Login, password reset | Rate limiting per IP |
| JWT forgery | All protected routes | `jwt.verify()` with strong secret |
| Path traversal | File uploads | Filename sanitization + UUID rename |
| Mass assignment | Create/update endpoints | Zod schema picks fields explicitly |
| Token theft | Refresh token reuse | Refresh token rotation + detect reuse |
| Timing attacks | Password compare | `bcrypt.compare()` always |
| Enumeration | 404 vs 403 responses | Always return 404 for not-found/forbidden |
