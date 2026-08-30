---
description: Scaffold a Symfony controller with route, request DTO, and response from a SDD spec
---

# /symfony-controller

**Auxiliary scaffolding command**: create a single-action (invokable) Symfony controller with its route, request DTO and response DTO.

## Blocking prerequisites

- Active SDD feature with `tasks.md` `status: approved`
- Current task mentions the creation of the endpoint
- Conventions available: `.claude/rules/10-code-conventions.md`
- The business service being used exists (otherwise create it first via `/symfony-service`)

## Steps

### 1. Identify the controller to create

Ask for:
- Business action (PascalCase): `GetUser`, `CreateOrder`, `UpdateCertificate`
- HTTP method: GET / POST / PUT / PATCH / DELETE
- Route: `/api/users/{id}`, `/api/orders`, etc.
- Authentication required: yes / no / specific role

### 2. Load the SDD context

Read `spec.md` (Design section → Endpoint(s)) to retrieve:
- Request payload format
- Response format
- Expected HTTP status codes (200, 201, 422, 404, etc.)
- Error cases to handle
- Serialization groups to use

### 3. Load the conventions

Read `.claude/rules/10-code-conventions.md` to comply with:
- Single Action Controllers (`__invoke()`)
- PHP 8+ attribute-based routing
- Thin controllers (no business logic)
- Typed DTOs (`readonly`)
- Uniform error format

Then **discover the project's actual layout**: inspect existing controllers and DTOs (and `.claude/rules/project-architecture.md` if present) for directories, namespaces and route conventions, and follow them. The `src/Controller/` and `App\DTO\...` paths below are the greenfield defaults.

### 4. Check for duplicates

```bash
# In the discovered controller directory (greenfield default shown)
test -f src/Controller/<Action>Controller.php && echo "EXISTS" || echo "OK"
```

### 5. Generate the request DTO (if applicable)

For POST/PUT/PATCH methods with a payload:

```php
<?php

declare(strict_types=1);

namespace App\DTO\Request;

use Symfony\Component\Validator\Constraints as Assert;

final readonly class Create<Entity>Request
{
    public function __construct(
        #[Assert\NotBlank]
        #[Assert\Email]
        public string $email,

        #[Assert\NotBlank]
        #[Assert\Length(min: 8)]
        public string $password,
    ) {
    }
}
```

### 6. Generate the response DTO (if applicable)

```php
<?php

declare(strict_types=1);

namespace App\DTO\Response;

use App\Entity\<Entity>;

final readonly class <Entity>Response
{
    public function __construct(
        public int $id,
        public string $email,
        public string $createdAt,
    ) {
    }

    public static function from<Entity>(<Entity> $<entity>): self
    {
        return new self(
            id: $<entity>->getId(),
            email: $<entity>->getEmail(),
            createdAt: $<entity>->getCreatedAt()->format(\DateTimeInterface::ATOM),
        );
    }
}
```

### 7. Generate the controller

Typical skeleton for a GET:

```php
<?php

declare(strict_types=1);

namespace App\Controller;

use App\DTO\Response\<Entity>Response;
use App\Service\<Domain>\<Entity>Service;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/<entities>/{id}', methods: ['GET'], name: '<entity>_get')]
final class Get<Entity>Controller
{
    public function __construct(
        private readonly <Entity>Service $service,
    ) {
    }

    public function __invoke(int $id): JsonResponse
    {
        $<entity> = $this->service->find($id);
        if ($<entity> === null) {
            throw new NotFoundHttpException("<Entity> #{$id} not found");
        }

        return new JsonResponse(
            <Entity>Response::from<Entity>($<entity>),
            Response::HTTP_OK
        );
    }
}
```

Typical skeleton for a POST:

```php
<?php

declare(strict_types=1);

namespace App\Controller;

use App\DTO\Request\Create<Entity>Request;
use App\DTO\Response\<Entity>Response;
use App\Service\<Domain>\<Entity>Service;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Attribute\MapRequestPayload;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/<entities>', methods: ['POST'], name: '<entity>_create')]
final class Create<Entity>Controller
{
    public function __construct(
        private readonly <Entity>Service $service,
    ) {
    }

    public function __invoke(
        #[MapRequestPayload] Create<Entity>Request $request,
    ): JsonResponse {
        $<entity> = $this->service->create($request);

        return new JsonResponse(
            <Entity>Response::from<Entity>($<entity>),
            Response::HTTP_CREATED
        );
    }
}
```

### 8. Security (if applicable)

If the endpoint requires authentication or authorization:

```php
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/api/users/{id}', methods: ['GET'])]
#[IsGranted('ROLE_USER')]
final class GetUserController
{
    // ...
}
```

For finer-grained authorization checks (on a resource), use a Symfony Voter.

### 9. Display and validate

Before writing, display in the chat:
- Request DTO
- Response DTO
- Controller
- Configured route
- Enabled security

Ask for confirmation.

### 10. Write the files

Paths follow the discovered convention (greenfield defaults shown):

- `src/Controller/<Action>Controller.php`
- `src/DTO/Request/<Entity>Request.php` (if POST/PUT/PATCH)
- `src/DTO/Response/<Entity>Response.php`

### 11. Verify the routing

```bash
# Via the project wrapper if one exists
php bin/console debug:router | grep <entity>
```

Confirm that the route is properly registered and reachable.

### 12. Announce

```
✅ Controller created: src/Controller/<Action>Controller.php
✅ Request DTO: src/DTO/Request/Create<Entity>Request.php
✅ Response DTO: src/DTO/Response/<Entity>Response.php

Route registered:
  <METHOD> <route> → <name>

Next steps:
- /symfony-test to scaffold the functional tests
- /sdd-implement to finalize the logic
```

## Stop rules

- **Single Action Controller**: one controller = one endpoint
- **No business logic** in the controller: delegate to the service
- **No Doctrine query** in the controller: go through the repository via the service
- **Always type** route and payload parameters
- **Always use a DTO** for the JSON response (no anonymous raw array)
- **Always specify explicit HTTP status codes** (`Response::HTTP_CREATED`, etc.)
- **Always think about security**: if the route is protected, add `#[IsGranted]`
