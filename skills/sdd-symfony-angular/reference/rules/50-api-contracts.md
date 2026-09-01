# API Contracts — Symfony ↔ Angular

> **Layer 2 — Specific to backend/frontend integration.**

---

## Guiding principle

> The API contract is a **shared artifact** between backend and frontend. Every change must be tracked and synchronized on both sides.

Preferred format: **OpenAPI 3.x** (generated or hand-written, single source of truth).

---

## Required capability, discovered implementation

A machine-readable API contract with a typed, synchronized Angular boundary is a **required full-stack capability**. Its implementation is a set of **project facts** — discover, never assume:

- **OpenAPI provider**: NelmioApiDocBundle, API Platform, or another real provider already configured. Never mandate Nelmio where API Platform owns the contract, and never mandate API Platform where Nelmio owns it. A valid **project-owned hand-written OpenAPI document** designated as the source of truth is equally acceptable — provider absence alone is never a gap.
- **Serializer**: Symfony Serializer, JMS Serializer, API Platform serialization, other — never force Symfony Serializer groups into a JMS-based project.
- **Authentication**: discovered — JWT/Lexik is one common setup, not an assumption; session-based Symfony security is equally valid.
- **CORS implementation**: discovered — NelmioCorsBundle is the common Symfony example, not a given.
- **Contract location/URL, frontend generator and output directory**: discovered from the project's configuration, scripts and dependencies.
- **Roots**: `<backend-root>`/`<frontend-root>` below stand for the discovered directories — never assume `backend/`/`frontend/`.

If the backend exposes no machine-readable contract: **PROJECT_TOOLING_GAP**. If the contract exists but no automated frontend type/client synchronization does: **API_CONTRACT_AUTOMATION_GAP**. Both remain required targets, closed by dedicated tooling/contract tasks — never silently during an unrelated feature. The universal rules of this file (explicit schemas, typed frontend boundary, backend validation, no sensitive-field leakage, documented HTTP statuses, deliberate breaking changes, contract synchronization) apply regardless of providers.

---

## Toolchain (provider-specific examples and greenfield defaults)

### Symfony backend — Generate the OpenAPI

#### Option A — `nelmio/api-doc-bundle` (provider-specific example)

```bash
cd <backend-root>
composer require nelmio/api-doc-bundle   # greenfield setup
```

`config/packages/nelmio_api_doc.yaml` configuration:

```yaml
nelmio_api_doc:
  documentation:
    info:
      title: Application API
      description: API documentation
      version: 1.0.0
  areas:
    path_patterns:
      - ^/api(?!/doc)
```

Annotate the controllers:

```php
use OpenApi\Attributes as OA;

#[Route('/api/users/{id}', methods: ['GET'])]
#[OA\Response(
    response: 200,
    description: 'User found',
    content: new OA\JsonContent(ref: new Model(type: UserResponse::class))
)]
#[OA\Response(response: 404, description: 'User not found')]
final class GetUserController { ... }
```

Access the docs (URLs are project facts — a local greenfield default shown):
- HTML: `<backend-base-url>/api/doc`
- JSON: `<backend-base-url>/api/doc.json`

#### Option B — `api-platform/api-platform` (provider-specific example)

API Platform generates OpenAPI automatically and offers more features, but it structures the entire backend around its conventions. Worth considering for greenfield projects. On a project where API Platform already owns the contract, use its export — do not install Nelmio alongside it.

### Angular frontend — Generate the TypeScript types

Discover the existing generator dependency, package script, contract input and output directory first. Greenfield default:

```bash
cd <frontend-root>
npm install --save-dev @openapitools/openapi-generator-cli   # greenfield setup
```

Greenfield script in `package.json` (input/output are project facts):

```json
{
  "scripts": {
    "api:sync": "openapi-generator-cli generate -i <openapi-contract-location-or-url> -g typescript-angular -o <generated-output-dir> --additional-properties=supportsES6=true,withInterfaces=true"
  }
}
```

Usage:

```bash
npm run api:sync
```

Generates into the configured output directory (greenfield default `src/app/generated/api/`):
- TypeScript models (interfaces for each DTO)
- Angular services with typed methods for each endpoint

---

## Endpoint format

### Standard HTTP codes (mandatory)

| Code | Usage | Body |
|---|---|---|
| 200 | Successful read or update | Resource |
| 201 | Successful creation | Created resource |
| 204 | Successful deletion or operation without body | Empty |
| 400 | Malformed request | Error |
| 401 | Authentication required or failed | Error |
| 403 | Authenticated but not authorized | Error |
| 404 | Resource not found | Error |
| 409 | Conflict (e.g. email already in use) | Error |
| 422 | Validation failed | Error with violations |
| 500 | Internal server error | Generic error |

