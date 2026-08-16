# Migration Guard — Java brownfield

> **Layer 2 — Brownfield-specific (Java backend).**  
> Rules to avoid breaking what exists when evolving an established Spring Boot project.

---

## Fundamental principle

> Any evolution of an existing entity, service, or endpoint must **preserve the current behavior** unless the spec explicitly says otherwise (breaking change accepted and documented).

## Before modifying an existing entity

### 1. Identify all usages

```bash
# The class itself
grep -rn "import com.example.app.domain.model.User" src/
grep -rn "new User(" src/

# The methods used, and JPQL references (entity name, not table name)
grep -rn ".getEmail()" src/main src/test
grep -rn "from User " src/main
```

### 2. Read the existing tests

If there are tests covering the entity, they define the expected behavior. Any breakage of those tests must be documented.

### 3. Check the exposed public API

If the entity feeds a serialized DTO in an API response, check:
- The DTOs/records mapped from it (`grep -rn "UserResponse" src/`)
- The frontend consumers (Angular, mobile, external)
- The OpenAPI documentation being up to date

## Before modifying an existing service

### 1. Identify all callers

```bash
# Injections of the service
grep -rn "UserService" src/main src/test

# Controller endpoints that expose it (layout-agnostic: works for both
# layer-first .../api/ and feature-first .../<feature>/api/ packages)
grep -rn "UserService" --include='*Controller.java' src/main/java

# Mapper usages (MapStruct or manual)
grep -rn "UserMapper" src/main src/test
```

### 2. Preserve the public signature

Unless the spec explicitly says otherwise:

```java
// ❌ Dangerous signature change
- public Optional<User> find(Long id)
+ public Optional<User> find(Long id, boolean withRelations)

// ✅ Prefer a new method
public Optional<User> find(Long id) { ... }              // unchanged
public Optional<User> findWithRelations(Long id) { ... } // new
```

### 3. If a signature MUST change

Document it as a breaking change:
- Create `breaking-changes.md` in the feature folder
- List all impacted callers
- Include an AC for updating the callers in the spec
- Consider a transition period with `@Deprecated`

```java
/**
 * @deprecated Use {@link #findWithRelations(Long)} instead.
 */
@Deprecated(since = "2.5", forRemoval = true)
public Optional<User> find(Long id, boolean withRelations) { ... }
```

The javadoc `@deprecated` tag must always point to the replacement; `forRemoval = true` turns the compiler warning into a stronger signal for callers.

## Database migrations (Flyway)

### Flyway is forward-only — recovery discipline

There is no `down()` in Flyway. The rules:

- **NEVER edit a migration that has been applied** anywhere: the stored checksum no longer matches and every subsequent run fails
- To undo a shipped change, write a **new compensating migration** (`V1.4.1__drop_wrongly_added_column.sql`)
- `flyway repair` (checksum realignment) is reserved for **documented incidents** (e.g. a line-ending change corrupted checksums) — recorded in the feature folder, never a routine fixup

### Adding vs removing a column

**Adding**: generally safe if nullable or with a default value.

**Removing**: do it in 2 separate deployments:

1. **Deployment A**:
   - Remove all usages of the column in the code (entity field, JPQL, DTOs)
   - No removal migration yet
   - Deploy
2. **Deployment B** (weeks later):
   - `DROP COLUMN` migration
   - Deploy

### Column renaming

Avoid it. If necessary:
1. Migration: add a new column with the new name
2. Backfill SQL in the same or a follow-up migration:
   ```sql
   UPDATE app_user SET contact_email = email WHERE contact_email IS NULL;
   ```
3. Switch the entity mapping to the new column, mark the old accessor `@Deprecated`
4. Later, remove the old column (2-step process)

### Type change

Very dangerous. Prefer:
1. Migration: add a new column with the new type
2. Backfill with cast SQL (`UPDATE ... SET amount_cents = round(amount * 100)`)
3. Switch the code over
4. Remove the old column (2-step process)

## Code removal

### Before removing a class, service, or entity

1. Search for all usages:
   - Source code (`grep -rn "ClassName" src/`)
   - Tests
   - Configuration (`application.yml`, `@ConfigurationProperties`, `@Bean` factories)
   - Scheduled jobs (`@Scheduled`), event listeners (`@EventListener`)
   - Reflection-based usage (Jackson polymorphism, Spring Batch job definitions)
2. If even a single usage exists → do not remove, mark `@Deprecated`

### `@Deprecated` before final removal

```java
/**
 * @deprecated Use {@link NewUserService#register(RegisterCommand)} instead.
 */
@Deprecated(since = "3.0", forRemoval = true)
public class OldUserService {
    // ...
}
```

Compiler and IDE surface the warning at every call site → callers migrate before the removal release.

## Serialization and API

### Response format

Any change to a Jackson-serialized DTO/record returned by an API is a **breaking change** for consumers.

