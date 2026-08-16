---
description: Generate or synchronize the OpenAPI contract between Spring Boot backend and Angular frontend
---

# /api-contract

**Synchronization command**: generate the OpenAPI contract from the Spring Boot backend (springdoc), then regenerate the TypeScript types and services on the Angular side.

## Blocking prerequisites

- Active SDD feature (except in global sync mode without a feature)
- Spring Boot backend with `springdoc-openapi-starter-webmvc-ui` installed (or the `springdoc-openapi-gradle-plugin` / Maven equivalent for build-time generation)
- Angular frontend with `@openapitools/openapi-generator-cli` installed
- Available conventions: `.claude/rules/api-contracts.md`

## Usage modes

### Mode 1 — Global sync (no parameter)

Synchronize all types from the current state of the backend.

```
/api-contract
```

### Mode 2 — Check a specific endpoint

```
/api-contract check <path/endpoint>
```

### Mode 3 — Update an endpoint after modification

```
/api-contract update <path/endpoint>
```

## Steps

### 1. Verify the tools are in place

#### Backend

```bash
cd backend
grep -E "springdoc-openapi" build.gradle build.gradle.kts pom.xml 2>/dev/null
```

If nothing → explain the installation and stop:

```
❌ springdoc-openapi required on the backend side.
   Gradle: implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.x' (Maven: same artifact)
   Optional (build-time export): org.springdoc.openapi-gradle-plugin
```

#### Frontend

```bash
cd frontend
npm list @openapitools/openapi-generator-cli
```

If missing → explain the installation and stop:

```
❌ @openapitools/openapi-generator-cli required on the frontend side.
   npm install --save-dev @openapitools/openapi-generator-cli
```

### 2. Load the conventions

Read `.claude/rules/api-contracts.md`:
- Uniform error format (`ProblemDetail`)
- Standard HTTP codes
- DTO exposure (response records, never entities)
- Naming conventions

### 3. Load the SDD context (if a feature is active)

Read `spec.md` (Design section → Endpoint(s)) to retrieve:
- Endpoints to add/modify
- Expected schemas for requests and responses
- Documented HTTP codes

### 4. "Global sync" mode

#### 4.1 — Export the OpenAPI JSON (two paths)

**Path A — Runtime export** (backend running locally):

```bash
# Backend running (Docker Compose or ./gradlew bootRun)?
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/v3/api-docs

mkdir -p api-docs && curl -s http://localhost:8080/v3/api-docs > api-docs/openapi.json
```

**Path B — Build-time export** (springdoc-openapi-gradle-plugin):

```bash
cd backend && ./gradlew generateOpenApiDocs
cp build/openapi.json ../api-docs/openapi.json
```

**Prefer the build artifact in CI**: no manually started server — the plugin forks `bootRun` and fetches `/v3/api-docs` itself. The app must therefore be able to start in CI (dedicated `ci` profile with an H2/Testcontainers datasource), and a local port is bound during the task. Path A is fine for quick local iterations.

#### 4.2 — Save the previous contract (for diff)

```bash
# Keep the committed version before overwriting
git show HEAD:api-docs/openapi.json > api-docs/openapi.previous.json 2>/dev/null || true
```

#### 4.3 — Regenerate the Angular types and services

```bash
cd frontend
npx openapi-generator-cli generate \
  -i ../api-docs/openapi.json \
  -g typescript-angular \
  -o src/app/generated/api \
  --additional-properties=npmName=app-api,supportsES6=true,withInterfaces=true,modelPropertyNaming=camelCase
```

This generates `src/app/generated/api/`: `model/` (interfaces), `api/` (Angular services with typed methods), `configuration.ts`.

#### 4.4 — Diff with the previous version (if applicable)

```bash
diff api-docs/openapi.previous.json api-docs/openapi.json || echo "Changes detected"
```

Display a summary of the changes in the chat:

```
📋 Changes detected:

Endpoints added:
  + POST /api/users/{id}/avatar

Endpoints modified:
  ~ POST /api/users
      → Added "phoneNumber" field to CreateUserRequest

Endpoints removed:
  - DELETE /api/legacy/cleanup

Types modified:
  ~ UserResponse
      → Added "lastLoginAt: string | null" field
```

#### 4.5 — Verify hand-written types (brownfield)

On brownfield projects the frontend often still uses **hand-written interfaces** instead of the generated ones. Detect the drift:

```bash
# Hand-written types living outside the generated tree
grep -rln "interface.*Response\|interface.*Request" frontend/src/app --include="*.ts" | grep -v "generated/"
```