### Uniform error format

Every API error returns the same format:

```json
{
    "message": "Validation failed",
    "code": "VALIDATION_ERROR",
    "violations": [
        {
            "field": "email",
            "message": "Invalid email format"
        },
        {
            "field": "password",
            "message": "Must be at least 8 characters"
        }
    ]
}
```

### Verbs and URLs

| Action | Verb | URL |
|---|---|---|
| List | GET | `/api/users` |
| Fetch one | GET | `/api/users/{id}` |
| Create | POST | `/api/users` |
| Replace (full update) | PUT | `/api/users/{id}` |
| Partial update | PATCH | `/api/users/{id}` |
| Delete | DELETE | `/api/users/{id}` |

### Naming conventions

- ✅ Resources in **plural kebab-case**: `/api/order-lines`, `/api/user-roles`
- ✅ Path parameters as `{id}` or `{slug}` (descriptive)
- ✅ Query params in `camelCase`: `?sortBy=createdAt&order=desc`
- ✅ JSON body keys in `camelCase`

---

## Serialization — discovered serializer

The serializer is a **project fact**: Symfony Serializer, JMS Serializer, API Platform serialization, or another established one. The groups below are the **Symfony Serializer example** — a JMS-based project follows its established JMS annotations and exclusion policies instead; do not add Symfony groups there. Whatever the serializer, the universal rules hold: fine-grained control over exposure, no sensitive-field leakage, lighter list payloads.

### Group convention (Symfony Serializer example)

```php
#[ORM\Entity]
final class User
{
    #[Groups(['user:read', 'user:list'])]
    private int $id;

    #[Groups(['user:read', 'user:list', 'user:write'])]
    private string $email;

    #[Groups(['user:detail'])]
    private \DateTimeImmutable $createdAt;

    #[Groups(['user:write'])]  // never read
    private string $password;
}
```

Standard groups:
- `<entity>:read`: fields readable in responses
- `<entity>:write`: fields accepted in payloads
- `<entity>:list`: subset for lists (often fewer fields)
- `<entity>:detail`: superset for the detail view

Applied in the controller:

```php
return new JsonResponse(
    $this->serializer->serialize($user, 'json', ['groups' => ['user:read', 'user:detail']]),
    Response::HTTP_OK,
    [],
    true
);
```

### Benefits

- Fine-grained control over what is exposed
- Security: no accidental leak of sensitive fields (`password`, `secret_key`)
- Performance: lighter payload in list view

---

## API change workflow

### When an endpoint changes

1. **Update the SDD spec** first (Design section → Endpoint)
2. **Update the contract metadata via the discovered source mechanism** — Nelmio attributes or API Platform resource/operation metadata (provider-specific examples), or direct edits to the project-owned OpenAPI document
3. **Check the generated docs**: export the contract via the discovered provider's mechanism (e.g. Nelmio's `api:doc:dump`, API Platform's export) or visit the project's docs endpoint
4. **Regenerate the types on the Angular side**: `npm run api:sync`
5. **Update the consuming Angular components**
6. **Test both sides**

### Breaking changes

An API breaking change impacts all clients:
- The Angular front end (yourself)
- Mobile apps (maybe not you)
- External integrations (maybe not you either)

Procedure:

1. Document the breaking change in the feature's `breaking-changes.md`
2. Announce it to consumers in advance
3. Keep the old endpoint alive during a transition period (versioning)
4. Mark the old one `@deprecated`
5. Remove it after the deadline

### API versioning

If multiple versions coexist:

```
/api/v1/users     ← old version, still maintained
/api/v2/users     ← new version
```

Or via header:

```
GET /api/users
Accept: application/vnd.app.v2+json
```

The choice depends on the project; **being consistent** matters more than the choice itself.

---

## Validation

### Backend side (Symfony)

Payload validation via Symfony Validator with `#[MapRequestPayload]`:

```php
final readonly class CreateUserRequest
{
    public function __construct(
        #[Assert\NotBlank]
        #[Assert\Email]
        public string $email,

        #[Assert\NotBlank]
        #[Assert\Length(min: 8)]
        public string $password,
    ) {}
}

#[Route('/api/users', methods: ['POST'])]
final class CreateUserController
{
    public function __invoke(
        #[MapRequestPayload] CreateUserRequest $request,
    ): JsonResponse { ... }
}
```

If validation fails, Symfony automatically throws an exception → HTTP 422 with the standard error format (via an EventListener).

### Frontend side (Angular)

