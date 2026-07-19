---
description: Generate or synchronize the OpenAPI contract between Symfony backend and Angular frontend
---

# /api-contract

**Synchronization command**: generate the OpenAPI contract from the Symfony backend, then regenerate the TypeScript types and services on the Angular side.

## Blocking prerequisites

- Active SDD feature (except in global sync mode without a feature)
- Symfony backend with `nelmio/api-doc-bundle` installed (or `api-platform`)
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
composer show | grep -E "nelmio/api-doc-bundle|api-platform"
```

If nothing → explain the installation and stop:

```
❌ nelmio/api-doc-bundle or api-platform required on the backend side.
   composer require nelmio/api-doc-bundle
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
- Uniform error format
- Standard HTTP codes
- Serialization groups
- Naming conventions

### 3. Load the SDD context (if a feature is active)

Read `spec.md` (Design section → Endpoint(s)) to retrieve:
- Endpoints to add/modify
- Expected schemas for requests and responses
- Documented HTTP codes

### 4. "Global sync" mode

#### 4.1 — Verify that the backend is running (or startable)

```bash
# If the backend runs via Docker Compose
docker-compose up -d backend

# Check accessibility
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/doc.json
```

#### 4.2 — Fetch the OpenAPI JSON

```bash
mkdir -p api-docs
curl -s http://localhost:8000/api/doc.json > api-docs/openapi.json
```

Verify that it is valid:

```bash
cat api-docs/openapi.json | python3 -m json.tool > /dev/null && echo "✅ Valid JSON"
```

#### 4.3 — Save the previous contract (for diff)

```bash
[ -f api-docs/openapi.json ] && cp api-docs/openapi.json api-docs/openapi.previous.json
```

#### 4.4 — Regenerate the Angular types and services

```bash
cd frontend
npx openapi-generator-cli generate \
  -i ../api-docs/openapi.json \
  -g typescript-angular \
  -o src/app/generated/api \
  --additional-properties=npmName=app-api,supportsES6=true,withInterfaces=true,modelPropertyNaming=camelCase
```

This generates:
- `src/app/generated/api/model/`: all the types (interfaces)
- `src/app/generated/api/api/`: Angular services with typed methods
- `src/app/generated/api/configuration.ts`: configuration

#### 4.5 — Diff with the previous version (if applicable)

```bash
diff -r api-docs/openapi.previous.json api-docs/openapi.json || echo "Changes detected"
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

### 5. "Check" mode

Verify that a specific endpoint is:
- Documented on the backend side (OpenAPI annotations present)
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
  - Controller: src/Controller/GetUserController.php ✅
  - OpenAPI annotations: ✅
  - Present in openapi.json: ✅

Frontend:
  - Generated service: UserApiService.findById() ✅
  - Return type: UserResponse ✅
  - Sync: ✅
```

### 6. "Update" mode

For an endpoint that has just been modified:

#### 6.1 — Verify the OpenAPI annotations on the Symfony side

Open the controller and verify that the `#[OA\...]` attributes reflect the changes:

```php
#[Route('/api/users/{id}', methods: ['GET'])]
#[OA\Get(
    summary: 'Get user by id',
    parameters: [
        new OA\Parameter(name: 'id', in: 'path', required: true, schema: new OA\Schema(type: 'integer')),
    ],
    responses: [
        new OA\Response(response: 200, description: 'User found', content: new OA\JsonContent(ref: new Model(type: UserResponse::class))),
        new OA\Response(response: 404, description: 'User not found'),
    ]
)]
```

#### 6.2 — Re-export the JSON

```bash
curl -s http://localhost:8000/api/doc.json > api-docs/openapi.json
```

#### 6.3 — Frontend regeneration (step 4.4)

#### 6.4 — Update the consuming Angular components

List the Angular files that used the old type, and flag those that need to be adapted:

```bash
grep -rln "UserResponse" frontend/src/app/features/
```

### 7. Verify the TypeScript compilation

After regeneration:

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

Backend (Symfony):
  api-docs/openapi.json (X endpoints, Y schemas)

Frontend (Angular):
  src/app/generated/api/
  - Types generated: Y
  - Services generated: N

Checks:
  - TypeScript compiles: ✅
  - Tests pass: ✅ (or ⚠ with a list)

Next steps (if applicable):
- Adapt the impacted Angular components
- Test locally (E2E or manual)
```

## Stop rules

- **The backend OpenAPI contract is the source of truth**. Any divergence is a bug.
- **Do not manually modify the files in `generated/`**: they will be overwritten on the next `/api-contract`.
- **Always regenerate on the frontend side after modifying an endpoint** (Single Source of Truth).
- **Always verify the TypeScript compilation after regeneration**.
- **Always document the OpenAPI annotations** on the Symfony side — otherwise the contract is incomplete.
- **In case of a breaking change**: API versioning or a transition period with `@deprecated`.
- **Do not include the generated files in the code review** without having seen the OpenAPI JSON diff first (= understand what actually changed).
- **Include `api-docs/openapi.json` in Git versioning**: it is the shared contract.
