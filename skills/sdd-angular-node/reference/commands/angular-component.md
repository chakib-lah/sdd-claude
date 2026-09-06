---
description: Scaffold an Angular standalone component from a SDD spec
---

# /angular-component

**Auxiliary scaffolding command**: create a standalone Angular component with template, styles, and test file.

## Blocking prerequisites

- Active SDD feature with `tasks.md` `status: approved`
- Current task mentioning the creation of this component
- Available conventions: `.claude/rules/40-angular-conventions.md`

## Steps

### 1. Identify the component to create

Ask for:
- Component name (PascalCase, `Component` suffix): `UserCard`, `OrderList`, `CertificateForm`
- Feature (folder): `user`, `order`, `certificate`
- Type: `pages` (routed component) or `components` (presentation)
- Identified inputs and outputs (signal-based)
- Uses Signals or RxJS?

### 2. Load the SDD context

Read `plan.md` (Technical design → frontend components) — plus `spec.md` for the behavioral requirements and ACs — to retrieve:
- Role of the component
- Data displayed
- User actions (clicks, forms)
- Visual states (loading, empty, error)

### 3. Load the conventions

Read `.claude/rules/40-angular-conventions.md`:
- Standalone new components (where the installed Angular version supports it)
- `ChangeDetectionStrategy.OnPush`
- Signals preferred over local RxJS
- Selector prefix discovered from `angular.json`

Then **discover the project's frontend state**: the frontend root (where `angular.json` lives — never assume `frontend/`), the selector prefix (`angular.json` → `prefix`), the existing feature organization, the current component architecture (standalone vs NgModules) and the configured test runner. The paths, `app-` selectors and layouts below are **greenfield defaults** — follow the discovered conventions. Never migrate neighboring NgModules or rewrite existing modules as part of this command; if the surrounding architecture prevents a safe standalone component, report the concrete blocker.

### 4. Check for duplicates

```bash
# The check consumes the DISCOVERED frontend root (feature organization: greenfield layout shown)
test -d <frontend-root>/src/app/features/<feature>/<type>/<name>/ && echo "EXISTS" || echo "OK"
```

### 5. Choose the destination path

Inside the discovered frontend root and existing feature organization. Greenfield example:

```
<frontend-root>/src/app/features/<feature>/<type>/<name>/
├── <name>.component.ts
├── <name>.component.html
├── <name>.component.scss
└── <name>.component.spec.ts
```

Examples (greenfield layout):
- Routed page: `<frontend-root>/src/app/features/user/pages/user-list/`
- Presentation component: `<frontend-root>/src/app/features/user/components/user-card/`

### 6. Generate the TypeScript component

```typescript
import { ChangeDetectionStrategy, Component, input, output } from '@angular/core';
import { CommonModule } from '@angular/common';

import { UserResponse } from '../../models/user.model';

@Component({
  selector: 'app-user-card',
  standalone: true,
  imports: [CommonModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './user-card.component.html',
  styleUrl: './user-card.component.scss',
})
export class UserCardComponent {
  // Signal-based inputs (Angular 17.1+)
  readonly user = input.required<UserResponse>();
  readonly highlighted = input(false);

  // Signal-based outputs
  readonly edit = output<number>();
  readonly delete = output<number>();

  protected onEditClick(): void {
    this.edit.emit(this.user().id);
  }

  protected onDeleteClick(): void {
    this.delete.emit(this.user().id);
  }
}
```

For a routed component (page), typically add:
- API service injection
- State signals (loading, data, error)
- `effect()` or a subscription to routing if needed

```typescript
import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { DestroyRef } from '@angular/core';

import { UserApiService } from '../../services/user-api.service';
import { UserResponse } from '../../models/user.model';

@Component({
  selector: 'app-user-list',
  standalone: true,
  imports: [CommonModule, RouterLink],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './user-list.component.html',
  styleUrl: './user-list.component.scss',
})
export class UserListComponent implements OnInit {
  private readonly userApi = inject(UserApiService);
  private readonly destroyRef = inject(DestroyRef);

  protected readonly users = signal<UserResponse[]>([]);
  protected readonly loading = signal(false);
  protected readonly error = signal<string | null>(null);

  ngOnInit(): void {
    this.loadUsers();
  }

  private loadUsers(): void {
    this.loading.set(true);
    this.userApi.list()
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: users => {
          this.users.set(users);
          this.loading.set(false);
        },
        error: err => {
          this.error.set('Error while loading');
          this.loading.set(false);
        },
      });
  }
}
```

