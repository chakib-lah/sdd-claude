---
description: Layer 2 — Node.js/Express backend-specific conventions
---

# Node.js / Express conventions

> **Layer 2 — Specific to the Node.js backend.**  
> Adapt according to the detected framework (Express, Fastify, NestJS).

---

## Express — Controller structure

```typescript
// src/controllers/user.controller.ts
import { Request, Response, NextFunction } from 'express';
import { UserService } from '../services/user.service';
import { createUserSchema } from '../schemas/user.schema';

export class UserController {
  constructor(private readonly userService: UserService) {}

  async create(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const payload = createUserSchema.parse(req.body); // Zod validation
      const user = await this.userService.create(payload);
      res.status(201).json(user);
    } catch (err) {
      next(err); // delegate to the error middleware
    }
  }
}
```

## Express — Route structure

```typescript
// src/routes/user.routes.ts
import { Router } from 'express';
import { UserController } from '../controllers/user.controller';
import { authMiddleware } from '../middleware/auth.middleware';

const router = Router();
const controller = new UserController(/* injection */);

router.post('/', authMiddleware, controller.create.bind(controller));
router.get('/:id', authMiddleware, controller.findById.bind(controller));
router.get('/', authMiddleware, controller.findAll.bind(controller));

export { router as userRouter };
```

## Validation — Zod

```typescript
// src/schemas/user.schema.ts
import { z } from 'zod';

export const createUserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  firstName: z.string().optional(),
});

export type CreateUserDto = z.infer<typeof createUserSchema>;
```

## Environment variables — Validation at startup

```typescript
// src/config/env.ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']),
  PORT: z.string().default('3000'),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
});

export const env = envSchema.parse(process.env);
```

## Auth — JWT middleware

```typescript
// src/middleware/auth.middleware.ts
import jwt from 'jsonwebtoken';
import { env } from '../config/env';

export const authMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ message: 'Unauthorized', code: 'MISSING_TOKEN' });

  try {
    req.user = jwt.verify(token, env.JWT_SECRET) as JwtPayload;
    next();
  } catch {
    return res.status(401).json({ message: 'Invalid token', code: 'INVALID_TOKEN' });
  }
};
```

## Logging

Use a logger (Winston, Pino) rather than `console.log`:

```typescript
import pino from 'pino';
export const logger = pino({ level: process.env.LOG_LEVEL ?? 'info' });

// Usage
logger.info({ userId: user.id }, 'User created');
logger.error({ err }, 'Unexpected error');
```

## Anti-patterns

- ❌ Business logic in controllers
- ❌ Direct DB access from controllers
- ❌ `console.log` in production
- ❌ Unvalidated environment variables
- ❌ Scattered `try/catch` blocks without a centralized middleware
- ❌ `any` in request/response types
- ❌ Secrets in the source code
