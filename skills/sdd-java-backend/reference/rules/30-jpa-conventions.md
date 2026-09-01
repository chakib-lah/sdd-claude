# JPA / Hibernate — Conventions

> **Layer 2 — Specific to JPA/Hibernate (Java backend).**

---

## Target version

- **Hibernate ORM**: 6.6+ (Jakarta Persistence 3.x — `jakarta.persistence.*` imports, never `javax.persistence.*`)
- **Spring Data JPA**: 3.x
- **Flyway**: 10+ — ⚠️ since Flyway 10 the PostgreSQL support lives in a **separate artifact**: `flyway-core` alone no longer talks to PostgreSQL, you must **also** declare `implementation 'org.flywaydb:flyway-database-postgresql'`. Flyway 9 and earlier shipped everything in the single `flyway-core` artifact.

## Entities

### Golden rule: one entity, one responsibility

An entity represents a single business concept. If an entity has more than 15-20 fields, that is usually a sign of poor modeling.

### Entity format

```java
package com.example.app.domain.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "app_user")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "app_user_seq")
    @SequenceGenerator(name = "app_user_seq", sequenceName = "app_user_seq", allocationSize = 50)
    private Long id;

    @Column(name = "email", length = 180, nullable = false, unique = true)
    private String email;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected User() {
        // JPA only — never call from application code
    }

    public User(String email) {
        this.email = email;
        this.createdAt = Instant.now();
    }

    public Long getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    // getCreatedAt() etc. — getters only, no blanket setters
}
```

> Calling `Instant.now()` in an entity constructor/factory is acceptable for creation timestamps; as soon as business logic depends on time, inject a `Clock` instead (see the tests-strategy rule).

❌ **Never rely on implicit naming**: always declare `@Table(name = ...)` and `@Column(name = ...)` explicitly, in **snake_case**. Implicit naming depends on the active `PhysicalNamingStrategy` and silently breaks when it changes.  
❌ **No generic setters** on every field — only create a setter if the field must be able to change.

### ID generation strategy

| Strategy | Usage |
|---|---|
| `GenerationType.SEQUENCE` | ✅ Preferred for PostgreSQL — allows JDBC batching, `allocationSize` tuning |
| `GenerationType.IDENTITY` | Acceptable (existing `serial`/`identity` columns) — but disables insert batching |
| `GenerationType.AUTO` | ❌ Avoid — behavior varies by dialect and Hibernate version |

### Explicit constructor

Prefer a constructor (or static factory method) that enforces invariants at instantiation:

```java
// ✅ Good
public Order(User customer, String reference) {
    this.customer = Objects.requireNonNull(customer);
    this.reference = Objects.requireNonNull(reference);
    this.status = OrderStatus.DRAFT;
    this.createdAt = Instant.now();
}

// ❌ Bad: entity created empty, then filled via setters
Order order = new Order();
order.setCustomer(customer);
order.setReference(reference);
order.setStatus(OrderStatus.DRAFT);
```

The protected no-arg constructor required by JPA stays `protected` so application code cannot use it.

### No Lombok `@Data` on entities

❌ **Forbidden on entities**: `@Data`, `@EqualsAndHashCode`, `@ToString` (and `@Value`).

- `@EqualsAndHashCode` over all fields breaks entity identity: the hash changes when the ID is assigned at persist, corrupting `HashSet`/`HashMap` membership.
- `@ToString` traverses lazy associations → `LazyInitializationException` or accidental full-graph loading in a log statement.
- `@Data` implies both, plus public setters on every field.

✅ Acceptable on entities: `@Getter`, `@NoArgsConstructor(access = AccessLevel.PROTECTED)`. If you need `equals`/`hashCode`, implement them on the ID only (null-ID-never-equal convention) or on a natural business key.

### Recommended Java types

| Java | Column | Notes |
|---|---|---|
| `Long` | `bigint` | preferred PK type |
| `String` | `varchar(N)` | always specify `length` |
| `String` (long) | `text` | `@Column(columnDefinition = "text")` |
| `boolean` | `boolean` | |
| `Instant` | `timestamptz` | ✅ prefer for timestamps (`createdAt`, `updatedAt`) |
| `LocalDate` | `date` | for date-only business fields |
| `BigDecimal` | `numeric(p, s)` | money/quantities — never `double` |
| Java enum | `varchar` | with `@Enumerated(EnumType.STRING)` |

### Temporals

