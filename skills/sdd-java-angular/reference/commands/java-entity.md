---
description: Scaffold a JPA entity with Flyway migration from a SDD spec
---

# /java-entity

**Auxiliary scaffolding command**: create a JPA entity with its associated Flyway migration and Spring Data repository.

## Blocking prerequisites

- Active SDD feature with `tasks.md` `status: approved`
- Current task mentions the creation/modification of this entity
- Conventions available: `.claude/rules/10-code-conventions.md`, `.claude/rules/30-jpa-conventions.md`

## Steps

### 1. Identify the entity to create

Ask for:
- Entity name (PascalCase, singular): `User`, `Order`, `Invoice`
- Functional domain (if the project is sliced by domain): `user`, `order`, etc.

Detect the target package from the existing layout:

```bash
find src/main/java -type d \( -name "domain" -o -name "model" -o -name "entity" \) | head -5
```

- Hexagonal/DDD layout → `com.example.app.<domain>.domain.model`
- Standard layering → `com.example.app.entity` (or `model`)

Follow whichever convention the codebase already uses. Never introduce a new layout.

### 2. Load the SDD context

Read `plan.md` (Technical design → entities / data model) — plus `spec.md` for the behavioral requirements and ACs — to retrieve:
- List of fields with their types and constraints
- Relations with other entities
- Required indexes
- Unique constraints

### 3. Load the JPA conventions

Read `.claude/rules/30-jpa-conventions.md` to comply with:
- Explicit `@Table`/`@Column` names in snake_case
- `SEQUENCE` identifier strategy
- No Lombok `@Data` on entities: `@Getter` + protected no-arg constructor + factory or builder
- `Instant`/`LocalDate` for temporal fields
- `LAZY` fetching on associations by default

### 4. Check for duplicates

```bash
find src/main/java -name "<EntityName>.java" | head -5
```

If a file exists → ask whether this is a modification (re-read the spec for the exact changes) or whether the name is wrong.

### 5. Generate the entity

Typical skeleton:

```java
package com.example.app.<domain>.domain.model;

import jakarta.persistence.*;
import lombok.Getter;

import java.time.Instant;

@Entity
@Table(
    name = "<table_name>",
    indexes = {@Index(name = "idx_<table>_<col>", columnList = "<col>")},                        // ← if needed
    uniqueConstraints = {@UniqueConstraint(name = "uq_<table>_<col>", columnNames = "<col>")}    // ← if needed
)
@Getter
public class <EntityName> {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "<table>_seq")
    @SequenceGenerator(name = "<table>_seq", sequenceName = "<table>_seq", allocationSize = 50)
    private Long id;

    // Fields typed according to the spec, each with an explicit @Column(name = "snake_case")

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** Required by JPA — never call directly. */
    protected <EntityName>() {
    }

    private <EntityName>(/* required params according to the invariants */) {
        // Initialize required fields
        this.createdAt = Instant.now();
    }

    public static <EntityName> create(/* required params */) {
        return new <EntityName>(/* ... */);
    }

    // Mutators ONLY for fields that are meant to change (intention-revealing names, no blanket setX)
}
```

### 6. Generate the Spring Data repository

```java
package com.example.app.<domain>.domain.repository; // or com.example.app.repository

import org.springframework.data.jpa.repository.JpaRepository;

public interface <EntityName>Repository extends JpaRepository<<EntityName>, Long> {

    // Derived query methods according to the spec
    // Ex: Optional<<EntityName>> findByEmail(String email);
}
```

### 7. Hand-write the Flyway migration

Never rely on Hibernate to create the schema. Detect the next version number from the existing files:

```bash
ls src/main/resources/db/migration/ | sort -V | tail -3
```

Then create `src/main/resources/db/migration/V<x.y.z>__create_<table>.sql`:

```sql
CREATE SEQUENCE <table>_seq START WITH 1 INCREMENT BY 50;

CREATE TABLE <table_name> (
    id         BIGINT      NOT NULL PRIMARY KEY,
    -- columns according to the spec: snake_case, explicit SQL types
    created_at TIMESTAMPTZ NOT NULL
);

-- Indexes and constraints declared on the entity
CREATE UNIQUE INDEX uq_<table>_<col> ON <table_name> (<col>);
CREATE INDEX idx_<table>_<col> ON <table_name> (<col>);
```

Verify that the migration contains:
- ✅ Every column mapped in the entity (SQL types consistent with the Java types)
- ✅ All indexes and unique constraints declared in `@Table`
- ✅ Foreign keys for every relation
- ✅ No changes to tables outside the scope of the task

### 8. Display and validate

Before writing the files, display in the chat:
- Entity content
- Repository content
- Migration SQL
- List of impacted relations (other entities to modify?)

Ask for confirmation.

### 9. Write the files

- `src/main/java/.../<EntityName>.java`
- `src/main/java/.../<EntityName>Repository.java`
- `src/main/resources/db/migration/V<x.y.z>__create_<table>.sql`

### 10. Verify the migration

```bash
# Gradle
./gradlew flywayInfo

# Maven
mvn flyway:info
```

If the Flyway plugin is not configured, boot the application with schema validation instead:

```bash
SPRING_JPA_HIBERNATE_DDL_AUTO=validate ./gradlew bootRun
```

The migration must appear as `Pending` (or `Success` after a run) and the application must start without any schema validation error.

### 11. Announce

```
✅ Entity created: src/main/java/.../<EntityName>.java
✅ Repository created: src/main/java/.../<EntityName>Repository.java
✅ Migration created: src/main/resources/db/migration/V<x.y.z>__create_<table>.sql

Migration verified:
  - flywayInfo: ✅
  - Schema validation (ddl-auto=validate): ✅

Next steps:
- Run /java-test to scaffold the tests
- Then /sdd-implement for the next task
```

## Stop rules

- **Never overwrite an existing entity**
- **Always generate the repository alongside the entity**
- **Always ship the Flyway migration with the entity**: an entity without its migration is an incomplete deliverable
- **Forward-only SQL**: never edit an already-applied migration, always add a new versioned file
- **Never use `ddl-auto=update`**: Flyway owns the schema, Hibernate only validates
- **Do not expose a mutator on every field**: only on those that are meant to change
- **Do not add business logic to the entity** except trivial invariants
- **No Lombok `@Data` or class-level `@Setter` on entities**
