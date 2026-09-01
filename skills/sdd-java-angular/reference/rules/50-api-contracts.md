# API Contracts — Spring Boot ↔ Angular

> **Layer 2 — Specific to backend/frontend integration.**

---

## Guiding principle

> The API contract is a **shared artifact** between backend and frontend. Every change must be tracked and synchronized on both sides.

Preferred format: **OpenAPI 3.x** (generated or hand-written, single source of truth).

---

## Required capability, discovered implementation

A machine-readable API contract with a typed, synchronized Angular boundary is a **required full-stack capability**. Its implementation is a set of **project facts** — discover, never assume:

- **OpenAPI provider**: springdoc-openapi is the common Spring Boot example, but any real configured provider/export mechanism is valid. A valid **project-owned hand-written OpenAPI document** designated as the source of truth is equally acceptable — provider absence alone is never a gap.
- **Export mechanism**: runtime endpoint (springdoc default `/v3/api-docs` — path and base URL are configured project facts), a build-time export plugin (Gradle or Maven — task name and output artifact location come from the build configuration), or a project script. Never assume a specific task name, port or artifact path.
- **Tracked contract snapshot**: whether the provider-generated contract is versioned in Git is a **project fact, not a universal prerequisite**. A valid provider setup may keep the contract as a build/export artifact only — its absence is never a contract-source gap.
- **Provider metadata**: springdoc annotations (`@Tag`, `@Operation`, `@ApiResponse`, `@Schema`) are provider-specific — required only where springdoc owns the contract and the project's convention applies them, never universally.
- **Authentication**: discovered — Spring Security OAuth2 resource server / JWT is one common setup; session-based security, Basic Auth, a custom security filter or gateway-provided identity are equally valid.
- **CORS implementation**: discovered — a `CorsConfigurationSource` bean is the common Spring example, not a given (gateway-level CORS is equally valid).
- **Contract location/URL, frontend generator and output directory**: discovered from the project's configuration, scripts and dependencies.
- **Roots**: `<backend-root>`/`<frontend-root>` below stand for the discovered directories — never assume `backend/`/`frontend/`; the backend root may be the repository root itself.

If the backend exposes no machine-readable contract source at all: **PROJECT_TOOLING_GAP**. If a valid contract source exists but no automated frontend type/client synchronization does: **API_CONTRACT_AUTOMATION_GAP**. Both remain required targets, closed by dedicated tooling/contract tasks — never silently during an unrelated feature, and never conflated with each other. The universal rules of this file (explicit schemas, typed frontend boundary, backend validation, no sensitive-field leakage, documented HTTP statuses, deliberate breaking changes, contract synchronization) apply regardless of providers.

---

## Toolchain (provider-specific examples and greenfield defaults)

### Spring Boot backend — springdoc (provider-specific example)

```groovy
// build.gradle — greenfield setup; Maven: same artifact in pom.xml
dependencies {
    // springdoc 2.x targets Spring Boot 3.x — use springdoc 3.x with Boot 4
    implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.8.9'
}
```

`application.yml` configuration (paths are configurable project facts):

```yaml
springdoc:
  api-docs:
    path: /v3/api-docs
  swagger-ui:
    path: /swagger-ui.html
  paths-to-match: /api/**
```

Access the docs (URLs are project facts — local greenfield defaults shown): HTML at `<backend-base-url>/swagger-ui.html`, JSON at `<backend-base-url>/v3/api-docs`.

Keep these endpoints out of production — a build-time export (below) removes any runtime need for them:

```yaml
# application-prod.yml (prod profile)
springdoc:
  api-docs:
    enabled: false
  swagger-ui:
    enabled: false
```

#### Build-time export (provider-specific example)

The `springdoc-openapi-gradle-plugin` exports the contract without a manually started server — it forks the application and fetches the docs endpoint itself, so the app must be able to start with the resources the project's profiles require. The task name and output artifact location are **configured project facts** (read the plugin configuration — defaults differ between projects). Never silently start databases or modify profiles/configuration to force the export through — if required infrastructure is unavailable, report the blocker.

