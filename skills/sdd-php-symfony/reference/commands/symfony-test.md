---
description: Scaffold PHPUnit tests (unit, integration, functional) from a SDD spec for Symfony
---

# /symfony-test

**Auxiliary scaffolding command**: create the PHPUnit tests for an existing Symfony class (Service, Repository, Controller).

## Blocking prerequisites

- Active SDD feature with `tasks.md` `status: approved`
- The class under test must already exist
- Conventions available: `.claude/rules/11-tests-strategy.md`

## Steps

### 1. Identify the class to test

Ask for:
- Path to the class under test (e.g. `src/Service/User/UserService.php`)
- Test level: unit, integration or functional — then map it to the project's **discovered** suite (see step 2)

Automatic level suggestion based on the class:
- Business service → unit (mocks for repositories)
- Repository → integration (real test database)
- Controller → functional (WebTestCase, HTTP requests)
- Validator / Value Object → unit
- EventSubscriber → integration (KernelTestCase)

### 2. Load the conventions

Read `.claude/rules/11-tests-strategy.md` to comply with:
- The test-level model (unit / integration / functional) and its universal practices
- File naming (`<ClassName>Test.php`)
- AAA pattern (Arrange / Act / Assert)
- Method naming conventions

Then **discover the project's actual test layout**: read the PHPUnit configuration (`phpunit.xml.dist`, `phpunit.xml` or `phpunit.dist.xml`) for suite names and directories, and inspect existing tests for base classes and namespaces. Generate into the **existing** suites — the `tests/Unit|Integration|Functional` paths and `App\Tests\...` namespaces in the skeletons below are the greenfield defaults. If a level has no matching suite, use the closest existing level; if the test infrastructure is missing entirely, report **PROJECT_TOOLING_GAP** (see `12-quality-gates.md`) instead of inventing a layout.

### 3. Load the SDD context

Read `spec.md` to retrieve the **acceptance criteria**. Each AC becomes at least one test.

### 4. Read the class under test

Identify:
- Namespace and name
- Injected dependencies (constructor) → to mock in Unit tests
- Public methods → each must have at least one test
- Error cases (thrown exceptions) → dedicated tests

### 5. Generate the skeleton according to the type

#### Type: Unit (with mocks)

```php
<?php

declare(strict_types=1);

namespace App\Tests\Unit\Service\<Domain>;

use App\Entity\<Entity>;
use App\Repository\<Entity>Repository;
use App\Service\<Domain>\<Name>Service;
use App\Exception\<Entity>NotFoundException;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use Psr\Log\LoggerInterface;

final class <Name>ServiceTest extends TestCase
{
    private <Entity>Repository|MockObject $repository;
    private LoggerInterface|MockObject $logger;
    private <Name>Service $sut;

    protected function setUp(): void
    {
        $this->repository = $this->createMock(<Entity>Repository::class);
        $this->logger = $this->createMock(LoggerInterface::class);
        $this->sut = new <Name>Service($this->repository, $this->logger);
    }

    /**
     * Covers AC-1: <AC statement>
     */
    public function testReturnsNullWhenEntityNotFound(): void
    {
        // Arrange
        $this->repository
            ->method('find')
            ->with(42)
            ->willReturn(null);

        // Act
        $result = $this->sut->find(42);

        // Assert
        self::assertNull($result);
    }

    /**
     * Covers AC-2: <AC statement>
     */
    public function testThrowsExceptionOnDuplicate(): void
    {
        self::markTestIncomplete('To implement via /sdd-implement');
    }

    // One test per additional AC
}
```

#### Type: Integration (KernelTestCase)

```php
<?php

declare(strict_types=1);

namespace App\Tests\Integration\Repository;

use App\Entity\<Entity>;
use App\Repository\<Entity>Repository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

final class <Entity>RepositoryTest extends KernelTestCase
{
    private EntityManagerInterface $em;
    private <Entity>Repository $sut;

    protected function setUp(): void
    {
        self::bootKernel();
        $container = self::getContainer();
        $this->em = $container->get(EntityManagerInterface::class);
        $this->sut = $container->get(<Entity>Repository::class);

        // Reset test table
        $this->em->getConnection()->executeStatement('TRUNCATE TABLE <table> CASCADE');
    }

    /**
     * Covers AC-1: <statement>
     */
    public function testPersistsAndRetrieves<Entity>(): void
    {
        // Arrange
        $entity = new <Entity>(/* params */);
        $this->em->persist($entity);
        $this->em->flush();
        $this->em->clear();

        // Act
        $found = $this->sut->find($entity->getId());

        // Assert
        self::assertNotNull($found);
        self::assertSame($entity->getId(), $found->getId());
    }

    public function testFindByEmailReturnsNullWhenNotFound(): void
    {
        $result = $this->sut->findByEmail('nonexistent@example.com');
        self::assertNull($result);
    }
}
```

