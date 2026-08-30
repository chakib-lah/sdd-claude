# Test strategy — PHP / Symfony

> **Layer 2 — Specific to the PHP/Symfony stack.**

---

## Tools

- **Test framework**: **PHPUnit is required** — the canonical test tool of this skill. The installed major is a project fact: read it from `composer.lock`, never pin it in this rule.
- **Symfony Test Pack**: `composer require --dev symfony/test-pack` (greenfield setup)
- **Doctrine fixtures**: `composer require --dev doctrine/doctrine-fixtures-bundle` (greenfield setup)
- **Coverage**: Xdebug or PCOV

If the project has no working PHPUnit setup at all, that is a **PROJECT_TOOLING_GAP** (see `12-quality-gates.md`): report it, keep the requirement, and close it in a dedicated tooling change — never as a side effect of an unrelated feature, and never by declaring tests optional.

## Test organization — discover the real layout first

Suite names and test directories are **project facts**. Before generating or moving any test:

1. Read the PHPUnit configuration — whichever variant the project uses (`phpunit.xml.dist`, `phpunit.xml` or `phpunit.dist.xml`) — and list the declared `<testsuite>` names and their directories.
2. Inspect the existing `tests/` tree and follow its conventions (base classes, namespaces, fixtures).
3. **Brownfield**: never reorganize or rename the existing test tree during an unrelated feature.

**Greenfield default** (only when no test tree exists yet):

```
tests/
├── Unit/                       ← Unit tests (mocks for deps)
│   ├── Service/
│   │   └── UserServiceTest.php
│   ├── Validator/
│   └── ValueObject/
├── Functional/                 ← HTTP endpoint tests
│   ├── Controller/
│   │   └── UserControllerTest.php
│   └── Api/
├── Integration/                ← Tests with a real DB (no HTTP)
│   ├── Repository/
│   │   └── UserRepositoryTest.php
│   └── EventSubscriber/
├── Fixtures/                   ← Doctrine fixtures
│   ├── UserFixtures.php
│   └── OrderFixtures.php
└── bootstrap.php
```

## Test categories

The three categories below are universal test **levels**, not directory names: projects name and group their suites differently (different casing, abbreviated names, merged or additional levels). Map each level to the project's discovered suites; the directories in the examples are the greenfield defaults.

### Unit tests

For: business services, validators, value objects, pure logic.

```php
final class UserServiceTest extends TestCase
{
    private UserRepository|MockObject $repository;
    private LoggerInterface|MockObject $logger;
    private UserService $sut;

    protected function setUp(): void
    {
        $this->repository = $this->createMock(UserRepository::class);
        $this->logger = $this->createMock(LoggerInterface::class);
        $this->sut = new UserService($this->repository, $this->logger);
    }

    public function testReturnsNullWhenUserNotFound(): void
    {
        // Arrange
        $this->repository->method('find')->willReturn(null);

        // Act
        $result = $this->sut->find(42);

        // Assert
        self::assertNull($result);
    }
}
```

### Integration tests

For: repositories with a real DB, event subscribers, services that depend on the container.

```php
final class UserRepositoryTest extends KernelTestCase
{
    private UserRepository $sut;
    private EntityManagerInterface $em;

    protected function setUp(): void
    {
        self::bootKernel();
        $container = self::getContainer();
        $this->em = $container->get(EntityManagerInterface::class);
        $this->sut = $container->get(UserRepository::class);

        // Reset the test DB
        $this->em->getConnection()->executeStatement('TRUNCATE TABLE user CASCADE');
    }

    public function testPersistsAndRetrievesUser(): void
    {
        $user = new User('test@example.com');
        $this->em->persist($user);
        $this->em->flush();

        $found = $this->sut->find($user->getId());
        self::assertSame('test@example.com', $found->getEmail());
    }
}
```

### Functional tests

For: controllers, HTTP endpoints, backend-side end-to-end integration.

```php
final class UserControllerTest extends WebTestCase
{
    public function testGetUserReturnsJson(): void
    {
        $client = static::createClient();
        $client->request('GET', '/api/users/1');

        self::assertResponseIsSuccessful();
        self::assertJson($client->getResponse()->getContent());
        self::assertSame('application/json', $client->getResponse()->headers->get('Content-Type'));
    }

    public function testCreateUserReturns201(): void
    {
        $client = static::createClient();
        $client->request('POST', '/api/users', [], [], 
            ['CONTENT_TYPE' => 'application/json'],
            json_encode(['email' => 'new@example.com', 'password' => 'secret123'])
        );

        self::assertResponseStatusCodeSame(201);
    }
}
```

## Naming conventions

### Files
- `<ClassName>Test.php` for each tested class
- Placed in the mirror sub-directory of the appropriate **discovered** suite: `src/Service/User/UserService.php` → `<unit-suite-dir>/Service/User/UserServiceTest.php` (greenfield default: `tests/Unit/Service/User/UserServiceTest.php`)

### Test methods
- `test<ActionExpectedResult>`: `testReturnsNullWhenUserNotFound`
- Readable format, no `should` and no underscores
- A single main assertion per test (or several assertions tied to the same behavior)

