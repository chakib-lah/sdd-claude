---
description: Generate or synchronize the OpenAPI contract between Symfony backend and Angular frontend
---

# /api-contract

**Synchronization command**: generate the OpenAPI contract from the Symfony backend, then regenerate the TypeScript types and services on the Angular side.

## Blocking prerequisites

- Active SDD feature (except in global sync mode without a feature)
- A machine-readable OpenAPI contract source on the backend side — either a **discovered provider** (Nelmio, API Platform, other) or a valid **project-owned hand-written contract** designated as the source of truth
- An automated TypeScript generator on the frontend — **discovered** from `package.json`/scripts
- Available conventions: `.claude/rules/api-contracts.md`

Both roots, the contract location/URL, the tracked contract path and the generated output directory are **project facts** — discover them first; the `<backend-root>`, `<frontend-root>`, `<openapi-contract-url>`, `<contract-path>` and `<generated-output-dir>` placeholders below stand for the discovered values.

**Coordinate system**: resolve the repository root **once** — `<repo-root>` (e.g. `git rev-parse --show-toplevel` on a Git checkout, shown as an implementation example, not a universal requirement). `<backend-root>`, `<frontend-root>` and `<contract-path>` are **repository-root-relative** and may be nested at any depth (`apps/backend`, `clients/web/angular`, `contracts/openapi.json`…). Always resolve paths from `<repo-root>`: never recover the repository root with `cd ..`, and never assume a `../<contract-path>` relationship between roots and the contract.

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

### 1. Discover the toolchain and the contract source mode

#### Backend contract source

```bash
cd <repo-root>/<backend-root>
composer show | grep -iE "nelmio/api-doc-bundle|api-platform"
```

Determine the **contract source mode** (check `config/packages/`, the repository and Layer 3 too):

- **MODE A — provider-generated**: a configured provider (Nelmio, API Platform, other) owns the contract. Discover its **actual export mechanism**. Never mandate Nelmio where API Platform owns the contract, or vice versa.
- **MODE B — project-owned**: no provider, but a valid hand-written OpenAPI document is the designated source of truth. Provider absence is **not** a gap — validate and use that contract directly.
- **MODE C — neither**: no configured provider **and** no designated valid machine-readable contract → **PROJECT_TOOLING_GAP** — report and stop:

```
❌ PROJECT_TOOLING_GAP: no machine-readable API contract source (no configured
   OpenAPI provider and no designated project-owned OpenAPI document).
   The contract capability remains required. Setting up a source is a dedicated
   tooling task (greenfield default: nelmio/api-doc-bundle) — never a silent side
   effect of this command inside a feature.
```

#### Frontend generator

```bash
cd <repo-root>/<frontend-root>
npm ls @openapitools/openapi-generator-cli 2>/dev/null || grep -i openapi package.json
```

Discover the existing generator dependency, its package script (e.g. `api:sync`), the contract input location/URL and the output directory. If the backend contract exists but no generator is configured → **API_CONTRACT_AUTOMATION_GAP** — report and stop, never `npm install` silently:

```
❌ API_CONTRACT_AUTOMATION_GAP: no automated TypeScript generator configured.
   Automated contract synchronization remains the required target. Setting it up is
   a dedicated tooling task (greenfield default: @openapitools/openapi-generator-cli).
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

#### 4.1 — MODE A only: verify that the backend is running (or startable)

Only needed when the discovered export mechanism requires a live backend (HTTP export). In MODE B (project-owned contract) skip to 4.2.

```bash
# Start the backend via the project's own wrapper (compose service names,
# Make targets and ports are project facts — discover them)
<project-backend-start-command>

# Check contract accessibility at the discovered location
curl -s -o /dev/null -w "%{http_code}" <openapi-contract-url>
```

#### 4.2 — Obtain the candidate contract — NEVER overwrite the tracked contract first

**MODE A**: export/fetch the new contract to a **temporary candidate** outside the tracked product paths (the tracked contract path — greenfield default `api-docs/openapi.json` — stays untouched at this step):

```bash
CANDIDATE=$(mktemp)
curl -s <openapi-contract-url> > "$CANDIDATE"
```

**MODE B**: the tracked project-owned contract IS the source of truth — there is no export; validate it and continue at 4.4 with `<repo-root>/<contract-path>` as generator input.

Validate the candidate:

```bash
cat "$CANDIDATE" | python3 -m json.tool > /dev/null && echo "✅ Valid JSON"
```

#### 4.3 — Compare the tracked contract with the candidate BEFORE any update

```bash
diff "<repo-root>/<contract-path>" "$CANDIDATE" || echo "Changes detected"
```

Run the project's configured contract-diff / breaking-change mechanism if one exists; otherwise analyze the diff per `.claude/rules/api-contracts.md` (breaking-change workflow). Only **after** this comparison and analysis, update the tracked contract and drop the candidate (it is temporary — never committed):

```bash
cp "$CANDIDATE" "<repo-root>/<contract-path>"
rm -f "$CANDIDATE"
```

#### 4.4 — Regenerate the Angular types and services

Use the project's own sync script when one exists (e.g. `npm run api:sync`). Direct example with the discovered generator and output — the contract input is resolved from `<repo-root>`, **independently of the current directory** (the frontend root may be nested):

```bash
cd <repo-root>/<frontend-root>
npx openapi-generator-cli generate \
  -i <repo-root>/<contract-path> \
  -g typescript-angular \
  -o <generated-output-dir> \
  --additional-properties=supportsES6=true,withInterfaces=true,modelPropertyNaming=camelCase