Always use `Instant` for timestamps (`created_at timestamptz`) and `LocalDate` for date-only business fields (`due_date date`). ❌ Never `java.util.Date`, `java.sql.Timestamp`, or `Calendar` in new code.

### Enums

**Always** `@Enumerated(EnumType.STRING)`:

```java
public enum OrderStatus {
    DRAFT, SUBMITTED, APPROVED, REJECTED
}

@Enumerated(EnumType.STRING)
@Column(name = "status", length = 20, nullable = false)
private OrderStatus status;
```

❌ **Never `EnumType.ORDINAL`** (the implicit default): reordering or inserting an enum constant silently corrupts every stored value.

## Repositories

### Spring Data JpaRepository interfaces

```java
package com.example.app.domain.repository;

import com.example.app.domain.model.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    Page<User> findByActiveTrue(Pageable pageable);
}
```

### Derived-query naming conventions

| Method | Usage |
|---|---|
| `findById(Long id)` | By PK only (inherited) |
| `findByEmail(String email)` | By business criterion, returns `Optional<User>` |
| `existsByEmail(String email)` | Existence check — never `findBy...().isPresent()` |
| `countByStatus(OrderStatus status)` | Counting — never load entities to count them |
| `findByStatusOrderByCreatedAtDesc(...)` | Filtered + sorted listing |
| `findByStatus(OrderStatus s, Pageable p)` | Paginated listing |

❌ **No unpaged `findAll()`** on potentially large tables — always pass a `Pageable`. `findAll()` without pagination is only acceptable for small, bounded reference tables (a few hundred rows max).

### JPQL confined to repository interfaces

`@Query` annotations live **only** on repository interfaces. ❌ No `EntityManager.createQuery(...)`, no Criteria API in services or controllers.

```java
// ❌ Bad: JPQL in the service
return em.createQuery("select u from User u where u.createdAt > :since", User.class)
    .setParameter("since", since)
    .getResultList();

// ✅ Good: JPQL in the repository, service delegates
public interface UserRepository extends JpaRepository<User, Long> {
    @Query("select u from User u where u.createdAt > :since")
    Page<User> findCreatedSince(@Param("since") Instant since, Pageable pageable);
}
```

### Projections for read-only lists

For list screens and exports, do not hydrate full entities — use interface or record projections:

```java
public record UserSummary(Long id, String email, Instant createdAt) {}

@Query("select new com.example.app.domain.repository.UserSummary(u.id, u.email, u.createdAt) from User u")
Page<UserSummary> findSummaries(Pageable pageable);
```

❌ **No repository methods returning `Object[]`** or untyped `Map` rows.

## Relations

### `FetchType.LAZY` everywhere

⚠️ **`@ManyToOne` and `@OneToOne` default to EAGER** in JPA. Override them explicitly:

```java
@ManyToOne(fetch = FetchType.LAZY, optional = false)
@JoinColumn(name = "customer_id", nullable = false)
private User customer;
```

`@OneToMany` and `@ManyToMany` are already lazy by default — keep them that way. Only use `EAGER` in very specific, documented cases.

### Explicit cascade only when justified

```java
// ✅ Good: cascade documented in the spec (composition — lines die with the order)
@OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
private List<OrderLine> lines = new ArrayList<>();
```

❌ **No blind `CascadeType.ALL` on `@ManyToOne`** or between aggregates: deleting an order must never cascade-delete its customer.

### Bidirectional sync helper methods

A bidirectional relation must be synchronized on both sides through helper methods:

```java
public void addLine(OrderLine line) {
    lines.add(line);
    line.setOrder(this);
}
// mirror method removeLine(line) sets line.setOrder(null)
```

❌ Never expose a public `setLines(List<OrderLine>)`.

### Initialize collections at declaration

```java
@OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
private List<OrderLine> lines = new ArrayList<>();  // ← mandatory
```

## Flyway migrations

### Naming

```
src/main/resources/db/migration/
  V1.0.0__create_app_user_table.sql
  V1.1.0__add_email_verified_at_to_app_user.sql
  V1.1.1__create_idx_app_user_email.sql
```

Pattern: `V<major>.<minor>.<patch>__snake_case_description.sql` — double underscore separator, description in snake_case.

### Rules

- **One migration per schema change** — no giant migrations
- **NEVER edit a migration that has been applied** anywhere (even a dev environment): Flyway stores a checksum per applied migration and the next run fails on mismatch
- **Flyway is forward-only** — there is no `down()`. Recovery = write a **new compensating migration** that reverses the change
- **Test migrations locally** on a fresh database before committing

