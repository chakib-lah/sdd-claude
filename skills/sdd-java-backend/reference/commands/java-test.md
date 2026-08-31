---
description: Scaffold JUnit tests (unit, slice, integration) from a SDD spec for Spring Boot
---

# /java-test

**Auxiliary scaffolding command**: create the JUnit 5 tests for an existing Spring class (Service, Repository, Controller).

## Blocking prerequisites

- Active SDD feature with `tasks.md` `status: approved`
- The class under test must already exist
- Conventions available: `.claude/rules/11-tests-strategy.md`

## Steps

### 1. Identify the class to test

Ask for:
- Path to the class under test (e.g. `src/main/java/com/example/app/user/application/UserServiceImpl.java`)
- Test type: `Unit`, `Repository slice`, `Web slice` or `Integration`

Automatic suggestion based on the class:
- Business service → `Unit` (Mockito for repositories and mappers)
- Repository → `Repository slice` (`@DataJpaTest` + embedded PostgreSQL or Testcontainers)
- Controller → `Web slice` (`@WebMvcTest` + MockMvc, service mocked)
- Full user flow across layers → `Integration` (`@SpringBootTest(webEnvironment = RANDOM_PORT)`)
- Value object / validator / mapper → `Unit`

### 2. Load the conventions and discover the project's test setup

Read `.claude/rules/11-tests-strategy.md` to comply with:
- Directory structure (`src/test/java`, mirrored packages)
- AAA pattern (Arrange / Act / Assert)
- AssertJ for all assertions
- **Test method naming**: `should<Action>When<Condition>` (e.g. `shouldReturn404WhenUserDoesNotExist`)

Then **discover the project's suite convention** — read the build configuration (Gradle build files/included scripts, or the POM's surefire/failsafe setup) and the wrapper location (which may be the repository root) before generating or running anything:

- **How the suites split**: name patterns (`*Test` vs `*IT` / `*IntTest` / `*IntegrationTest`), dedicated source sets (`src/integrationTest/java`), or tags — all valid; follow the one in place, never introduce a second incompatible convention.
- **Which tasks/goals run them**: custom Gradle tasks like `unitTest` / `integrationTest` are a common convention but **not built-in** — a project may only define the default `test` task. Maven: surefire (`test`) / failsafe (`verify`).
- Greenfield defaults when nothing is established: `<Class>Test` → unit suite (no full Spring context and no real database: pure Mockito, and web slices via `@WebMvcTest`); `<Class>IT` → integration suite (full context via `@SpringBootTest`, or a real database via `@DataJpaTest` with embedded PostgreSQL/Testcontainers)

### 3. Load the SDD context

Read `spec.md` to retrieve the **acceptance criteria**. Each AC becomes at least one test.

### 4. Read the class under test

Identify:
- Package and name
- Injected dependencies (constructor) → to mock in Unit tests
- Public methods → each must have at least one test
- Error cases (thrown exceptions) → dedicated tests

### 5. Generate the skeleton according to the type

#### Type: Unit (Mockito)

```java
package com.example.app.user.application;

// JUnit 5 + Mockito imports, plus:
import static org.assertj.core.api.Assertions.*;
import static org.mockito.BDDMockito.given;

@ExtendWith(MockitoExtension.class)
class UserServiceImplTest {

    @Mock
    private UserRepository repository;

    @Mock
    private UserMapper mapper;

    @InjectMocks
    private UserServiceImpl sut;

    @Test
    void shouldReturnUserWhenFound() {
        // Covers AC-1: <AC statement>
        // Arrange
        User user = User.create("alice@example.com");
        given(repository.findById(42L)).willReturn(Optional.of(user));
        given(mapper.toDto(user)).willReturn(new UserDto(42L, "alice@example.com"));

        // Act
        UserDto result = sut.getById(42L);

        // Assert
        assertThat(result.email()).isEqualTo("alice@example.com");
    }

    @Test
    void shouldThrowWhenUserNotFound() {
        // Covers AC-2: <AC statement>
        // Arrange
        given(repository.findById(42L)).willReturn(Optional.empty());

        // Act / Assert
        assertThatThrownBy(() -> sut.getById(42L))
            .isInstanceOf(UserNotFoundException.class);
    }

    @Test
    @Disabled("To implement via /sdd-implement")
    void shouldRejectDuplicateEmail() {
        // Covers AC-3: <AC statement>
        fail("Not yet implemented");
    }

    // One test per additional AC
}
```

#### Type: Repository slice (@DataJpaTest)

```java
package com.example.app.user.domain.repository;

// Spring Boot test + Testcontainers imports, plus:
import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class UserRepositoryIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private UserRepository sut;

    @Autowired
    private TestEntityManager em;

    @Test
    void shouldPersistAndRetrieveUser() {
        // Covers AC-1: <statement>
        // Arrange
        User user = em.persistFlushFind(User.create("alice@example.com"));
        em.clear();

        // Act
        Optional<User> found = sut.findByEmail("alice@example.com");

        // Assert
        assertThat(found).isPresent();
        assertThat(found.get().getId()).isEqualTo(user.getId());
    }

    @Test
    void shouldReturnEmptyWhenEmailNotFound() {
        assertThat(sut.findByEmail("nobody@example.com")).isEmpty();
    }
}
```

If the project already uses an embedded PostgreSQL (a real postgres binary on a temporary data directory) instead of Testcontainers, follow the existing setup — do not introduce a second database strategy.

#### Type: Web slice (@WebMvcTest)