```groovy
plugins {
    id 'org.springdoc.openapi-gradle-plugin' version '1.8.0'   // pin per project
}
```

A Maven project uses the equivalent springdoc Maven plugin; a project may also wire its own export script — use whatever the project has.

#### Provider metadata (where springdoc owns the contract)

springdoc infers a lot from method signatures and records. Where the project's convention applies `@Operation` / `@ApiResponse`, they sharpen descriptions and error schemas — follow that convention consistently. They are **provider-specific metadata, not a universal requirement**: a project on another provider uses that provider's mechanism, and a project-owned contract (below) is edited directly.

```java
public record UserResponse(
    @Schema(description = "Unique identifier", example = "42") Long id,
    @Schema(description = "Email address", example = "jane@example.com") String email
) {}
```

### Project-owned contract (equally valid source)

A hand-written, tracked OpenAPI document (JSON or YAML) designated as the source of truth is a valid contract source: validate it with the project's OpenAPI validator, evolve it through the project's established review workflow, and feed it to the frontend generator directly. No provider and no export step are required in this mode.

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

Usage: `npm run api:sync`. Generates into the configured output directory (greenfield default `src/app/generated/api/`):
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
| 400 | Malformed request or validation failed | ProblemDetail with violations |
| 401 | Authentication required or failed | ProblemDetail |
| 403 | Authenticated but not authorized | ProblemDetail |
| 404 | Resource not found | ProblemDetail |
| 409 | Conflict (e.g. email already in use) | ProblemDetail |
| 422 | Semantically invalid request (business rule) | ProblemDetail with violations |
| 500 | Internal server error | Generic ProblemDetail |

### Uniform error format — `ProblemDetail` (RFC 9457)

Spring ships `ProblemDetail` natively. Every API error returns the same shape:

```json
{
    "type": "https://example.com/problems/validation-error",
    "title": "Validation failed",
    "status": 400,
    "detail": "The request body contains invalid fields",
    "violations": [
        {
            "field": "email",
            "message": "Invalid email format"
        }
    ]
}
```

The `violations` array is a custom extension property, added via `problemDetail.setProperty("violations", ...)`.

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
- ✅ JSON body keys in `camelCase` — Jackson's default for records and beans; do **not** override with `PropertyNamingStrategies.SNAKE_CASE`

---

## DTO exposure — Response records per view

### Never serialize entities

JPA entities must **never** reach the JSON layer. Serializing them leaks internal fields, triggers lazy-loading surprises, and couples the API contract to the database schema (see `.claude/rules/30-jpa-conventions.md`).

### One record per view

Instead of serialization groups, define **dedicated response records** per view:

```java
// Lighter shape for lists
public record UserSummaryResponse(Long id, String email) {}

// Richer shape for the detail view
public record UserDetailResponse(Long id, String email, Instant createdAt, Instant lastLoginAt) {}
```

Applied in the controller (mapping entity → record in the service or a mapper):

```java
@GetMapping
public List<UserSummaryResponse> list() { ... }        // entities mapped to summaries
```

### Benefits

- Fine-grained control over what is exposed — each view has an explicit, compiler-checked shape
- Security: no accidental leak of sensitive fields (`passwordHash`, `secretKey`) — they simply have no place in the record
- Performance: lighter payload in list view; contract accuracy: one named schema per record

### Optional — `@JsonView`

Jackson's `@JsonView` can filter fields of a single DTO per endpoint. It works, but OpenAPI providers render the views less predictably than distinct records, and reviewers must track which view applies where. **Prefer dedicated records**; keep `@JsonView` for legacy code you are not ready to split.

---

## API change workflow

### When an endpoint changes

