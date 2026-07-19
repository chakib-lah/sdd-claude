# API Contracts — Symfony ↔ Angular

> **Layer 2 — Specific to backend/frontend integration.**

---

## Guiding principle

> The API contract is a **shared artifact** between backend and frontend. Every change must be tracked and synchronized on both sides.

Preferred format: **OpenAPI 3.x** (generated or hand-written, single source of truth).

---

## Recommended toolchain

### Symfony backend — Generate the OpenAPI

#### Option A — `nelmio/api-doc-bundle`

```bash
cd backend
composer require nelmio/api-doc-bundle
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

Access the docs:
- HTML: `http://localhost:8000/api/doc`
- JSON: `http://localhost:8000/api/doc.json`

#### Option B — `api-platform/api-platform`

API Platform generates OpenAPI automatically and offers more features, but it structures the entire backend around its conventions. Worth considering for greenfield projects.

### Angular frontend — Generate the TypeScript types

```bash
cd frontend
npm install --save-dev @openapitools/openapi-generator-cli
```

Script in `package.json`:

```json
{
  "scripts": {
    "api:sync": "openapi-generator-cli generate -i http://localhost:8000/api/doc.json -g typescript-angular -o src/app/generated/api --additional-properties=npmName=app-api,supportsES6=true,withInterfaces=true"
  }
}
```

Usage:

```bash
npm run api:sync
```

Generates into `src/app/generated/api/`:
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

## Symfony serialization — Groups

### Group convention

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
2. **Update the OpenAPI annotations** on the Symfony side
3. **Check the generated docs**: `php bin/console api:doc:dump` or visit `/api/doc.json`
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

Recommended: JWT via `lexik/jwt-authentication-bundle`.

On the Angular side, an `authInterceptor` adds the token automatically:

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

Configure `nelmio/cors-bundle` on the Symfony side:

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

The OpenAPI generated by Symfony is the **source of truth**. Any divergence on the Angular side is a bug.

### Include the docs in CI

```yaml
# .gitlab-ci.yml
api-doc-sync:
  script:
    - cd backend && php bin/console api:doc:dump > /tmp/openapi.json
    - cd ../frontend && npx openapi-generator-cli generate -i /tmp/openapi.json -g typescript-angular -o /tmp/generated
    - diff -r src/app/generated/api /tmp/generated || (echo "Front API types out of sync !" && exit 1)
```

### Hooks to enforce the sync

Pre-commit on the backend side:

```bash
# If controllers change → regenerate the docs and commit them
if git diff --cached --name-only | grep -q '^backend/src/Controller/'; then
  cd backend && php bin/console api:doc:dump > ../api-docs/openapi.json
  git add ../api-docs/openapi.json
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
