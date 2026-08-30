---
description: Scaffold a Spring REST controller with route, request DTO, and response from a SDD spec
---

# /java-controller

**Auxiliary scaffolding command**: create a `@RestController` with its route, request record and response record, documented for OpenAPI.

## Blocking prerequisites

- Active SDD feature with `tasks.md` `status: approved`
- Current task mentions the creation of the endpoint
- Conventions available: `.claude/rules/10-code-conventions.md`
- The business service being used exists (otherwise create it first via `/java-service`)

## Steps

### 1. Identify the controller to create

Ask for:
- Resource (PascalCase): `User`, `Order`, `Invoice`
- HTTP method: GET / POST / PUT / PATCH / DELETE
- Route: `/api/users/{id}`, `/api/orders`, etc.
- Access control: authenticated / specific role / deliberately public (justification required)

### 2. Load the SDD context

Read `spec.md` (Design section → Endpoint(s)) to retrieve:
- Request payload format
- Response format
- Expected HTTP status codes (200, 201, 400, 404, etc.)
- Error cases to handle
- Security-tagged acceptance criteria (roles, ownership rules)

### 3. Load the conventions

Read `.claude/rules/10-code-conventions.md` to comply with:
- Thin controllers (no business logic)
- Java records for request/response DTOs
- Bean Validation on every inbound payload
- springdoc annotations on every endpoint
- Uniform error format via the shared advice

### 4. Check for duplicates

```bash
find src/main/java -name "<Resource>Controller.java" | head -5
```

If the controller exists, add the new endpoint method to it instead of creating a second controller for the same resource.

### 5. Generate the request record (if applicable)

For POST/PUT/PATCH methods with a payload, a Java record with `jakarta.validation` constraints:

```java
package com.example.app.<domain>.api.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record Create<Resource>Request(

    @NotBlank
    @Email
    String email,

    @NotBlank
    @Size(min = 8)
    String password
) {
}
```

### 6. Generate the response record

```java
package com.example.app.<domain>.api.response;

import java.time.Instant;

public record <Resource>Response(
    Long id,
    String email,
    Instant createdAt
) {

    public static <Resource>Response from(<Resource>Dto dto) {
        return new <Resource>Response(dto.id(), dto.email(), dto.createdAt());
    }
}
```

If a MapStruct mapper already exists for this resource, map through it instead of the static factory — do not maintain both.

### 7. Generate the controller

springdoc annotations (`@Tag`, `@Operation`, `@ApiResponse`) are REQUIRED on every endpoint so the OpenAPI contract stays complete.

Typical skeleton for a GET:

```java
package com.example.app.<domain>.api;

import com.example.app.<domain>.api.response.<Resource>Response;
import com.example.app.<domain>.domain.service.<Resource>Service;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/<resources>")
@Tag(name = "<Resources>")
public class <Resource>Controller {

    private final <Resource>Service service;

    public <Resource>Controller(<Resource>Service service) {
        this.service = service;
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get a <resource> by id")
    @ApiResponse(responseCode = "200", description = "<Resource> found")
    @ApiResponse(responseCode = "404", description = "<Resource> not found")
    public <Resource>Response get(@PathVariable Long id) {
        return <Resource>Response.from(service.getById(id));
    }
}
```

Typical skeleton for a POST (added to the same controller):

```java
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create a <resource>")
    @ApiResponse(responseCode = "201", description = "<Resource> created")
    @ApiResponse(responseCode = "400", description = "Invalid payload")
    public <Resource>Response create(@Valid @RequestBody Create<Resource>Request request) {
        return <Resource>Response.from(service.create(request));
    }
```

Typical skeleton for a DELETE:

```java
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a <resource>")
    @ApiResponse(responseCode = "204", description = "<Resource> deleted")
    @ApiResponse(responseCode = "404", description = "<Resource> not found")
    public void delete(@PathVariable Long id) {
        service.delete(id);
    }
```

`@Valid` on the payload parameter is mandatory: without it the record's constraints are silently ignored.

### 8. Error handling

Error handling is delegated to the shared `@RestControllerAdvice` (RFC 9457 `ProblemDetail`). Never try/catch in the controller: throw the business exception and let the advice translate it.

Check that the advice covers the endpoint's error cases; if it does not exist yet, create it once:

```java
@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(<Resource>NotFoundException.class)
    public ProblemDetail handleNotFound(<Resource>NotFoundException ex) {
        // domain exception messages are controlled; NEVER copy raw exception messages
        // from unexpected exceptions into the response
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        problem.setDetail("Validation failed");
        // Attach field errors as a "violations" property
        return problem;
    }
}
```

### 9. Security (mandatory decision)

Every endpoint requires an explicit access-control decision — pick exactly one:

- **Specific role**: `@PreAuthorize("hasRole('...')")` — the spec restricts the endpoint to a role
- **Authenticated**: `@PreAuthorize("isAuthenticated()")` — any logged-in user may call it
- **Deliberately public**: no annotation — allowed only with a one-line justification, echoed in the confirmation step

This choice is never skipped, even when the spec has no security-tagged acceptance criteria: `.claude/rules/02-security.md` treats "no annotation = public" as a bug, so an unannotated endpoint must be a documented decision, not an omission.

Example with a specific role:

```java
import org.springframework.security.access.prepost.PreAuthorize;

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('USER')")
    public <Resource>Response get(@PathVariable Long id) {
        // ...
    }
```

For ownership rules (`user can only read their own <resource>`), delegate to a method-security expression or a dedicated authorization component — never an `if` in the controller.

### 10. Display and validate

Before writing, display in the chat:
- Request record
- Response record
- Controller (or new endpoint method)
- Advice changes (if any)
- Access-control decision: specific role / authenticated / deliberately public (with its one-line justification)

Ask for confirmation.

### 11. Write the files

- `src/main/java/.../<Resource>Controller.java`
- `src/main/java/.../Create<Resource>Request.java` (if POST/PUT/PATCH)
- `src/main/java/.../<Resource>Response.java`

### 12. Verify the route

With the application running, confirm the route appears in the OpenAPI contract:

```bash
curl -s http://localhost:8080/v3/api-docs | jq '.paths | keys'
```

If the application cannot be started here, the route must instead be covered by a `@WebMvcTest` (scaffolded via `/java-test`).

### 13. Announce

```
✅ Controller: src/main/java/.../<Resource>Controller.java
✅ Request record: src/main/java/.../Create<Resource>Request.java
✅ Response record: src/main/java/.../<Resource>Response.java

Route registered:
  <METHOD> <route> → visible in /v3/api-docs (or covered by @WebMvcTest)

Next steps:
- /java-test to scaffold the web slice tests
- /sdd-implement to finalize the logic
```

## Stop rules

- **Thin controller**: no business logic, delegate everything to the service
- **No repository or `EntityManager` access** in the controller: go through the service
- **Never expose entities directly**: request and response are records only
- **Never try/catch in the controller**: uniform error format via the shared `@RestControllerAdvice` and `ProblemDetail`
- **Always `@Valid`** on payload parameters, with constraints declared on the record
- **Always the springdoc annotations** (`@Tag`, `@Operation`, `@ApiResponse`): an undocumented endpoint breaks the OpenAPI contract
- **Always specify explicit status codes** (`@ResponseStatus(HttpStatus.CREATED)`, documented `@ApiResponse`)
- **Never generate an endpoint without an explicit access-control decision**: specific role, authenticated, or deliberately public — and "deliberately public" must be justified in one line
