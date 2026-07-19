---
description: Scaffold a PHPUnit test from a SDD spec, following project conventions
---

# /php-test

**Auxiliary scaffolding command**: create a PHPUnit test for an existing class, based on the acceptance criteria in `spec.md`.

## Blocking prerequisites

- An active SDD feature
- The class to test must already exist (otherwise use `/php-class` first)
- Test conventions available in `.claude/rules/30-tests-strategy.md`

## Steps

### 1. Identify the class to test

Ask:
- Path to the class to test (e.g. `src/Service/User/UserService.php`)
- Test type: `Unit` or `Integration`

### 2. Load the test conventions

Read `.claude/rules/30-tests-strategy.md` to comply with:
- Directory structure (`tests/Unit/`, `tests/Integration/`)
- File naming (`<ClassName>Test.php`)
- AAA pattern (Arrange / Act / Assert)
- Test method naming conventions

### 3. Load the SDD context

Read `spec.md` to retrieve the acceptance criteria, each of which will become a test:

```
AC-1: When the email is invalid, the system throws EmailInvalidException
       → test: testThrowsExceptionOnInvalidEmail
       
AC-2: When the user does not exist, find() returns null
       → test: testReturnsNullWhenUserNotFound
```

### 4. Read the class to test

Identify:
- The namespace and class name
- The constructor-injected dependencies (to mock for unit tests)
- The public methods (each must have at least one test)

### 5. Generate the test skeleton

#### Unit test (with mocks)

```php
<?php

declare(strict_types=1);

namespace App\Tests\Unit\Service\User;

use App\Entity\User;
use App\Repository\UserRepository;
use App\Service\User\UserService;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;

final class UserServiceTest extends TestCase
{
    private UserRepository|MockObject $repository;
    private UserService $sut;

    protected function setUp(): void
    {
        $this->repository = $this->createMock(UserRepository::class);
        $this->sut = new UserService($this->repository);
    }

    public function testReturnsNullWhenUserNotFound(): void
    {
        // Arrange
        $this->repository
            ->method('find')
            ->with(42)
            ->willReturn(null);

        // Act
        $result = $this->sut->findById(42);

        // Assert
        self::assertNull($result);
    }

    public function testReturnsUserWhenFound(): void
    {
        // Arrange
        $expectedUser = new User(/* ... */);
        $this->repository
            ->method('find')
            ->with(42)
            ->willReturn($expectedUser);

        // Act
        $result = $this->sut->findById(42);

        // Assert
        self::assertSame($expectedUser, $result);
    }

    // ... one test per acceptance criterion
}
```

#### Integration test (no mocks for the real dependencies)

```php
<?php

declare(strict_types=1);

namespace App\Tests\Integration\Repository;

use App\Repository\UserRepository;
use PHPUnit\Framework\TestCase;

final class UserRepositoryTest extends TestCase
{
    private \PDO $db;
    private UserRepository $sut;

    protected function setUp(): void
    {
        // Connection to a dedicated test database
        $this->db = new \PDO('mysql:host=localhost;dbname=test_db', 'test', 'test');
        $this->sut = new UserRepository($this->db);
        
        // Reset the table
        $this->db->exec('TRUNCATE TABLE user');
    }

    public function testInsertsAndRetrievesUser(): void
    {
        // Arrange
        $this->db->exec("INSERT INTO user (email) VALUES ('test@example.com')");
        $userId = (int) $this->db->lastInsertId();

        // Act
        $result = $this->sut->find($userId);

        // Assert
        self::assertNotNull($result);
        self::assertSame('test@example.com', $result->email);
    }
}
```

### 6. Generate one test per acceptance criterion

Read the AC from `spec.md` and generate for each:
- A test named following the `test<ActionExpectedResult>` pattern
- A comment indicating the covered AC
- An AAA skeleton with a TODO if the implementation is not obvious

Example:

```php
/**
 * Covers: AC-3 (When the email already exists, throws UserAlreadyExistsException)
 */
public function testThrowsExceptionOnDuplicateEmail(): void
{
    // TODO: implement
    self::markTestIncomplete('To implement');
}
```

### 7. Display and validate

Before writing, display the content and ask for confirmation.

### 8. Write the file

Create the file at the appropriate path:
- `tests/Unit/Service/User/UserServiceTest.php`
- `tests/Integration/Repository/UserRepositoryTest.php`

### 9. Verify that the tests run

```bash
vendor/bin/phpunit tests/Unit/Service/User/UserServiceTest.php
```

The tests must at minimum be detected by PHPUnit, even if they are `markTestIncomplete`.

### 10. Announce

```
✅ Tests scaffolded: tests/Unit/Service/User/UserServiceTest.php

Tests generated: N
  - N complete tests
  - N incomplete tests (TODO to complete via /sdd-implement)

Next step:
- Implement the tests via /sdd-implement (they are linked to the [Tests] task in tasks.md)
```

## Stop rules

- **Do not generate bogus tests** like `assertTrue(true)`: use `markTestIncomplete()` if not immediately implementable
- **At least one test per acceptance criterion**
- **No mocking of the class under test**: only the dependencies are mocked
- **No business logic in the test**: if you need an `if`, split into several tests
- **No required execution order between tests**: each test is independent