```sql
-- Mistake shipped in V1.1.0? Do NOT edit it. Compensate:
-- V1.1.1__drop_email_verified_at_from_app_user.sql
ALTER TABLE app_user DROP COLUMN email_verified_at;
```

### Hibernate must validate, never manage, the schema

`spring.jpa.hibernate.ddl-auto: validate` is the **only** allowed value outside throwaway sandboxes.

❌ **Never `update` or `create`/`create-drop`** on a shared or production database: the schema is owned by Flyway migrations, Hibernate only checks that the mapping matches.

### Indexes and constraints belong in migrations

`@Index` / `@UniqueConstraint` annotations are documentation for `validate` — with `ddl-auto: validate` they create nothing. Every index, unique constraint, and foreign key must exist in a migration:

```sql
-- V1.1.1__create_idx_app_user_email.sql
CREATE UNIQUE INDEX idx_app_user_email ON app_user (email);
CREATE INDEX idx_order_created_at ON customer_order (created_at);
```

### Column removal — always in 2 steps

**Step 1 — Deployment A**:
- Remove all references to the column in the code (entity field, queries, DTOs)
- No removal migration yet
- Deploy to Production

**Step 2 — Deployment B (weeks later)**:
- Create the `DROP COLUMN` migration
- Deploy

This avoids partial deployments that break production.

### Data in migrations

❌ Avoid putting business logic in migrations.  
✅ For initial reference data (seeds), a dedicated `V..._seed_...sql` migration with plain `INSERT`s is fine.  
✅ For complex data transformations, create a dedicated Spring Boot `ApplicationRunner` or batch job invoked after the migration.

## Performance

### N+1 queries

Always prefetch the relations you use:

```java
// ❌ Bad: N+1
List<Order> orders = orderRepository.findAll();
for (Order order : orders) {
    total += order.getLines().size();  // ← 1 query per order
}

// ✅ Good — option 1: @EntityGraph on the repository method
@EntityGraph(attributePaths = "lines")
Page<Order> findByStatus(OrderStatus status, Pageable pageable);

// ✅ Good — option 2: JPQL fetch join
@Query("select o from Order o join fetch o.lines where o.id = :id")
Optional<Order> findByIdWithLines(@Param("id") Long id);
```

Detect N+1 in dev by enabling SQL logging (`spring.jpa.properties.hibernate.format_sql=true` + logger `org.hibernate.SQL: DEBUG`) and watching for repeated identical selects.

### Pagination

Any list endpoint or batch read goes through `Pageable`. ⚠️ Paginating a query with a collection `join fetch` forces in-memory pagination (Hibernate logs `HHH90003004`) — paginate on the root entity, then fetch collections in a second query.

### `getReferenceById` vs `findById`

`getReferenceById(id)` returns a lazy proxy **without hitting the database** — ideal to set a `@ManyToOne` FK. But any access to a non-ID field triggers loading, and a missing row surfaces later as `EntityNotFoundException`. Use `findById` whenever you actually read the entity.

```java
// ✅ Good: FK assignment without a select
order.setCustomer(userRepository.getReferenceById(customerId));
```

### Open Session In View

`spring.jpa.open-in-view` defaults to `true`: the persistence context stays open during view/JSON rendering, hiding lazy-loading bugs and holding connections longer.

✅ Set `spring.jpa.open-in-view: false` for new projects. Every lazy access outside a transaction then fails fast (`LazyInitializationException`) → fetch what you need explicitly in the service/repository layer.

## Anti-patterns to ban

- ❌ Public setters on every field; Lombok `@Data`/`@EqualsAndHashCode`/`@ToString` on entities
- ❌ `EnumType.ORDINAL` (implicit default of `@Enumerated`)
- ❌ Relying on implicit table/column naming instead of explicit snake_case `@Table`/`@Column`
- ❌ `EntityManager` queries or Criteria API in services/controllers
- ❌ `EAGER` fetching left as the `@ManyToOne`/`@OneToOne` default
- ❌ Unsynchronized bidirectional relations (setting one side without the other)
- ❌ Blind `CascadeType.ALL` between aggregates
- ❌ Editing an already-applied Flyway migration (checksum mismatch)
- ❌ `ddl-auto: update` or `create` outside a throwaway sandbox
- ❌ Removing a column in the same deployment as the code that used it
- ❌ Unpaged `findAll()` on a large table
- ❌ Business logic in entities (except trivial invariants) or in migrations