```java
package com.example.app.user.api;

// Spring web slice imports, plus:
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserService service;

    @Test
    void shouldReturn200WhenUserExists() throws Exception {
        // Covers AC-1: <statement>
        given(service.getById(1L)).willReturn(new UserDto(1L, "alice@example.com"));

        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.email").value("alice@example.com"));
    }

    @Test
    void shouldReturn404WhenUserDoesNotExist() throws Exception {
        given(service.getById(999L)).willThrow(new UserNotFoundException(999L));

        mockMvc.perform(get("/api/users/999"))
            .andExpect(status().isNotFound());
    }

    @Test
    void shouldReturn400WhenPayloadInvalid() throws Exception {
        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\": \"invalid\"}"))
            .andExpect(status().isBadRequest());
    }
}
```

#### Type: Integration (@SpringBootTest)

```java
package com.example.app.user;

// Spring Boot test + Testcontainers imports, plus:
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class CreateUserFlowIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository repository;

    @AfterEach
    void cleanUp() {
        repository.deleteAll();
    }

    @Test
    void shouldCreateUserEndToEnd() {
        // Covers AC-1: <statement>
        // Arrange
        var request = new CreateUserRequest("alice@example.com", "s3cret-password");

        // Act
        ResponseEntity<UserResponse> response =
            restTemplate.postForEntity("/api/users", request, UserResponse.class);

        // Assert
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(repository.findByEmail("alice@example.com")).isPresent();
    }
}
```

### 6. Generate one test per AC

For each AC in `spec.md`, create a test method with a `// Covers AC-n` comment. If the implementation is not obvious, disable it explicitly:

```java
@Test
@Disabled("To implement via /sdd-implement")
void should<Action>When<Condition>() {
    // Covers AC-X: <exact AC statement>
    fail("Not yet implemented");
}
```

### 7. Parameterized tests for multi-case criteria

If several similar ACs exist (validation for example), propose a `@ParameterizedTest`:

```java
@ParameterizedTest
@CsvSource({
    "'', Email must not be blank",
    "plaintext, Invalid email format",
    "'  ', Email must not be blank"
})
void shouldRejectInvalidEmail(String email, String expectedError) {
    assertThatThrownBy(() -> User.create(email))
        .isInstanceOf(InvalidEmailException.class)
        .hasMessageContaining(expectedError);
}
```

For non-scalar cases, use `@MethodSource` with a `static Stream<Arguments>` provider named after the test.

### 8. Display and validate

Before writing:
- Display the list of generated tests (with AC ↔ test mapping)
- Ask for confirmation

### 9. Write the file

Path mirrors the class under test; suffix and location follow the **discovered** suite convention (greenfield defaults shown):
- `src/test/java/.../UserServiceImplTest.java` (unit)
- `src/test/java/.../UserRepositoryIT.java` (repository slice)
- `src/test/java/.../UserControllerTest.java` (web slice — no full context, no real database)
- `src/test/java/.../CreateUserFlowIT.java` (integration)

On a project with a dedicated integration source set or another suffix (`*IntTest`, `*IntegrationTest`…), place and name the file so the existing build picks it up.

### 10. Verify that the tests run in the right suite

Run the **discovered** tasks/goals via the project wrapper, from the discovered backend root (which may be the repository root). The class name passed to the filter is the **actual generated test class** — whatever name the discovered convention produced (`UserServiceTest`, `UserServiceIT`, `UserServiceIntTest`, `UserServiceIntegrationTest`, a dedicated-source-set class…) — never a suffix assumed at execution time:

```bash
# Gradle — the project's own tasks (greenfield defaults: unitTest / integrationTest —
# invoke a task only if the build defines it; a project without a split only has
# `test` — use it, with its supported filtering syntax where appropriate)
./gradlew <discovered-unit-test-task> --tests '<generated-unit-test-class>'
./gradlew <discovered-integration-test-task> --tests '<generated-integration-test-class>'

# Maven — through the project's established Surefire/Failsafe configuration
mvn -Dtest=<generated-unit-test-class> test
mvn -Dit.test=<generated-integration-test-class> verify
```

A unit-suite class that boots a full Spring context or touches a real database is in the wrong suite: move/rename it per the discovered integration convention. Web slices (`@WebMvcTest`) stay in the unit suite.

### 11. Announce

```
✅ Tests scaffolded: <path to the generated test class, named per the discovered suite convention>

Tests generated: N
  - N ACs covered
  - X complete tests
  - Y disabled tests (to finalize via /sdd-implement)

Next step:
- Implement the tests via /sdd-implement
- Run regularly: the discovered unit suite (fast) and integration suite (before push)
```

## Stop rules

- **At least one test per acceptance criteria**
- **No assertion-free tests, no `assertThat(true)`**: use `@Disabled` + `fail()` for placeholders
- **Never edit a test to make failing code pass**: fix the code, or flag the spec mismatch
- **No mocking of the class under test**: only dependencies are mocked
- **No business logic in the tests**: if you write an `if`, split into several tests
- **No required execution order** between tests
- **Suite membership follows the discovered project convention**: a unit-suite class must not boot a full Spring context or a real database (web slices `@WebMvcTest` are fine); anything that does belongs to the integration suite (greenfield default: rename `<Class>Test` → `<Class>IT`)
- **For slice and integration tests**: clean database state (`@DataJpaTest` rollback, or explicit cleanup in `@AfterEach`)
- **No tests that depend on the clock** without an injectable `Clock`
- **Document each test with the AC it covers** (`// Covers AC-n` comment)