#### Type: Functional (WebTestCase)

```php
<?php

declare(strict_types=1);

namespace App\Tests\Functional\Controller;

use App\Entity\<Entity>;
use App\Repository\<Entity>Repository;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

final class <Action>ControllerTest extends WebTestCase
{
    private KernelBrowser $client;

    protected function setUp(): void
    {
        $this->client = static::createClient();
    }

    /**
     * Covers AC-1: <statement>
     */
    public function testGetReturns200WhenEntityExists(): void
    {
        // Arrange
        $repo = static::getContainer()->get(<Entity>Repository::class);
        $entity = $repo->find(1);
        self::assertNotNull($entity, 'Fixtures not loaded');

        // Act
        $this->client->request('GET', '/api/<entities>/' . $entity->getId());

        // Assert
        self::assertResponseIsSuccessful();
        self::assertJson($this->client->getResponse()->getContent());
    }

    public function testGetReturns404WhenEntityDoesNotExist(): void
    {
        $this->client->request('GET', '/api/<entities>/999999');
        self::assertResponseStatusCodeSame(404);
    }

    public function testPostReturns201OnValidPayload(): void
    {
        $this->client->request(
            'POST',
            '/api/<entities>',
            [],
            [],
            ['CONTENT_TYPE' => 'application/json'],
            json_encode(['email' => 'new@example.com', 'password' => 'secret123'])
        );

        self::assertResponseStatusCodeSame(201);
    }

    public function testPostReturns422OnInvalidPayload(): void
    {
        $this->client->request(
            'POST',
            '/api/<entities>',
            [],
            [],
            ['CONTENT_TYPE' => 'application/json'],
            json_encode(['email' => 'invalid'])
        );

        self::assertResponseStatusCodeSame(422);
    }
}
```

### 6. Generate one test per AC

For each AC in `spec.md`, create a test method. If the implementation is not obvious, use `markTestIncomplete()`:

```php
/**
 * Covers AC-X: <exact AC statement>
 */
public function test<Description>(): void
{
    self::markTestIncomplete('To implement via /sdd-implement');
}
```

### 7. DataProvider for multiple cases

If several similar ACs exist (validation for example), propose a DataProvider:

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
    yield 'spaces_only' => ['  ', 'Cannot be empty'];
}
```

### 8. Display and validate

Before writing:
- Display the list of generated tests (with AC ↔ test mapping)
- Ask for confirmation

### 9. Write the file

Path according to the level, inside the **discovered** suite directory (greenfield defaults shown):
- `tests/Unit/Service/<Domain>/<Name>ServiceTest.php`
- `tests/Integration/Repository/<Entity>RepositoryTest.php`
- `tests/Functional/Controller/<Action>ControllerTest.php`

### 10. Verify that the tests are detected

```bash
# Via the project's test wrapper if one exists; direct-host example:
vendor/bin/phpunit <suite-dir>/<path>/<File>Test.php --list-tests
```

### 11. Announce

```
✅ Tests scaffolded: <suite-dir>/<path>/<File>Test.php

Tests generated: N
  - N ACs covered
  - X complete tests
  - Y incomplete tests (to finalize via /sdd-implement)

Next step:
- Implement the tests via /sdd-implement
- Run regularly, via the project's test wrapper (or vendor/bin/phpunit directly)
```

## Stop rules

- **At least one test per acceptance criteria**
- **No `assertTrue(true)` or empty tests**: use `markTestIncomplete()`
- **No mocking of the class under test**: only dependencies are mocked
- **No business logic in the tests**: if you write an `if`, split into several tests
- **No required execution order** between tests
- **For integration and functional tests**: clean reset in `setUp()` (TRUNCATE or rollback)
- **No tests that depend on the clock** without an injectable `Clock`
- **Document each test with the AC it covers** (`Covers AC-N` comment)