### 7. Generate the HTML template

```html
<div class="user-card" [class.user-card--highlighted]="highlighted()">
  <h3 class="user-card__title">{{ user().email }}</h3>
  <p class="user-card__meta">Created on {{ user().createdAt | date:'short' }}</p>

  <div class="user-card__actions">
    <button type="button" data-test="edit-button" (click)="onEditClick()">
      Edit
    </button>
    <button type="button" data-test="delete-button" (click)="onDeleteClick()">
      Delete
    </button>
  </div>
</div>
```

For a template with states (loading/error/empty/success):

```html
@if (loading()) {
  <p>Loading…</p>
} @else if (error()) {
  <p class="error">{{ error() }}</p>
} @else if (users().length === 0) {
  <p>No users</p>
} @else {
  <ul>
    @for (user of users(); track user.id) {
      <li>
        <app-user-card [user]="user" />
      </li>
    }
  </ul>
}
```

Use the new control flow syntax (`@if`, `@for`, `@switch`) — Angular 17+.

### 8. Generate the SCSS (empty or with BEM structure)

```scss
.user-card {
  display: flex;
  flex-direction: column;
  padding: 1rem;
  border: 1px solid var(--border-color, #ddd);
  border-radius: 0.5rem;

  &--highlighted {
    border-color: var(--accent-color, #0066cc);
  }

  &__title {
    margin: 0 0 0.5rem;
    font-size: 1.125rem;
  }

  &__meta {
    color: var(--muted-color, #666);
    font-size: 0.875rem;
  }

  &__actions {
    display: flex;
    gap: 0.5rem;
    margin-top: 1rem;
  }
}
```

### 9. Generate the test skeleton

Runner-agnostic TestBed skeleton — it must run on the project's **configured** runner (Vitest, Jasmine or Jest); never use runner-specific APIs here. If the project is still on Karma/Jasmine, the generated spec runs there as-is while the migration gap is reported separately.

```typescript
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { UserCardComponent } from './user-card.component';

describe('UserCardComponent', () => {
  let component: UserCardComponent;
  let fixture: ComponentFixture<UserCardComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [UserCardComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(UserCardComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    fixture.componentRef.setInput('user', { id: 1, email: 'test@example.com', createdAt: '2026-01-01' });
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  // Tests scaffolded via /angular-test — to be completed
});
```

### 10. Display and validate

Before writing the files, display in the chat:
- The `.ts`
- The `.html`
- The `.scss`
- The `.spec.ts`

Ask for confirmation.

### 11. Write the files

All files in the chosen folder.

### 12. Add the route if it is a page

If the component is in `pages/`, update `<feature>.routes.ts`:

```typescript
// <frontend-root>/src/app/features/user/user.routes.ts (greenfield layout)
import { Routes } from '@angular/router';

export const userRoutes: Routes = [
  {
    path: '',
    loadComponent: () => import('./pages/user-list/user-list.component').then(m => m.UserListComponent),
  },
  // ← New route to add
];
```

### 13. Announce

```
✅ Component created: <frontend-root>/src/app/features/user/components/user-card/

Files:
  - user-card.component.ts
  - user-card.component.html
  - user-card.component.scss
  - user-card.component.spec.ts

Type: presentation component (or routed page)
Selector: <app-user-card>

Next steps:
- /angular-test to scaffold the detailed tests
- /sdd-implement for the next task
```

## Stop rules

- **Never overwrite an existing file**
- **New components are standalone** where the installed Angular version supports it — and never convert surrounding NgModules as a side effect
- **Always `ChangeDetectionStrategy.OnPush`**
- **Use the discovered selector prefix** (`app-` only as the greenfield default)
- **Prefer Signals over RxJS** for local component state (where the installed version supports them)
- **Generated tests must run on the project's configured runner** — no runner-specific APIs in the skeleton
- **No business logic in the template**
- **No `any`** in the TypeScript
- **Prefer the new control flow syntax** (`@if`, `@for`) over `*ngIf`/`*ngFor` where supported
- **`data-test` attributes** for test selectors (no CSS classes for tests)