```

This generates into the configured output directory (greenfield default `src/app/generated/api/`):
- `model/`: all the types (interfaces)
- `api/`: Angular services with typed methods
- `configuration.ts`: configuration

#### 4.5 — Summarize the detected changes (from the 4.3 comparison)

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

### 5. "Check" mode — non-destructive, source-mode aware

Verify — **without mutating the tracked contract** — that a specific endpoint is:
- Represented in the designated machine-readable contract via the **discovered contract metadata/source mechanism** (Nelmio attributes and API Platform resource metadata are provider-specific examples; a project-owned document is checked directly — there is no universal annotations criterion)
- Valid OpenAPI, where OpenAPI is the selected contract format
- Synchronized on the Angular side (generated types/client up to date; breaking-change status where applicable)

```bash
# Search in the tracked contract (read-only)
jq '.paths."/api/users/{id}"' <repo-root>/<contract-path>

# Search in the generated Angular types
grep -r "findById" <repo-root>/<frontend-root>/<generated-output-dir>/
```

Report:

```
🔍 Endpoint: GET /api/users/{id}

Contract:
  - Contract source: [provider-generated (<provider>) | project-owned document]
  - Machine-readable contract: ✅
  - Contract metadata/source mechanism: ✅ (endpoint represented)
  - Contract validation: ✅

Frontend:
  - Generated service: UserApiService.findById() ✅
  - Return type: UserResponse ✅
  - Frontend synchronization: ✅
```

### 6. "Update" mode

For an endpoint that has just been modified:

#### 6.1 — Verify the contract metadata on the Symfony side

Via the **discovered contract metadata mechanism** — with Nelmio, open the controller and verify that the `#[OA\...]` attributes reflect the changes (provider-specific example); with API Platform, verify the resource/operation metadata; with a project-owned contract (MODE B), edit and validate the OpenAPI document directly:

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

#### 6.2 — Refresh the tracked contract, by discovered source mode

**MODE A (provider-generated)** — same candidate-first ordering as the global sync (steps 4.2–4.3); the export mechanism is the provider's own (an HTTP endpoint is just one example):

```bash
CANDIDATE=$(mktemp)
curl -s <openapi-contract-url> > "$CANDIDATE"     # or the provider's CLI export into "$CANDIDATE"
diff "<repo-root>/<contract-path>" "$CANDIDATE" || echo "Changes detected"
cp "$CANDIDATE" "<repo-root>/<contract-path>" && rm -f "$CANDIDATE"
```

**MODE B (project-owned)** — there is **no provider export and no `<openapi-contract-url>`**: the document edited in 6.1, through the project's established workflow, IS the tracked contract. Validate it, then compare against the previous Git/baseline version as the change/compatibility-analysis input:

```bash
<openapi-validator> "<repo-root>/<contract-path>"      # the project's validator (JSON/YAML OpenAPI)
git diff -- "<repo-root>/<contract-path>"              # old ↔ new comparison for breaking-change analysis
```

#### 6.3 — Frontend regeneration (step 4.4)

#### 6.4 — Update the consuming Angular components

List the Angular files that used the old type, and flag those that need to be adapted:

```bash
grep -rln "UserResponse" <frontend-root>/src/app/
```

### 7. Verify the TypeScript compilation

After regeneration:

```bash
cd <repo-root>/<frontend-root>
npx tsc --noEmit
```

If there are errors → display the list and propose fixes.

### 8. Verify the tests

Via the project's configured test script (whatever runner it wires):

```bash
cd <repo-root>/<frontend-root>
npm test
```

Broken tests indicate a contract break. To analyze:
- Renamed fields?
- Removal of an expected property?
- Format change (string ↔ number)?

### 9. Commit the diff

Propose a commit with an explicit message:

```bash
git add <repo-root>/<contract-path> <repo-root>/<frontend-root>/<generated-output-dir>/

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
  <contract-path> (X endpoints, Y schemas)

Frontend (Angular):
  <generated-output-dir>/
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

- **The designated machine-readable contract (provider-generated or project-owned) is the source of truth**. Any divergence is a bug.
- **Never overwrite the tracked contract before comparing it with the exported candidate** — export to a temporary candidate, validate, compare, then update.
- **Do not manually modify the files in `generated/`**: they will be overwritten on the next `/api-contract`.
- **Always regenerate on the frontend side after modifying an endpoint** (Single Source of Truth).
- **Always verify the TypeScript compilation after regeneration**.
- **Keep the contract metadata complete via the discovered mechanism** — Nelmio attributes/annotations as configured, API Platform resource/operation metadata, or direct edits to the project-owned OpenAPI document — otherwise the contract is incomplete.
- **In case of a breaking change**: API versioning or a transition period with `@deprecated`.
- **Do not include the generated files in the code review** without having seen the OpenAPI JSON diff first (= understand what actually changed).
- **Include the exported contract file in Git versioning**: it is the shared contract.
- **Never install backend or frontend tooling from this command**: a missing machine-readable contract source (no configured provider **and** no designated project-owned contract) is a PROJECT_TOOLING_GAP; a missing generator is an API_CONTRACT_AUTOMATION_GAP — both closed by dedicated tooling tasks, never silently during a feature. Provider absence alone is never a gap when a valid project-owned contract is the designated source of truth.