```java
// ❌ Removing an exposed field
- public record UserResponse(Long id, String email, String oldField) {}

// ✅ Transition strategy: parallel fields
public record UserResponse(
    Long id,
    String email,
    String oldField,   // kept temporarily
    String newField    // added in parallel
) {}

// Later, once clients have migrated: remove oldField
```

Adding a field is generally safe (clients ignore unknown fields). Removing or renaming one requires coordinating with the clients.

### Never expose entities directly

Controllers return DTOs/records, never JPA entities: entity serialization couples the API contract to the schema, triggers lazy-loading during rendering, and makes every mapping change a silent breaking change.

## Mandatory tests when modifying

### Characterization tests before modification

If the code to modify has no test, write a test that **captures the current behavior** before modifying:

```java
/**
 * Characterization: captures the current behavior to detect regressions.
 */
@Test
void currentBehaviorBeforeRefactor() {
    var result = sut.processOrder(legacyPayload);
    assertThat(result.status()).isEqualTo("expected current output");
}
```

### Non-regression tests in the spec

Any AC that modifies an existing behavior must have a twin non-regression AC:

```
AC-1: When the user creates an order with the new payload format,
       the order is saved correctly.

AC-1bis (non-regression): When the user creates an order with the old
                          payload format, the previous behavior is preserved.
```

## Spring configuration

### Modifying `application.yml` / profiles

Before modifying a property:
1. Identify all `@Value` / `@ConfigurationProperties` bindings that read it
2. Check profile-specific overrides (`application-prod.yml`, env vars)
3. Remember relaxed binding: `my-prop`, `myProp` and `MY_PROP` are the same key

### Modifying `SecurityFilterChain` configuration

🚨 **Particularly sensitive**. Always:
1. Test locally with a fully privileged user
2. Test with a limited user
3. Test the anonymous/public routes
4. Check the filter chain order and `permitAll`/`authenticated` matchers

### Changing a request mapping

If an endpoint path changes, every consumer breaks. Prefer serving both paths during a transition:

```java
@GetMapping({"/api/users/{id}", "/api/v1/users/{id}"})  // legacy alias kept
public UserResponse get(@PathVariable Long id) { ... }
```

## Dependency & platform upgrades

### BOM-managed versions (`io.spring.dependency-management`)

With the Spring dependency-management plugin, a version written directly on a dependency line is honored — but only for **that artifact**: sibling and transitive artifacts of the same family stay at the BOM version (e.g. pinning `flyway-core` without `flyway-database-postgresql` produces a mismatched pair). The `ext` version property moves the **whole family** consistently, which is why it is the recommended mechanism:

```groovy
ext['flyway.version'] = '10.20.1'   // ✅ moves every Flyway artifact together
implementation 'org.flywaydb:flyway-core:10.20.1'  // ⚠️ partial: pins this artifact only, siblings stay at the BOM version
```

### Lockfile discipline

After **every** dependency change, regenerate the lockfile and commit it with the build file:

```bash
./gradlew dependencies --write-locks
```

A `build.gradle` change without its `gradle.lockfile` counterpart fails the build (`LockOutOfDateException`).

### Platform upgrade paths

Upgrade one axis at a time, reading the official release notes at each step:

- **Java**: 17 → 21 → 25 (LTS to LTS; check bytecode-sensitive libs)
- **Spring Boot**: 3.3 → 3.5 → 4.x — Boot 4 splits several starters into finer-grained modules, expect starter renames
- **Gradle**: 7 → 9 (run with `--warning-mode all` first, fix deprecations before jumping)
- **Flyway**: 9 → 10 — add the split database artifact (`flyway-database-postgresql`), see `.claude/rules/jpa-conventions.md`

After each step: full test round + regenerated lockfile before the next step.

## Workflow of a brownfield SDD refactor

1. `/sdd-start REFACTOR-XXX-<description>`
2. `/sdd-spec` — systematically include non-regression AC
3. `/sdd-plan` — progressive strategy (wrapper → delegation → switch-over → removal)
4. `/sdd-tasks` — atomic breakdown
5. Before any implementation task: write the characterization tests if missing
6. `/sdd-implement` one task at a time
7. `/sdd-verify` and `/sdd-review` at the end

## Anti-patterns

- ❌ Big rewrite of an entire service in a single task or phase
- ❌ Modification without prior tests
- ❌ Editing an applied Flyway migration instead of writing a compensating one
- ❌ Routine `flyway repair` to paper over checksum mismatches
- ❌ Removing a column and the code that used it in the same deployment
- ❌ Public signature change without `@Deprecated` transition
- ❌ Method removal without an exhaustive search for usages
- ❌ Returning JPA entities from controllers
- ❌ Dependency bump without regenerating `gradle.lockfile`
- ❌ Refactor mixed with feature work in the same phase (the phase squash would merge them into one commit)
- ❌ "We'll see in production if it breaks" — no, we test beforehand
