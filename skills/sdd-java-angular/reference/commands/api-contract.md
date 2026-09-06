---
description: Generate or synchronize the OpenAPI contract between Spring Boot backend and Angular frontend
---

# /api-contract

**Synchronization command**: obtain the OpenAPI contract from its discovered source on the Spring Boot side, then regenerate the TypeScript types and services on the Angular side.

## Blocking prerequisites

- Active SDD feature (except in global sync mode without a feature)
- A machine-readable OpenAPI contract source on the backend side — either a **discovered provider** (springdoc is the common Spring example; another export mechanism is equally valid) or a valid **project-owned hand-written contract** designated as the source of truth
- An automated TypeScript generator on the frontend — **discovered** from `package.json`/scripts
- Available conventions: `.claude/rules/50-api-contracts.md`

Both roots, the contract source/URL, the optional tracked contract path and the generated output directory are **project facts** — discover them first; the `<backend-root>`, `<frontend-root>`, `<openapi-contract-url>`, `<contract-path>` and `<generated-output-dir>` placeholders below stand for the discovered values.

**Coordinate system**: resolve the repository root **once** — `<repo-root>` (e.g. `git rev-parse --show-toplevel` on a Git checkout, shown as an implementation example, not a universal requirement). `<backend-root>`, `<frontend-root>` and `<contract-path>` are **repository-root-relative** and may be nested at any depth (`apps/server`, `clients/web/angular`, `contracts/openapi.yaml`…) — the backend root may even be the repository root itself, with the Gradle/Maven wrapper living there. Always resolve paths from `<repo-root>`: never recover the repository root with `cd ..`, and never assume a `../<contract-path>` relationship between roots and the contract.

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
grep -riE "springdoc" build.gradle build.gradle.kts pom.xml gradle/*.gradle 2>/dev/null
```

Determine the **contract source mode** (check the build files, `application*.yml|properties`, the repository and Layer 3 too):

- **MODE A — provider-generated**: a configured provider (springdoc is the common Spring example; another real provider/export mechanism is equally valid) owns the contract. Discover its **actual export mechanism**:
  - runtime HTTP endpoint (springdoc default path `/v3/api-docs`, but the path and base URL are configured project facts — read `springdoc.api-docs.path` and the project's run setup);
  - build-time export task (e.g. the `springdoc-openapi-gradle-plugin` and its configured task/output — task name and artifact location come from the build configuration, never assumed; Maven has an equivalent plugin);
  - or the project's own export script/wrapper.

  Also discover **whether a tracked contract snapshot exists** in Git (a versioned `openapi.json`/`openapi.yaml`/`swagger.json`). **A tracked snapshot is a project fact, not a universal prerequisite** — a valid MODE A project may keep the generated contract as a build artifact only. Its absence is NOT a gap of any kind.

- **MODE B — project-owned**: no provider, but a valid hand-written OpenAPI document is the designated source of truth. Provider absence is **not** a gap — validate and use that contract directly.

- **MODE C — neither**: no configured provider **and** no designated valid machine-readable contract → **PROJECT_TOOLING_GAP** — report and stop:

```
❌ PROJECT_TOOLING_GAP: no machine-readable API contract source (no configured
   OpenAPI provider and no designated project-owned OpenAPI document).
   The contract capability remains required. Setting up a source is a dedicated
   tooling task (greenfield default: springdoc-openapi) — never a silent side
   effect of this command inside a feature.
```

#### Frontend generator

```bash
cd <repo-root>/<frontend-root>
npm ls @openapitools/openapi-generator-cli 2>/dev/null || grep -i openapi package.json
```

Discover the existing generator dependency, its package script (e.g. `api:sync`), the contract input location/URL and the output directory. If a valid backend contract source exists but no generator is configured → **API_CONTRACT_AUTOMATION_GAP** — report and stop, never `npm install` silently:

```
❌ API_CONTRACT_AUTOMATION_GAP: no automated TypeScript generator configured.
   The backend contract source is valid — this is NOT a contract-source gap.
   Automated contract synchronization remains the required target. Setting it up is
   a dedicated tooling task (greenfield default: @openapitools/openapi-generator-cli).
```

### 2. Load the conventions

Read `.claude/rules/50-api-contracts.md`:
- Uniform error format (`ProblemDetail`)
- Standard HTTP codes
- DTO exposure (response records, never entities)
- Naming conventions

### 3. Load the SDD context (if a feature is active)

Read `plan.md` (Technical design → endpoints) — plus `spec.md` for the behavioral requirements and ACs — to retrieve:
- Endpoints to add/modify
- Expected schemas for requests and responses
- Documented HTTP codes

### 4. "Global sync" mode

#### 4.1 — MODE A only: verify that the export can actually run

Only needed when the discovered export mechanism requires a running or startable application (runtime HTTP export, or a build-time export plugin that forks the application). In MODE B (project-owned contract) skip to 4.2.

```bash
# Start/exercise the backend via the project's own wrapper only (compose service
# names, profiles, tasks and ports are project facts — discover them)
<project-backend-export-or-start-command>

# Runtime-export example: check contract accessibility at the discovered location
curl -s -o /dev/null -w "%{http_code}" <openapi-contract-url>
```

If the discovered export needs project infrastructure that is unavailable (database, profile-specific services…), **report the concrete blocker and stop cleanly**. Never silently start databases, install services, or modify `application*.yml`, profiles or build files to force the export through.

#### 4.2 — Obtain the candidate contract — NEVER overwrite a tracked contract first

**MODE A**: export/fetch the new contract to a **temporary candidate** outside the tracked product paths (any tracked contract snapshot stays untouched at this step):

```bash
CANDIDATE=$(mktemp)
curl -s <openapi-contract-url> > "$CANDIDATE"
# or: run the discovered build export task and copy ITS configured output
#     artifact (a project fact, e.g. under the build directory) into "$CANDIDATE"
```

**MODE B**: the tracked project-owned contract IS the source of truth — there is no export; validate it and continue at 4.4 with `<repo-root>/<contract-path>` as generator input.

Validate the candidate — **JSON and YAML are both valid contract formats**:

```bash
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$CANDIDATE" 2>/dev/null \
  || python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$CANDIDATE" \
  && echo "✅ Parseable contract"
# or the project's own OpenAPI validator when one is configured
```

#### 4.3 — Compare BEFORE any update — by tracked-snapshot state

**Tracked snapshot exists** (discovered in step 1): compare it with the candidate **before** touching it:

```bash
diff "<repo-root>/<contract-path>" "$CANDIDATE" || echo "Changes detected"
```

Run the project's configured contract-diff / breaking-change mechanism if one exists; otherwise analyze the diff per `.claude/rules/50-api-contracts.md` (breaking-change workflow). Only **after** this comparison and analysis, update the tracked snapshot and drop the candidate (it is temporary — never committed):

```bash
cp "$CANDIDATE" "<repo-root>/<contract-path>"
rm -f "$CANDIDATE"
```

**NO tracked snapshot** (valid MODE A state): the temporary candidate IS the provider contract artifact for this operation. **Do not create a tracked contract file, and do not mutate the project layout.** For breaking-change comparison, use the project's existing baseline mechanism if one exists (previous build artifact, contract-diff tooling, API review process); otherwise report explicitly that no durable baseline exists for automated breaking-change comparison — this limitation never reclassifies the contract source as missing.

#### 4.4 — Regenerate the Angular types and services

Use the project's own sync script when one exists (e.g. `npm run api:sync`). Direct example with the discovered generator and output — the contract input is the tracked/project-owned contract path, or the temporary candidate when no snapshot is tracked; it is resolved from `<repo-root>`, **independently of the current directory** (the frontend root may be nested):

```bash
cd <repo-root>/<frontend-root>
npx openapi-generator-cli generate \
  -i <contract-input>   `# <repo-root>/<contract-path> — or "$CANDIDATE" when nothing is tracked` \
  -g typescript-angular \
  -o <generated-output-dir> \
  --additional-properties=supportsES6=true,withInterfaces=true,modelPropertyNaming=camelCase
```

This generates into the configured output directory (greenfield default `src/app/generated/api/`):
- `model/`: all the types (interfaces)
- `api/`: Angular services with typed methods
- `configuration.ts`: configuration

Drop the candidate afterwards when one was used (`rm -f "$CANDIDATE"`).

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

#### 4.6 — Verify hand-written types (brownfield)

On brownfield projects the frontend often still uses **hand-written interfaces** instead of the generated ones. Detect the drift:

```bash
# Hand-written types living outside the generated tree
grep -rln "interface.*Response\|interface.*Request" <repo-root>/<frontend-root>/src/app --include="*.ts" | grep -v "generated/"
```

For each hand-written interface whose name matches a contract schema, do a **field-by-field diff** against the schema:

```
⚠ Hand-written types drifting from the contract:

  UserResponse (src/app/shared/models/user.model.ts)
    - missing field: lastLoginAt (string | null)
    - wrong type: id is string, contract says number
```

Propose, in order of preference:
1. **Migrate** the imports to the generated types and delete the hand-written duplicates
2. If migration is too large for this change, **fix** the hand-written interfaces to match the contract and flag the migration as follow-up debt

### 5. "Check" mode — non-destructive, source-mode aware

Verify — **without mutating any tracked contract** — that a specific endpoint is:
- Represented in the designated machine-readable contract via the **discovered contract metadata/source mechanism** (springdoc annotations are a provider-specific example; a project-owned document is checked directly — there is no universal annotations criterion)
- Valid OpenAPI, where OpenAPI is the selected contract format
- Synchronized on the Angular side (generated types/client up to date; breaking-change status where applicable)

```bash
# Search in the contract (read-only — tracked snapshot, project-owned document,
# or a freshly exported temporary candidate when nothing is tracked)
jq '.paths."/api/users/{id}"' <contract-input>

# Search in the generated Angular types
grep -r "findById" <repo-root>/<frontend-root>/<generated-output-dir>/
```

Report:

```
🔍 Endpoint: GET /api/users/{id}

Contract:
  - Contract source: [provider-generated (<provider>) | project-owned document]
  - Tracked snapshot: [<contract-path> | none — build/export artifact only]
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

#### 6.1 — Verify the contract metadata on the Spring side

Via the **discovered contract metadata mechanism** — where springdoc owns the contract, open the controller and verify that the project's annotation convention reflects the changes (provider-specific example); with another provider/export mechanism, verify its metadata; with a project-owned contract (MODE B), edit and validate the OpenAPI document directly:

```java
// springdoc provider example
@GetMapping("/api/users/{id}")
@Operation(summary = "Get user by id")
@ApiResponse(responseCode = "200", description = "User found",
    content = @Content(schema = @Schema(implementation = UserResponse.class)))
@ApiResponse(responseCode = "404", description = "User not found")
public UserResponse findById(@PathVariable Long id) { ... }
```

#### 6.2 — Refresh the contract, by discovered source mode

**MODE A (provider-generated)** — same candidate-first ordering as the global sync (steps 4.2–4.3); the export mechanism is the provider's own (a runtime HTTP endpoint is just one example):

```bash
CANDIDATE=$(mktemp)
curl -s <openapi-contract-url> > "$CANDIDATE"     # or the discovered build-export task's artifact into "$CANDIDATE"
diff "<repo-root>/<contract-path>" "$CANDIDATE" || echo "Changes detected"   # only when a tracked snapshot exists
cp "$CANDIDATE" "<repo-root>/<contract-path>"                                # only when a tracked snapshot exists
```

When no snapshot is tracked, keep the candidate as the generator input and never create a tracked file.

**MODE B (project-owned)** — there is **no provider export and no `<openapi-contract-url>`**: the document edited in 6.1, through the project's established workflow, IS the tracked contract. Validate it, then compare against the previous Git/baseline version as the change/compatibility-analysis input:

```bash
<openapi-validator> "<repo-root>/<contract-path>"      # the project's validator (JSON/YAML OpenAPI)
git diff -- "<repo-root>/<contract-path>"              # old ↔ new comparison for breaking-change analysis
```

#### 6.3 — Frontend regeneration (step 4.4)

#### 6.4 — Update the consuming Angular components

List the Angular files that used the old type, and flag those that need to be adapted:

```bash
grep -rln "UserResponse" <repo-root>/<frontend-root>/src/app/
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

Compose the commit through the **effective Git policy** (`.claude/rules/01-git-conventions.md` § Effective Git policy resolution) — semantic intent: *commit the generated API contract synchronization*. The resolved policy decides the exact message format, whether a ticket is required and where it appears (when the sync stems from a feature in progress, the feature's ticket is the natural candidate) — never impose a command-specific syntax — stage **only paths the project actually tracks** (the tracked snapshot when one exists, the generated output when the project versions it; when neither is tracked there may be nothing to stage from this command):

```bash
git add <repo-root>/<contract-path> <repo-root>/<frontend-root>/<generated-output-dir>/

git commit   # message already resolved through the effective Git policy — subject line only, no trailer
```

### 10. Announce

```
✅ API contract synchronized.

Backend (Spring Boot):
  Source: [provider-generated (<provider>) | project-owned document]
  Contract: [<contract-path> | temporary export artifact] (X endpoints, Y schemas)

Frontend (Angular):
  <generated-output-dir>/
  - Types generated: Y
  - Services generated: N

Checks:
  - TypeScript compiles: ✅
  - Tests pass: ✅ (or ⚠ with a list)
  - Hand-written types drift: none (or ⚠ with a list)

Next steps (if applicable):
- Adapt the impacted Angular components
- Migrate remaining hand-written types to generated ones
```

## Stop rules

- **The designated machine-readable contract (provider-generated or project-owned) is the source of truth**. Any divergence is a bug.
- **Never overwrite a tracked contract before comparing it with the exported candidate** — export to a temporary candidate, validate, compare, then update.
- **Never create a tracked contract snapshot automatically** — whether the provider-generated contract is versioned is a project decision; a valid MODE A project may track nothing.
- **Never silently start databases/services or modify configuration, profiles or build files to force a provider export through** — report the concrete blocker and stop.
- **Do not manually modify the files in the generated output directory**: they will be overwritten on the next `/api-contract`.
- **Always regenerate on the frontend side after modifying an endpoint** (Single Source of Truth).
- **Always verify the TypeScript compilation after regeneration**.
- **Keep the contract metadata complete via the discovered mechanism** — springdoc annotations where springdoc owns the contract and the project applies them, another provider's metadata as configured, or direct edits to the project-owned OpenAPI document — otherwise the contract is incomplete. There is no universal annotation requirement.
- **JSON and YAML are both valid OpenAPI formats** — validate whichever the project uses.
- **In case of a breaking change**: API versioning or a transition period with `@Deprecated` (and the provider's deprecation metadata where applicable, e.g. `@Operation(deprecated = true)` under springdoc).
- **Do not include the generated files in the code review** without having seen the contract diff first (= understand what actually changed).
- **Never install backend or frontend tooling from this command**: a missing machine-readable contract source (no configured provider **and** no designated project-owned contract) is a PROJECT_TOOLING_GAP; a missing generator is an API_CONTRACT_AUTOMATION_GAP — both closed by dedicated tooling tasks, never silently during a feature. Provider absence alone is never a gap when a valid project-owned contract is the designated source of truth, and a missing tracked snapshot is never a gap when a valid provider exists.
