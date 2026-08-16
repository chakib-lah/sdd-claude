---
description: Scaffold a Spring service (interface + implementation) from a SDD spec
---

# /java-service

**Auxiliary scaffolding command**: create a Spring service with its interface, ready to be injected.

## Blocking prerequisites

- Active SDD feature with `tasks.md` `status: approved`
- Current task mentions the creation of the service
- Conventions available: `.claude/rules/10-code-conventions.md`

## Steps

### 1. Identify the service to create

Ask for:
- Service name (PascalCase, `Service` suffix): `UserService`, `OrderService`
- Functional domain: `user`, `order`, etc.

Detect the architecture to pick the layout:

```bash
find src/main/java -type d \( -name "application" -o -name "usecase" \) | head -5
```

- Hexagonal/DDD layout → interface in `<domain>.domain.service` + `<Name>ServiceImpl` in `<domain>.application`
- Standard layering → single `@Service` class in `com.example.app.service`

Follow whichever convention the codebase already uses.

### 2. Load the SDD context

Read `spec.md` (Design section → Services involved) to retrieve:
- Responsibility of the service (a single one)
- Dependencies to inject
- Expected public methods
- Business exceptions to throw
- DTO ⇄ entity conversions involved

### 3. Load the conventions

Read `.claude/rules/10-code-conventions.md` to comply with:
- Constructor injection only (`private final` fields, no field `@Autowired`)
- One responsibility per service
- `Optional` instead of null returns
- `@Transactional` boundaries at service level (`readOnly = true` for queries)

### 4. Check for duplicates

```bash
find src/main/java -name "<Name>Service*.java" | head -5
```

### 5. Generate the interface (hexagonal layout)

```java
package com.example.app.<domain>.domain.service;

public interface <Name>Service {

    <Return> <query>(<params>);

    <Return> <command>(<params>);
}
```

### 6. Generate the implementation

```java
package com.example.app.<domain>.application;

import com.example.app.<domain>.domain.repository.<Entity>Repository;
import com.example.app.<domain>.domain.service.<Name>Service;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class <Name>ServiceImpl implements <Name>Service {

    private final <Entity>Repository repository;
    private final <Entity>Mapper mapper;

    public <Name>ServiceImpl(<Entity>Repository repository, <Entity>Mapper mapper) {
        this.repository = repository;
        this.mapper = mapper;
    }

    @Override
    public <Return> <query>(<params>) {
        // Skeleton to implement via /sdd-implement
        throw new UnsupportedOperationException("To implement via /sdd-implement");
    }

    @Override
    @Transactional // write operation → overrides the class-level readOnly
    public <Return> <command>(<params>) {
        throw new UnsupportedOperationException("To implement via /sdd-implement");
    }
}
```

### 7. Standard layering variant (no interface)

Generate a single `@Service` class directly, same content without `implements`:

```java
@Service
@Transactional(readOnly = true)
public class <Name>Service {
    // private final dependencies + constructor injection
    // Public methods, @Transactional on write operations
}
```

### 8. Identify the exceptions to create

If the spec mentions business error cases that do not yet have a dedicated exception, propose creating them, extending the base domain exception:

```java
package com.example.app.<domain>.domain.exception;

public class <Entity>NotFoundException extends DomainException {

    public <Entity>NotFoundException(Long id) {
        super("<Entity> %d not found".formatted(id));
    }
}
```

If no base `DomainException` exists yet, create it once:

```java
public abstract class DomainException extends RuntimeException {
    protected DomainException(String message) {
        super(message);
    }
}
```

### 9. MapStruct mapper (if DTO ⇄ entity conversion is involved)

```java
package com.example.app.<domain>.application.mapper;

import org.mapstruct.Mapper;

@Mapper(componentModel = "spring")
public interface <Entity>Mapper {

    <Entity>Dto toDto(<Entity> entity);
}
```

If MapStruct is not on the classpath, either propose adding the dependency + annotation processor, or fall back to a static factory method on the DTO. Never map field by field inside the service.

### 10. Display and validate

Before writing, display in the chat:
- Interface (if hexagonal layout)
- Service implementation
- Exceptions to create (if applicable)
- Mapper (if applicable)

Ask for confirmation.

### 11. Write the files

- `src/main/java/.../<Name>Service.java` (interface, if applicable)
- `src/main/java/.../<Name>ServiceImpl.java` (or single `<Name>Service.java`)
- `src/main/java/.../<Entity><Reason>Exception.java` (if applicable)
- `src/main/java/.../<Entity>Mapper.java` (if applicable)

### 12. Announce

```
✅ Service created: src/main/java/.../<Name>ServiceImpl.java
✅ Interface created: src/main/java/.../<Name>Service.java (if applicable)
✅ Exception(s) created: src/main/java/.../exception/...
✅ Mapper created: src/main/java/.../<Entity>Mapper.java (if applicable)

Note: Spring component scanning picks the service up, no manual config needed.

Next steps:
- /java-test to scaffold the unit tests
- /sdd-implement to fill in the business logic
```

## Stop rules

- **Never overwrite an existing file**
- **Do not fill in the business logic**: that is the role of `/sdd-implement`
- **One responsibility per service**: if the intended scope exceeds it, suggest splitting into several services rather than creating a God service
- **Always inject via the constructor** with `private final` fields (never field injection)
- **No repository query logic inside the service**: derived queries and `@Query` live on the repository interface
- **No web/HTTP concerns in the service**: no `ResponseEntity`, no status codes, no servlet API
- **`@Transactional` at service level only**: `readOnly = true` for queries, plain `@Transactional` on writes
