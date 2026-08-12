# SDD Skills — Selection guide

> Pick the right skill for the project's stack.

---

## Decision tree

```
package.json has @angular/core ?
├── YES:
│   └── composer.json has symfony/framework-bundle ?
│       ├── YES  → sdd-symfony-angular
│       └── NO:
│           └── package.json has express / fastify / @nestjs/core ?
│               ├── YES  → sdd-angular-node
│               └── NO   → core only (Angular frontend only)
└── NO:
    └── composer.json has symfony/framework-bundle ?
        ├── YES  → sdd-php-symfony
        └── NO:
            └── Any .php files present ?
                ├── YES  → sdd-php-backend
                └── NO   → no applicable SDD skill
```

---

## Skills table

| Skill | Stack | Typical projects | Auxiliary commands |
|---|---|---|---|
| `sdd-php-backend` | Pure PHP (no framework) | Internal scripts, legacy | `/php-class`, `/php-test`, `/extract-class` |
| `sdd-php-symfony` | PHP + Symfony + Doctrine | Back-office, business APIs | `/symfony-entity`, `/symfony-service`, `/symfony-controller`, `/symfony-test` |
| `sdd-symfony-angular` | Symfony + Angular | Full-stack application | 4 symfony-* + `/angular-component`, `/angular-service`, `/angular-test`, `/api-contract` |
| `sdd-angular-node` | Angular + Node.js | Full-stack application (Node) | `/angular-component`, `/angular-service`, `/angular-test`, `/node-endpoint`, `/node-service`, `/node-test`, `/api-design`, `/contract-check` |

---

## Auxiliary commands per skill

All **universal** commands (sdd-*, retro-spec) are present in every skill.

The **auxiliary** scaffolding commands are specific to each skill:

### sdd-php-backend
- `/php-class` — generates a PHP class from the spec
- `/php-test` — generates PHPUnit tests from the spec
- `/extract-class` *(brownfield)* — extracts a class from procedural code

### sdd-php-symfony
- `/symfony-entity` — generates Doctrine entity + migration
- `/symfony-service` — generates service + interface
- `/symfony-controller` — generates single-action controller
- `/symfony-test` — generates PHPUnit tests (unit + functional)

### sdd-symfony-angular
- Everything from sdd-php-symfony +
- `/angular-component` — generates standalone component
- `/angular-service` — generates typed Angular service
- `/angular-test` — generates Angular tests
- `/api-contract` — OpenAPI sync Symfony ↔ Angular

### sdd-angular-node
- `/angular-component` — generates standalone component
- `/angular-service` — generates typed Angular service
- `/angular-test` — generates Angular tests
- `/node-endpoint` — generates controller + route + Supertest tests
- `/node-service` — generates Node.js service + unit tests
- `/node-test` — generates tests from the AC
- `/api-design` — generates/updates the OpenAPI spec
- `/contract-check` — checks Angular/backend sync

---

## Structure of a skill

```
sdd-<stack>/
├── SKILL.md              ← Frontmatter (name, description) + installation process
└── reference/
    ├── commands/         ← All commands (universal + auxiliary)
    ├── rules/            ← All rules (core + stack-specific)
    └── templates/        ← Templates (spec, plan, tasks, notes, sdd-readme + exports AMOA jira-story, spec-doc)
```

Files in `reference/` are copied into the project's `.claude/` during installation.
