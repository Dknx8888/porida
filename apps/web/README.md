# Porida web app

Next.js/React frontend using HeroUI v3, Tailwind CSS v4, TanStack Query, and
openapi-fetch. The active portfolio list reads from the ASP.NET Core REST API.

See [the project setup guide](../../SETUP.md) for the unified Ubuntu,
Ultramarine, and Windows setup script, PostgreSQL, and API User Secrets.

## Run from the repository root

~~~bash
bun install --frozen-lockfile
bun run dev:api
~~~

In a separate terminal:

~~~bash
bun run dev:web
~~~

Open the address printed by Next.js.

## API connection and generated types

Copy .env.example to .env.local if needed. API_BASE_URL selects the backend
used by the Next.js /api rewrite; its local default is http://127.0.0.1:5100.
Restart the web server after changing it.

With the .NET API running in Development, from the repository root:

~~~bash
bun run --cwd apps/web generate:api
~~~

This regenerates src/lib/api/schema.d.ts from the .NET OpenAPI contract.

Route composition lives in src/app. Portfolio code lives in
src/features/portfolios, shared layout in src/components/layout, and the
TanStack provider in src/providers. The create form is a saved draft; its
submission flow is not connected yet.

## Checks

From the repository root:

~~~bash
bun run lint:web
bun run build:web
~~~

Unused draft imports and mutation setup currently produce accepted lint
warnings while feature development is paused.
