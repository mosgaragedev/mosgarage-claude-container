# VALIDATION.md — Validation Loop Patterns

> What is a "validation loop"? It is the cycle of:
> Input arrives → Zod parses it → error returned if invalid → valid data passed to logic
> The "loop" refers to testing that cycle for EVERY schema, EVERY field, EVERY constraint.
> A broken validation loop means malformed data silently reaches your database.

---

## The Three Validation Points

Every piece of user data must be validated at three points:

```
Point 1: Frontend (react-hook-form + Zod)
  → Immediate UX feedback, prevents unnecessary API calls
  → NOT a security control — users can bypass this

Point 2: API boundary (Fastify route + Zod)
  → The real security control — server enforces shape and constraints
  → Must be present on EVERY route, no exceptions

Point 3: Database (Prisma schema constraints)
  → Last line of defense — catches bugs in application logic
  → @db.VarChar(255), NOT NULL, UNIQUE constraints
```

---

## Shared Schema Pattern

Schemas live in `packages/types/src/` and are imported by both frontend and API.
Never duplicate schemas — one schema, two importers.

```typescript
// packages/types/src/notes.schema.ts
import { z } from 'zod'

// Base shape used by both Create and Update
const NoteBase = z.object({
  title: z.string().min(1, 'Title is required').max(255).trim(),
  content: z.record(z.unknown()).optional(),
  folderId: z.string().cuid().nullable().optional(),
  tagIds: z.array(z.string().cuid()).max(20).optional(),
})

// Create: title required
export const CreateNoteSchema = NoteBase

// Update: all fields optional (PATCH semantics)
export const UpdateNoteSchema = NoteBase.partial()

// Query params for list endpoint
export const ListNotesQuerySchema = z.object({
  folderId: z.string().cuid().optional(),
  tagIds: z.string().optional(),         // comma-separated, split in handler
  isPinned: z.coerce.boolean().optional(),
  search: z.string().min(3).max(100).optional(),
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  sort: z.enum(['updatedAt', 'createdAt', 'title']).default('updatedAt'),
  order: z.enum(['asc', 'desc']).default('desc'),
})

// Response shape — what the API returns (used for type safety, not Zod validation)
export type NoteResponse = {
  id: string
  title: string
  content: Record<string, unknown>
  folderId: string | null
  isPinned: boolean
  tags: Array<{ id: string; name: string; color: string }>
  createdAt: string
  updatedAt: string
}

// Inferred TypeScript types
export type CreateNoteInput = z.infer<typeof CreateNoteSchema>
export type UpdateNoteInput = z.infer<typeof UpdateNoteSchema>
export type ListNotesQuery = z.infer<typeof ListNotesQuerySchema>
```

---

## API Route Validation Pattern

```typescript
// apps/api/src/routes/notes/create.ts
import { CreateNoteSchema } from '@lifeops/types'

export const createNoteRoute = async (fastify: FastifyInstance) => {
  fastify.post('/notes', async (request, reply) => {

    // Step 1: Validate body
    const parsed = CreateNoteSchema.safeParse(request.body)
    if (!parsed.success) {
      return reply.code(400).send({
        error: 'Validation failed',
        code: 'VALIDATION_ERROR',
        details: parsed.error.flatten().fieldErrors,
      })
    }

    // Step 2: Business logic with validated data (parsed.data is fully typed)
    const { title, content, folderId, tagIds } = parsed.data

    // Step 3: Validate referenced IDs exist and belong to user
    if (folderId) {
      const folder = await prisma.folder.findUnique({
        where: { id: folderId, userId: request.user.id },
      })
      if (!folder) {
        return reply.code(422).send({
          error: 'Folder not found',
          code: 'FOLDER_NOT_FOUND',
        })
      }
    }

    // Step 4: Write to DB
    const note = await prisma.note.create({
      data: {
        title,
        content: content ?? {},
        folderId: folderId ?? null,
        userId: request.user.id,  // ALWAYS from JWT, never from body
      },
      select: {
        id: true, title: true, content: true, folderId: true,
        isPinned: true, createdAt: true, updatedAt: true,
        // userId, deletedAt NOT selected
      },
    })

    return reply.code(201).send(note)
  })
}
```

---

## Frontend Validation Pattern

```typescript
// apps/web/src/app/(dashboard)/notes/components/NoteCreateForm.tsx
'use client'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { CreateNoteSchema, type CreateNoteInput } from '@lifeops/types'

export function NoteCreateForm() {
  const form = useForm<CreateNoteInput>({
    resolver: zodResolver(CreateNoteSchema),
    defaultValues: { title: '', tagIds: [] },
  })

  const onSubmit = async (data: CreateNoteInput) => {
    // data is fully typed and validated — safe to send to API
    await createNote(data)
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <input {...form.register('title')} />
      {form.formState.errors.title && (
        <p>{form.formState.errors.title.message}</p>
      )}
      <button type="submit">Create note</button>
    </form>
  )
}
```

---

## Common Validation Mistakes to Avoid

```typescript
// MISTAKE 1: Optional ID not validated as cuid
folderId: z.string().optional()          // accepts "../../etc" — BAD
folderId: z.string().cuid().optional()   // CORRECT

// MISTAKE 2: Number not coerced from query string
limit: z.number()                        // query params are always strings — fails
limit: z.coerce.number().int().max(100)  // CORRECT

// MISTAKE 3: Enum not restricted
status: z.string()                       // accepts "HACKED" — BAD
status: z.enum(['TODO','IN_PROGRESS','DONE','CANCELLED'])  // CORRECT

// MISTAKE 4: Missing trim on user strings
name: z.string().min(1)                  // "  " passes — BAD
name: z.string().min(1).trim()           // CORRECT

// MISTAKE 5: Not using safeParse
const data = schema.parse(body)          // throws — caught by Fastify as 500
const result = schema.safeParse(body)    // returns { success, data, error } — CORRECT
if (!result.success) return reply.code(400)...

// MISTAKE 6: Validating then re-accessing raw body
const result = schema.safeParse(body)
if (result.success) {
  const title = (body as any).title      // bypasses validated data — BAD
  const title = result.data.title        // CORRECT — use result.data always
}
```

---

## Validation Loop Test Checklist Per Schema

For every schema in `packages/types/src/`:

- [ ] Test valid minimum case (required fields only)
- [ ] Test valid maximum case (all optional fields populated)
- [ ] Test each required field: missing → 400
- [ ] Test each string field: empty string → 400
- [ ] Test each string field: max length + 1 → 400
- [ ] Test each string field: whitespace trimmed → data normalized
- [ ] Test each ID field: invalid cuid → 400
- [ ] Test each enum field: invalid value → 400
- [ ] Test each number field: below min → 400, above max → 400
- [ ] Test each date field: invalid format → 400
- [ ] Test arrays: over max length → 400, empty array → allowed if min(0)
- [ ] Test nested objects: invalid nested field → 400 with correct path