For each hand-written interface whose name matches an OpenAPI schema (`jq '.components.schemas | keys' api-docs/openapi.json`), do a **field-by-field diff** against the schema:

```
⚠ Hand-written types drifting from the contract:

  UserResponse (src/app/shared/models/user.model.ts)
    - missing field: lastLoginAt (string | null)
    - wrong type: id is string, contract says number
```

Propose, in order of preference:
1. **Migrate** the imports to the generated types (`src/app/generated/api/model/`) and delete the hand-written duplicates
2. If migration is too large for this change, **fix** the hand-written interfaces to match the contract and flag the migration as follow-up debt

### 5. "Check" mode

Verify that a specific endpoint is:
- Documented on the backend side (`@Operation` / `@ApiResponse` annotations present)
- Present in the exported JSON
- Synchronized on the Angular side

```bash
# Search in openapi.json
jq '.paths."/api/users/{id}"' api-docs/openapi.json

# Search in the generated Angular types
grep -r "findById" frontend/src/app/generated/api/
```

Report:

```
🔍 Endpoint: GET /api/users/{id}

Backend:
  - Controller: src/main/java/com/example/app/user/UserController.java ✅
  - @Operation / @ApiResponse annotations: ✅
  - Present in openapi.json: ✅

Frontend:
  - Generated service: UserApiService.findById() → UserResponse ✅
  - Sync: ✅
```

### 6. "Update" mode

For an endpoint that has just been modified:

#### 6.1 — Verify the springdoc annotations on the Spring side

Open the controller and verify that the annotations reflect the changes:

```java
@GetMapping("/api/users/{id}")
@Operation(summary = "Get user by id")
@ApiResponse(responseCode = "200", description = "User found",
    content = @Content(schema = @Schema(implementation = UserResponse.class)))
@ApiResponse(responseCode = "404", description = "User not found")
public UserResponse findById(@PathVariable Long id) { ... }
```

#### 6.2 — Re-export the JSON

```bash
curl -s http://localhost:8080/v3/api-docs > api-docs/openapi.json
# or: ./gradlew generateOpenApiDocs && cp backend/build/openapi.json api-docs/openapi.json
```

#### 6.3 — Frontend regeneration (step 4.3)

#### 6.4 — Update the consuming Angular components

List the Angular files that used the old type, and flag those that need to be adapted:

```bash
grep -rln "UserResponse" frontend/src/app/features/
```

### 7. Verify the TypeScript compilation

```bash
cd frontend
npx tsc --noEmit
```

If there are errors → display the list and propose fixes.

### 8. Verify the tests

```bash
cd frontend
npm test -- --watch=false
```

Broken tests indicate a contract break. To analyze:
- Renamed fields?
- Removal of an expected property?
- Format change (string ↔ number)?

### 9. Commit the diff

Propose a commit with an explicit message:

```bash
git add api-docs/openapi.json frontend/src/app/generated/api/

# Commit
git commit -m "chore(api): sync OpenAPI contract"
```

If the sync stems from a feature in progress, include the ticket:

```bash
git commit -m "feat(<TICKET>): sync API types after endpoint update"
```

### 10. Announce

```
✅ API contract synchronized.

Backend (Spring Boot):
  api-docs/openapi.json (X endpoints, Y schemas)

Frontend (Angular):
  src/app/generated/api/ (Y types, N services)

Checks:
  - TypeScript compiles: ✅
  - Tests pass: ✅ (or ⚠ with a list)
  - Hand-written types drift: none (or ⚠ with a list)

Next steps (if applicable):
- Adapt the impacted Angular components
- Migrate remaining hand-written types to generated ones
```

## Stop rules

- **The backend OpenAPI contract (springdoc annotations) is the single source of truth**. Any divergence is a bug.
- **`@Operation` / `@ApiResponse` annotations are mandatory on controllers** — without them the contract is incomplete and the generated client is wrong.
- **Do not manually modify the files in `src/app/generated/`**: they will be overwritten on the next `/api-contract`.
- **Always regenerate on the frontend side after modifying an endpoint** (Single Source of Truth).
- **Always verify the TypeScript compilation after regeneration**.
- **In case of a breaking change**: API versioning or a transition period with `@Deprecated` on the old endpoint.
- **Do not include the generated files in the code review** without having seen the OpenAPI JSON diff first (= understand what actually changed).
- **Include `api-docs/openapi.json` in Git versioning**: it is the shared contract.