Frontend validation is a UX convenience, **not a security guarantee**. Always validate on the backend.

```typescript
import { FormBuilder, Validators } from '@angular/forms';

protected readonly form = this.fb.group({
  email: ['', [Validators.required, Validators.email]],
  password: ['', [Validators.required, Validators.minLength(8)]],
});

protected onSubmit(): void {
  if (this.form.invalid) return;
  
  this.userApi.create(this.form.value as CreateUserRequest)
    .pipe(takeUntilDestroyed(this.destroyRef))
    .subscribe({
      next: user => { /* success */ },
      error: (err: HttpErrorResponse) => {
        // Map backend violations onto the FormControls
        if (err.error?.violations) {
          for (const v of err.error.violations) {
            this.form.get(v.field)?.setErrors({ backend: v.message });
          }
        }
      },
    });
}
```

---

## Security

### Authentication

Authentication is **discovered**, never assumed: JWT via `lexik/jwt-authentication-bundle` is one common setup; session-based Symfony security is equally valid. Follow what the project has.

If JWT is in place, an Angular `authInterceptor` adds the token automatically (JWT-specific example):

```typescript
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const token = auth.getToken();

  if (token) {
    req = req.clone({
      setHeaders: { Authorization: `Bearer ${token}` },
    });
  }

  return next(req);
};
```

### CORS

The CORS implementation is **discovered**. On Symfony, `nelmio/cors-bundle` is the common example:

```yaml
nelmio_cors:
  defaults:
    origin_regex: true
    allow_origin: ['%env(CORS_ALLOW_ORIGIN)%']
    allow_methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']
    allow_headers: ['Content-Type', 'Authorization']
    expose_headers: ['Link']
    max_age: 3600
  paths:
    '^/api/': null
```

`.env`:

```
CORS_ALLOW_ORIGIN=^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?$
```

**Never** use `*` as the origin except for a public API without auth.

### Error masking

In production, hide internal error details:

```json
// Dev
{ "message": "SQLSTATE[23000]: Integrity constraint violation", "trace": "..." }

// Prod
{ "message": "An error occurred", "code": "INTERNAL_ERROR" }
```

Configure this via a Symfony EventListener that formats according to the environment.

---

## Documentation and synchronization

### Source of truth

The source of truth is **discovered**: it is the designated machine-readable contract, whatever its source mode — provider-generated (API Platform, Nelmio, another configured provider) or a project-owned hand-written OpenAPI document. Any divergence on the Angular side from that designated contract is a bug.

### Enforce the sync in the project's CI

The sync check runs in the project's **existing** pipeline — the toolkit prescribes what must be green, never how the pipeline is wired: dump the OpenAPI spec, regenerate the Angular types, then fail on any divergence (`git status --porcelain` catches untracked generated files too).

### Hooks to enforce the sync

A pre-commit validation hook is **non-destructive**: it never overwrites or stages the tracked contract as its way of checking freshness — it exports to a temporary candidate and **fails** when the tracked contract is stale, leaving the deliberate update to `/api-contract`. (Provider-generated mode; for a project-owned contract there is no export — validate the document instead.) Same path rules as above (`<repo-root>` resolved once — e.g. `git rev-parse --show-toplevel` on a Git checkout, an implementation example; roots and contract path repository-root-relative at any depth; never `../`, never `cd ..`):

```bash
# If controllers change → verify the tracked contract is still in sync (never mutate it here)
if git diff --cached --name-only | grep -q '^<backend-root>/src/Controller/'; then
  CANDIDATE=$(mktemp)
  ( cd "<repo-root>/<backend-root>" && <provider-export-command> > "$CANDIDATE" )
  if ! diff -q "<repo-root>/<contract-path>" "$CANDIDATE" > /dev/null; then
    echo "❌ API contract out of sync — run /api-contract to update it deliberately"
    rm -f "$CANDIDATE"; exit 1
  fi
  rm -f "$CANDIDATE"
fi
```

---

## Anti-patterns

- ❌ Endpoint that returns 200 even on error (with `success: false`)
- ❌ Different error format across endpoints
- ❌ Mixing `camelCase` and `snake_case` in the JSON
- ❌ Plural URLs for some resources, singular for others
- ❌ Hand-written TypeScript types that drift from the backend
- ❌ No backend validation (frontend-only)
- ❌ Exposing everything (`@Groups(['default'])` on all fields)
- ❌ Endpoints that return different structures depending on parameters (`?detail=true`)
- ❌ `password` or other sensitive fields in the `read` groups
- ❌ CORS `*` in production
- ❌ PHP stack trace returned in production