1. **Update the SDD spec** first (Design section → Endpoint)
2. **Update the contract on the Spring side** via the discovered mechanism — DTO records plus the provider's metadata convention (springdoc annotations where springdoc owns the contract), or the project-owned OpenAPI document directly
3. **Check the resulting contract**: the discovered export (build task or runtime endpoint), or the validated project-owned document
4. **Regenerate the types on the Angular side**: the project's sync script (e.g. `npm run api:sync`)
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
4. Mark the old one `@Deprecated` (plus the provider's deprecation metadata where applicable — springdoc example: `@Operation(deprecated = true)`)
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

Note: Spring Boot 4 / Spring Framework 7 introduce **first-class API versioning** directly in the mappings (`@GetMapping(version = "2")` plus an `ApiVersionConfigurer`) — a clean option on that baseline.

The choice depends on the project; **being consistent** matters more than the choice itself.

---

## Validation

### Backend side (Spring Boot)

Payload validation via `jakarta.validation` annotations on request records:

```java
public record CreateUserRequest(
    @NotBlank @Email String email,
    @NotBlank @Size(min = 8) String password
) {}

@PostMapping("/api/users")
@ResponseStatus(HttpStatus.CREATED)
public UserResponse create(@Valid @RequestBody CreateUserRequest request) { ... }
```

If validation fails, Spring throws `MethodArgumentNotValidException` → map it to the uniform format in a `@RestControllerAdvice`:

```java
@ExceptionHandler(MethodArgumentNotValidException.class)
ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
    var problem = ProblemDetail.forStatusAndDetail(
        HttpStatus.BAD_REQUEST, "The request body contains invalid fields");
    problem.setTitle("Validation failed");
    problem.setProperty("violations", ex.getBindingResult().getFieldErrors().stream()
        .map(e -> Map.of("field", e.getField(), "message", e.getDefaultMessage()))
        .toList());
    return problem;
}
```

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

Authentication is **discovered**, never assumed: Spring Security with an OAuth2 resource server / JWT is one common setup; session-based security, Basic Auth behind a dedicated filter, a custom security filter chain, or gateway-provided identity headers are equally valid. Follow what the project has — and keep the universal invariants regardless: authorization is decided server-side, credentials/tokens are handled safely, CSRF protection applies where the transport requires it.

If JWT is in place (JWT-specific example — the OAuth2 resource server when tokens come from an identity provider, or a custom JWT filter when the application issues its own):

```java
@Bean
SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    return http
        .csrf(csrf -> csrf.disable())   // stateless API, token-based
        .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/auth/**").permitAll()
            .anyRequest().authenticated())
        .oauth2ResourceServer(o -> o.jwt(Customizer.withDefaults()))
        .build();
}
```

On the Angular side, an `authInterceptor` adds the token automatically (JWT-specific example):

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

#### Token storage (when tokens are used)

Keep the JWT **in memory** (an `AuthService` field or signal) — never in
`localStorage` without explicitly accepting the XSS exfiltration trade-off: any
injected script can read it. If an `HttpOnly` cookie is used instead, CSRF
protection MUST be re-enabled — the `csrf.disable()` above is only valid while
the token travels exclusively in the `Authorization` header.

### CORS

The CORS implementation is **discovered** (application-level or gateway-level). The common Spring example is a `CorsConfigurationSource` bean with **env-driven origins**:

```java
@Bean
CorsConfigurationSource corsConfigurationSource(
        @Value("${app.cors.allowed-origins}") List<String> allowedOrigins) {
    var config = new CorsConfiguration();
    config.setAllowedOrigins(allowedOrigins);
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(List.of("Content-Type", "Authorization"));
    var source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
}
```

`application.yml`:

```yaml
app:
  cors:
    allowed-origins: ${CORS_ALLOWED_ORIGINS:http://localhost:4200}
```

**Never** use `*` as the origin in production — only an explicit, environment-provided list.

### Error masking

In production, hide internal error details:

```yaml
# application.yml (prod profile)
server:
  error:
    include-stacktrace: never
    include-message: never
```

The client sees `{ "title": "Internal Server Error", "status": 500, "detail": "An error occurred" }` — never a constraint name, SQL fragment, or stack trace. Make sure the `@RestControllerAdvice` catch-all never copies exception messages into the `ProblemDetail` in prod.

---

## Documentation and synchronization

### Source of truth

The source of truth is **discovered**: it is the designated machine-readable contract, whatever its source mode — provider-generated (springdoc or another configured provider/export) or a project-owned hand-written OpenAPI document. Any divergence on the Angular side from that designated contract is a bug. Whether a provider-generated contract is additionally **tracked in Git** is a project decision: never create a tracked snapshot as a side effect of validation or sync.

### Enforce the sync in the project's CI

The sync check runs in the project's **existing** pipeline — the toolkit prescribes what must be green, never how the pipeline is wired: obtain the contract via the discovered mechanism, regenerate the Angular types, then fail on any divergence (`git status --porcelain` catches untracked generated files too, where the generated output is versioned). Caveat that survives any wiring: a build-time export forks the application, so the app must be able to **start** in that job with the resources its profiles require — the pipeline provides them; the check never provisions infrastructure or edits configuration itself.

### Hooks to enforce the sync

A pre-commit validation hook is **non-destructive**: it never overwrites or stages a tracked contract as its way of checking freshness — it exports to a temporary candidate and **fails** when the tracked contract is stale, leaving the deliberate update to `/api-contract`. (Provider-generated mode with a tracked snapshot; for a project-owned contract there is no export — validate the document instead; when no snapshot is tracked there is nothing for a hook to compare — the sync lives in `/api-contract` and CI.) Same path rules as above (`<repo-root>` resolved once — e.g. `git rev-parse --show-toplevel` on a Git checkout, an implementation example; roots and contract path repository-root-relative at any depth; never `../`, never `cd ..`).

The trigger predicate is discovered, not universal. **`<api-contract-relevant-backend-change-pattern>`** is the staged-path pattern selecting the project's **contract-relevant backend changes** — controller/resource classes, DTO/schema classes, provider annotations/metadata, provider config, or the contract source files themselves, per the discovered project layout and provider (never a universal `src/main/java` or springdoc-annotation path assumption). Git prints staged paths **repository-root-relative, never `./`-prefixed**: with a nested backend root the pattern carries the discovered prefix (e.g. `^back/…`); with a backend at the repository root it matches the bare backend-owned paths — never substitute `.` into a `^<backend-root>/…` prefix:

```bash
# If contract-relevant backend sources change → verify the tracked contract is still in sync (never mutate it here)
if git diff --cached --name-only | grep -qE '<api-contract-relevant-backend-change-pattern>'; then
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

- ❌ **Hand-written TypeScript types that drift from the backend contract** — the number one integration bug on brownfield projects; migrate to the generated types
- ❌ Endpoint that returns 200 even on error (with `success: false`)
- ❌ Different error format across endpoints (some `ProblemDetail`, some ad-hoc JSON)
- ❌ Mixing `camelCase` and `snake_case` in the JSON
- ❌ Plural URLs for some resources, singular for others
- ❌ No backend validation (frontend-only)
- ❌ Serializing JPA entities directly (lazy-loading leaks, coupled contract)
- ❌ Endpoints that return different structures depending on parameters (`?detail=true`)
- ❌ `passwordHash` or other sensitive fields in response records
- ❌ CORS `*` in production
- ❌ Stack trace returned in production (`server.error.include-stacktrace` left on `always`)
- ❌ JWT persisted in `localStorage` without accepting the XSS trade-off — or an `HttpOnly` cookie transport with CSRF protection left disabled
- ❌ swagger-ui / the runtime docs endpoint left enabled in production
- ❌ A validation hook or check that overwrites, stages or creates a tracked contract file
- ❌ Mandating provider annotations on a project whose contract source is not that provider
