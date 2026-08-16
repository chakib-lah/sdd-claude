# Test strategy — PHP / Symfony

> **Layer 2 — Specific to the PHP/Symfony stack.**

---

## Tools

- **Test framework**: PHPUnit 11.x or 12.x
- **Symfony Test Pack**: `composer require --dev symfony/test-pack`
- **Doctrine fixtures**: `composer require --dev doctrine/doctrine-fixtures-bundle`
- **Coverage**: Xdebug or PCOV

## Test organization

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

### Unit tests (`tests/Unit/`)

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

### Integration tests (`tests/Integration/`)

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

### Functional tests (`tests/Functional/`)

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
- Placed in the mirror sub-directory: `src/Service/User/UserService.php` → `tests/Unit/Service/User/UserServiceTest.php`

### Test methods
- `test<ActionExpectedResult>`: `testReturnsNullWhenUserNotFound`
- Readable format, no `should` and no underscores
- A single main assertion per test (or several assertions tied to the same behavior)

### Configuration

Recommended `phpunit.dist.xml`:

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

## Execution commands

To adapt to the project's Makefile:

```bash
# All tests
vendor/bin/phpunit

# By category
vendor/bin/phpunit --testsuite=Unit
vendor/bin/phpunit --testsuite=Integration
vendor/bin/phpunit --testsuite=Functional

# With coverage
vendor/bin/phpunit --coverage-html=coverage/

# Test DB preparation (to adapt)
php bin/console doctrine:database:create --env=test --if-not-exists
php bin/console doctrine:schema:create --env=test
php bin/console doctrine:fixtures:load --env=test --no-interaction
```

Recommended Makefile targets (to be added to `.claude/rules/12-quality-gates.md` too):

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