### Configuration

An existing project's PHPUnit configuration — whatever its filename and suite names — is authoritative: read it, don't rewrite it to match this rule. **Greenfield default** configuration:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit
    bootstrap="tests/bootstrap.php"
    colors="true"
    failOnWarning="true"
    failOnRisky="true">
    <php>
        <ini name="error_reporting" value="-1" />
        <server name="APP_ENV" value="test" force="true" />
        <server name="SHELL_VERBOSITY" value="-1" />
    </php>
    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
        <testsuite name="Integration">
            <directory>tests/Integration</directory>
        </testsuite>
        <testsuite name="Functional">
            <directory>tests/Functional</directory>
        </testsuite>
    </testsuites>
    <coverage>
        <include>
            <directory suffix=".php">src</directory>
        </include>
    </coverage>
</phpunit>
```

## Fixtures and data providers

### DataProvider for multiple cases

```php
/**
 * @dataProvider invalidEmailProvider
 */
public function testRejectsInvalidEmail(string $email, string $expectedError): void
{
    $this->expectException(InvalidEmailException::class);
    $this->expectExceptionMessage($expectedError);

    new Email($email);
}

public static function invalidEmailProvider(): \Generator
{
    yield 'empty' => ['', 'Cannot be empty'];
    yield 'no_at' => ['plaintext', 'Invalid format'];
    yield 'spaces' => ['  ', 'Cannot be empty'];
}
```

### Doctrine fixtures

```php
final class UserFixtures extends Fixture
{
    public function load(ObjectManager $manager): void
    {
        $admin = new User('admin@test.com');
        $admin->setRoles(['ROLE_ADMIN']);
        $manager->persist($admin);

        $regular = new User('user@test.com');
        $manager->persist($regular);

        $manager->flush();

        $this->addReference('user-admin', $admin);
        $this->addReference('user-regular', $regular);
    }
}
```

## Execution commands — discover the project wrapper

How tests run is a **project fact**. Discover the established execution wrapper before running anything — Makefile targets, Composer scripts, or a Docker/compose wrapper — and use the project's own entry points. Fall back to direct binaries only when the project actually runs them directly.

Direct-host examples (projects without a wrapper):

```bash
# All tests
vendor/bin/phpunit

# One suite — names come from the discovered PHPUnit configuration
vendor/bin/phpunit --testsuite=<suite-name>

# With coverage
vendor/bin/phpunit --coverage-html=coverage/

# Test DB preparation — use the project's own target/script when one exists
php bin/console doctrine:database:create --env=test --if-not-exists
php bin/console doctrine:schema:create --env=test
php bin/console doctrine:fixtures:load --env=test --no-interaction
```

**Greenfield** recommended Makefile targets (a project that already has its own targets keeps them — never edit a Layer-2 rule to record project targets):

```makefile
test:
	vendor/bin/phpunit

test-unit:
	vendor/bin/phpunit --testsuite=Unit

test-int:
	vendor/bin/phpunit --testsuite=Integration

test-func:
	vendor/bin/phpunit --testsuite=Functional

test-db-reset:
	php bin/console doctrine:database:drop --env=test --force --if-exists
	php bin/console doctrine:database:create --env=test
	php bin/console doctrine:schema:create --env=test
	php bin/console doctrine:fixtures:load --env=test --no-interaction
```

## Target coverage

| Code type | Target coverage |
|---|---|
| Business services | ≥ 90% |
| Validators / Value Objects | 100% |
| Repositories | ≥ 80% (via integration tests) |
| Controllers | ≥ 70% (via functional tests) |
| Legacy code | no threshold, but cover fixed bugs |

## Best practices

### Functional tests — no real authentication

For protected endpoints, use an authenticated client:

```php
private function loginAsUser(string $email): KernelBrowser
{
    $client = static::createClient();
    $userRepo = static::getContainer()->get(UserRepository::class);
    $user = $userRepo->findByEmail($email);
    $client->loginUser($user);
    return $client;
}
```

### Test isolation

Each test must be able to run independently and in any order. If a test depends on state created by another, it must be prepared in `setUp()` or via a fixture.

### Speed

- Unit tests: ≤ 100ms per test (with mocks)
- Integration tests: ≤ 500ms per test
- Functional tests: ≤ 1s per test

If a test is slower, that's a warning signal (often a poorly isolated test or one with too much setup).

## Anti-patterns

- ❌ Mocking the EntityManager in a unit test (use an integration test)
- ❌ Testing private properties via Reflection
- ❌ Tests that depend on the clock without an injectable `Clock`
- ❌ Fixtures not isolated between tests (use TRUNCATE or rollback)
- ❌ `assertTrue(true)` or empty tests
- ❌ Multiple unrelated `assert*` in the same test
- ❌ Tests in French mixed with tests in English (pick one and stick to it)

## Tests for legacy code

For brownfield modules with few tests:

1. **Characterization tests**: capture the current behavior
2. **Smoke tests** on critical workflows (HTTP 200 + response format)
3. **Bug-by-bug tests**: one test per fixed bug that would have caught the bug
4. **Progressive coverage** on new modules first
