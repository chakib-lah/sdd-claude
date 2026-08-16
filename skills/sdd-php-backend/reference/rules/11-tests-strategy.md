# Test strategy — PHP

> **Layer 2 — Specific to the PHP stack (no framework).**

---

## Tools

- **Test framework**: PHPUnit 11.x or 12.x (10.x acceptable on legacy PHP 8.1)
- **Coverage**: Xdebug or PCOV
- **Custom assertions**: `assertCallable`, `assertJsonStructure`, etc. as needed

If PHPUnit is not installed:

```bash
composer require --dev phpunit/phpunit
```

## PHPUnit configuration

Recommended `phpunit.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit
    bootstrap="vendor/autoload.php"
    colors="true"
    failOnWarning="true"
    failOnRisky="true">
    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
        <testsuite name="Integration">
            <directory>tests/Integration</directory>
        </testsuite>
    </testsuites>
    <coverage>
        <include>
            <directory suffix=".php">src</directory>
        </include>
    </coverage>
</phpunit>
```

## Test organization

```
tests/
├── Unit/                       ← Unit tests (mocks for deps)
│   ├── Service/
│   │   └── UserServiceTest.php
│   ├── Validator/
│   └── ValueObject/
├── Integration/                ← Tests with real dependencies (DB, FS)
│   ├── Repository/
│   │   └── UserRepositoryTest.php
│   └── Service/
└── fixtures/                   ← Shared test data
    └── users.json
```

## Naming conventions

### Test files

- `MyClassTest.php` for the class `MyClass`
- Placed in `tests/Unit/` or `tests/Integration/` depending on the type

### Test methods

```php
public function testReturnsNullWhenUserNotFound(): void
public function testCreatesUserWithHashedPassword(): void
public function testThrowsExceptionOnDuplicateEmail(): void
```

Format: `test<ActionExpectedResult>`, action and result readable, no `should` and no underscores.

### Alternative: DataProvider for parameterized tests

```php
/**
 * @dataProvider invalidEmailProvider
 */
public function testRejectsInvalidEmail(string $email, string $expectedError): void
{
    // ...
}

public static function invalidEmailProvider(): array
{
    return [
        'missing @' => ['plaintext', 'Invalid format'],
        'empty' => ['', 'Cannot be empty'],
        'spaces' => ['  ', 'Cannot be empty'],
    ];
}
```

## Test types and when to use them

### Unit tests (`tests/Unit/`)

**What**: test a class in isolation, with mocks for all its dependencies.

**When**:
- Business services
- Validators
- Value Objects
- Pure computation / transformation logic

**How**:

```php
final class UserServiceTest extends TestCase
{
    private UserRepository|MockObject $repository;
    private EmailService|MockObject $emailService;
    private UserService $sut;

    protected function setUp(): void
    {
        $this->repository = $this->createMock(UserRepository::class);
        $this->emailService = $this->createMock(EmailService::class);
        $this->sut = new UserService($this->repository, $this->emailService);
    }

    public function testCreatesUserWithHashedPassword(): void
    {
        $this->repository
            ->expects(self::once())
            ->method('save')
            ->with(self::callback(fn(User $u) => password_verify('secret', $u->password)));

        $this->sut->createUser('test@example.com', 'secret');
    }
}
```

### Integration tests (`tests/Integration/`)

**What**: test integration with real dependencies (DB, filesystem, external API partially mocked).

**When**:
- Repositories (with a real test DB)
- File reads/writes
- HTTP calls (with a mock server or stub)

**Recommended setup**:
- Database dedicated to tests (`test_db`)
- Reset between each test or per file (`setUp` / `tearDown`)
- Versioned fixtures (`tests/fixtures/`)

### Smoke tests (optional, legacy projects)

For brownfield projects with few tests, start with smoke tests:
- Check that the main pages load (status 200)
- Check that critical workflows complete
- Low coverage, but a fast early-warning trigger

## Execution commands

To adapt to the project (Makefile, Composer scripts, etc.):

```bash
# All tests
vendor/bin/phpunit

# Unit tests only
vendor/bin/phpunit --testsuite=Unit

# Integration tests only
vendor/bin/phpunit --testsuite=Integration

# Coverage
vendor/bin/phpunit --coverage-html=coverage/

# A specific file
vendor/bin/phpunit tests/Unit/Service/UserServiceTest.php

# A specific test
vendor/bin/phpunit --filter testCreatesUserWithHashedPassword
```

If a `Makefile` is present in the project, prefer:

```bash
make test           # all tests
make test-unit      # unit
make test-int       # integration
make coverage       # with coverage
```

## Target coverage

| Code type | Target coverage |
|---|---|
| Critical business services | ≥ 90% |
| Validators / Value Objects | 100% |
| Repositories | ≥ 70% (integration) |
| Controllers / Routing | ≥ 50% (smoke ok) |
| Legacy code | no threshold (but cover fixed bugs) |

## Best practices

### One test = one behavior

- No 5 unrelated assertions in the same test
- A test name clearly describes the tested scenario

### Arrange / Act / Assert (AAA)

```php
public function testReturnsNullWhenUserNotFound(): void
{
    // Arrange
    $this->repository->method('find')->willReturn(null);

    // Act
    $result = $this->sut->findById(42);

    // Assert
    self::assertNull($result);
}
```

### No business logic in tests

- If a test contains `if` statements, it needs to be split into several tests
- Fixtures must be trivial to read

### Independent tests

- No required execution order
- `setUp` / `tearDown` for shared state

## Anti-patterns

- ❌ Testing the implementation instead of the behavior (`assertObjectHasProperty('_internalCache')`)
- ❌ Mocking the class under test
- ❌ Tests that depend on the system clock without an injectable `Clock`
- ❌ Tests that depend on an external environment (real network, shared DB)
- ❌ `assertTrue(true)` or empty tests (detect them with `failOnRisky`)

## Tests for legacy code

For brownfield projects with few or no tests:

1. **Start with smoke tests** on critical workflows
2. **Characterization tests**: capture the current behavior before any refactor
3. **Tests on bug fixes**: 1 test per fixed bug, one that would have caught the bug
4. **Progressive coverage**: aim for 50% on new modules, accept the legacy as-is
