# Test strategy — Java / Spring Boot

> **Layer 2 — Specific to the Java/Spring Boot stack.**

---

## Tools — required capability, discovered parameters

- **Test framework**: JUnit 5 (Jupiter) — **required**
- **Mocking**: Mockito (`@ExtendWith(MockitoExtension.class)`)
- **Assertions**: AssertJ (`assertThat(...)`) — not Hamcrest, not bare JUnit asserts
- **Spring support**: `spring-boot-starter-test` (includes all of the above)
- **Integration DB**: the project's **discovered strategy** — integration tests exercise a real or representative database engine when database-specific behavior matters. Testcontainers with the **production engine's** image is the common example; an established embedded setup (e.g. an embedded PostgreSQL such as Zonky on a PostgreSQL project) is equally valid — follow the strategy in place, never introduce a second one, and never impose PostgreSQL infrastructure on a project whose production database is another engine
- **Coverage**: the configured tool (JaCoCo is the common example — see `.claude/rules/12-quality-gates.md`)

## Discovery first

**JUnit 5 automated tests are required.** How the project splits and runs them is a set of **project facts** — read the build configuration under the discovered backend root (which may be the repository root) before generating or running anything:

- **Build tool and wrapper**: Gradle (`./gradlew` at its actual location, `build.gradle` or `build.gradle.kts`) or Maven (`./mvnw`/`mvn`, `pom.xml`) — never assume the wrapper sits in a fixed subdirectory.
- **Test tasks/goals**: list what the build defines (`./gradlew tasks`, or the POM's surefire/failsafe configuration). Custom `unitTest`/`integrationTest` tasks are a common convention — often declared in an included build script — but they are **not built-in Gradle facts**; a project may only have the default `test` task.
- **Suite/naming convention**: name-pattern splits (`*Test` vs `*IT` / `*IntTest` / `*IntegrationTest`), dedicated source sets (`src/integrationTest/java`), or tag-based splits are all valid established conventions — discover the one in place and follow it; never introduce a second incompatible convention.
- **Database strategy**: Testcontainers, an existing embedded database setup, or a CI database service — follow the existing setup.

Missing test infrastructure is a **PROJECT_TOOLING_GAP** (see `.claude/rules/12-quality-gates.md`).

## Test organization

`src/test/java` mirrors `src/main/java` package for package:

```
src/test/java/com/example/app/
├── application/service/
│   └── UserServiceImplTest.java        ← unit (mocks)
├── infrastructure/persistence/
│   └── UserRepositoryIT.java           ← repository slice (real DB)
├── infrastructure/web/
│   └── UserControllerTest.java         ← web slice (MockMvc)
└── UserApiIT.java                      ← full integration (random port)
```

### Unit / integration split (greenfield default: class-name pattern)

The split below is the **greenfield default** — an existing project's discovered convention (another suffix, dedicated source sets, tags) takes precedence:

- `*Test` → no full Spring context and no real database: pure unit tests AND web slices (`@WebMvcTest`)
- `*IT` (or `*IntTest`, Gradle-only) → full context (`@SpringBootTest`) or real database (`@DataJpaTest` with the project's discovered DB strategy)

Gradle task split (**greenfield example** — `unitTest`/`integrationTest` are not built-in Gradle tasks; existing projects often declare the same split in a dedicated build script — discover theirs instead of re-declaring):

```groovy
tasks.register('unitTest', Test) {
    useJUnitPlatform()
    testClassesDirs = sourceSets.test.output.classesDirs
    classpath = sourceSets.test.runtimeClasspath
    include '**/*Test.class'
    exclude '**/*IT.class', '**/*IntTest.class'
}

tasks.register('integrationTest', Test) {
    useJUnitPlatform()
    testClassesDirs = sourceSets.test.output.classesDirs
    classpath = sourceSets.test.runtimeClasspath
    include '**/*IT.class', '**/*IntTest.class'
    shouldRunAfter tasks.named('unitTest')
}

tasks.named('check') {
    dependsOn 'unitTest', 'integrationTest'
}
```

Note: the default `test` task still runs everything. When the split tasks are wired
into `check`, exclude the default task from it (`check.dependsOn.remove(tasks.named('test'))`
— or, alternatively, `test.enabled = false`) to avoid running every test twice.

Maven equivalent: Surefire runs `*Test` during `test`, Failsafe runs `*IT` during
`verify` (declare the `maven-failsafe-plugin` with the `integration-test` and `verify`
goals). Only the `*IT` suffix is picked up by Failsafe defaults; other suffixes
(`*IntTest`, `*IntegrationTest`…) require explicit `<includes>` configuration.

## Test categories

### Unit tests (`*Test`)

For: business services, mappers, validators, pure logic. No Spring context.

```java
@ExtendWith(MockitoExtension.class)
class UserServiceImplTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private UserMapper userMapper;

    @InjectMocks
    private UserServiceImpl sut;

    @Test
    void shouldReturnEmptyWhenUserNotFound() {
        // Arrange
        when(userRepository.findById(42L)).thenReturn(Optional.empty());

        // Act
        Optional<UserResponse> result = sut.findById(42L);

        // Assert
        assertThat(result).isEmpty();
    }

    @Test
    void shouldThrowWhenEmailAlreadyExists() {
        // Arrange
        when(userRepository.existsByEmail("dup@example.com")).thenReturn(true);
        CreateUserRequest request = new CreateUserRequest("dup@example.com", "secret123", null);

        // Act + Assert
        assertThatThrownBy(() -> sut.create(request))
            .isInstanceOf(UserAlreadyExistsException.class)
            .hasMessageContaining("dup@example.com");
    }
}
```

### Repository slice tests (`*IT`, `@DataJpaTest`)

For: Spring Data repositories, custom queries, JPA mappings — against a real or representative instance of the **project's database engine**, via the discovered strategy.

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@AutoConfigureEmbeddedDatabase(provider = ZONKY)   // PostgreSQL-project example — or a Testcontainers @ServiceConnection with the production engine's image
class UserRepositoryIT {

    @Autowired
    private UserRepository sut;

    @Test
    void shouldFindUserByEmail() {
        // Arrange
        sut.save(aUser().withEmail("test@example.com").build());

        // Act
        Optional<User> found = sut.findByEmail("test@example.com");

        // Assert
        assertThat(found).isPresent()
            .get().extracting(User::getEmail).isEqualTo("test@example.com");
    }
}
```

### Web slice tests (`*Test`, `@WebMvcTest`)

For: controller request/response contracts, validation, error mapping — services mocked.

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserService userService;

    @Test
    void shouldReturn404WhenUserNotFound() throws Exception {
        // Arrange
        when(userService.findById(99L)).thenReturn(Optional.empty());

        // Act + Assert
        mockMvc.perform(get("/api/users/99"))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.title").value("Resource not found"));
    }

    @Test
    void shouldReturn400OnInvalidEmail() throws Exception {
        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"not-an-email\",\"password\":\"secret123\"}"))
            .andExpect(status().isBadRequest());
    }
}
```

### Full integration tests (`*IT`, `@SpringBootTest`)

For: end-to-end backend flows over real HTTP, with a real DB.

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("ci")
class UserApiIT {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void shouldCreateUserAndRetrieveIt() {
        // Arrange
        CreateUserRequest request = new CreateUserRequest("new@example.com", "secret123", "Jane");

        // Act
        ResponseEntity<UserResponse> created =
            restTemplate.postForEntity("/api/users", request, UserResponse.class);

        // Assert
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(created.getBody().email()).isEqualTo("new@example.com");
    }
}
```

> **Spring Boot 4 note**: Boot 4 unifies MockMvc, WebTestClient and TestRestTemplate
> behind **RestTestClient**. On Boot 4 projects, prefer `RestTestClient` for both
> web slice and full integration tests.

## Naming conventions

### Files

- Suffix and location follow the **discovered** suite convention (greenfield defaults: `<ClassName>Test.java` for unit/slice tests, `<ClassName>IT.java` for integration — a project on `*IntTest`, `*IntegrationTest` or a dedicated source set keeps its own)
- Placed in the mirror package: `main/.../UserServiceImpl.java` → `test/.../UserServiceImplTest.java`

### Test methods

- `should<Action>When<Condition>`: `shouldReturnEmptyWhenUserNotFound`
- One behavior per test; multiple assertions only if they check the same behavior
- Optional `@DisplayName` for long business rules

### Parameterized tests for multiple cases

```java
@ParameterizedTest
@CsvSource({
    "'', Cannot be empty",
    "plaintext, Invalid format",
    "'  ', Cannot be empty"
})
void shouldRejectInvalidEmail(String email, String expectedError) {
    assertThatThrownBy(() -> new Email(email))
        .isInstanceOf(InvalidEmailException.class)
        .hasMessageContaining(expectedError);
}
```

Use `@MethodSource` when cases need complex objects.

### Test-data builders instead of shared fixtures

```java
public class UserTestBuilder {

    private String email = "default@example.com";
    private UserStatus status = UserStatus.ACTIVE;

    public static UserTestBuilder aUser() { return new UserTestBuilder(); }

    public UserTestBuilder withEmail(String email) { this.email = email; return this; }
    public UserTestBuilder inactive() { this.status = UserStatus.INACTIVE; return this; }

    public User build() { return new User(email, status); }
}
```

Each test builds exactly the data it needs — no shared mutable fixture classes.

### Time-dependent code

Inject a `java.time.Clock` bean and use `Clock.fixed(...)` in tests. Never call
`Instant.now()` / `LocalDate.now()` directly in business code.

## Execution commands

`/sdd-implement` and `/sdd-verify` run the **discovered** commands — resolve them once from the build configuration and reuse them consistently. A resolved command is a **complete invocation**, not a working directory plus a task name: it encodes the discovered wrapper executable **at its actual location**, the invocation working directory, the module/project selector where the build is multi-module/multi-project, the task/goal and any configured options. The wrapper location and the backend root are **independent discovered facts** — a repository-root wrapper may drive a nested module just as validly as a wrapper living inside the backend root; never assume the wrapper sits in the backend root.

```bash
# Discovered complete invocations — resolve once, reuse; invoke only tasks/goals the build defines
<backend-test-command>               # the whole suite (Gradle default `test` / Maven `verify`)
<backend-unit-test-command>          # the discovered fast suite (greenfield default task: unitTest)
<backend-integration-test-command>   # the discovered integration suite (greenfield default task: integrationTest)
<backend-coverage-command>           # e.g. resolves to the configured jacocoTestReport — only if configured

# Example resolutions (valid shapes, NOT universal syntax):
#   <repo-root>/gradlew :apps:backend:test        — root wrapper + nested Gradle module selector
#   cd <backend-root> && ./gradlew test           — wrapper inside the backend root
#   <repo-root>/mvnw -pl <module> test            — root Maven wrapper + module targeting
#   cd <backend-root> && ./mvnw verify            — wrapper inside the Maven module
#   <maven-invocation> -Dtest=ClassName test      — a single test class via Surefire
```

Never invoke a task/goal the build does not define — a project without a split only has `test`/`verify`.

## Target coverage

Review and greenfield targets — the enforced gate is the project's **configured** thresholds (see `.claude/rules/12-quality-gates.md`), plus no coverage regression on changed code. Never present this table as a project's current truth.

| Code type | Target coverage |
|---|---|
| Business services | ≥ 90% |
| Mappers / validators | 100% (mostly generated + trivial) |
| Repositories (custom queries) | ≥ 80% (via `@DataJpaTest`) |
| Controllers | ≥ 70% (via `@WebMvcTest` / integration) |
| Legacy code | no threshold, but cover fixed bugs |

## Best practices

### Test isolation

Each test must run independently and in any order. Reset DB state per test
(`@Transactional` rollback on slice tests, or explicit cleanup in `@BeforeEach`
for `RANDOM_PORT` tests where the HTTP call runs in another transaction).

### Speed budgets

- Unit tests: ≤ 50ms per test (no Spring context)
- Slice tests (`@DataJpaTest`, `@WebMvcTest`): ≤ 500ms per test (context cached)
- Full integration tests: ≤ 2s per test

If a test is slower, that's a warning signal — usually an uncached Spring context
(avoid `@DirtiesContext`, avoid gratuitous `@MockitoBean` variations that fork contexts).

## Anti-patterns

- ❌ Mocking repositories in integration tests (use the real DB — that is the point)
- ❌ `@SpringBootTest` for logic testable with plain Mockito (context startup cost)
- ❌ Assertion-free tests or `assertThat(true).isTrue()`
- ❌ Tests that depend on the clock without an injectable `Clock`
- ❌ `Thread.sleep(...)` to wait for async work (use Awaitility)
- ❌ Testing private methods via reflection (test through the public API)
- ❌ Order-dependent tests sharing mutable static state
- ❌ Multiple unrelated behaviors asserted in the same test

## Tests for legacy code

For brownfield modules with few tests:

1. **Characterization tests**: capture the current behavior before touching it
2. **Smoke tests** on critical endpoints (HTTP 200 + response shape)
3. **Bug-by-bug tests**: one test per fixed bug that would have caught the bug
4. **Progressive coverage** on new modules first
