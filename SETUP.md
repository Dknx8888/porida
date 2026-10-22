# Porida development setup

Porida uses ASP.NET Core 10 and EF Core/Npgsql for its REST API, PostgreSQL 18
for storage, and Next.js/React with TanStack Query and openapi-fetch for the web
app. Bun manages the web workspace and launches root development commands.

## One setup entry point

Run **porida-setup.sh** from Bash. It detects the operating system.

| Platform | Supported releases | Package installation |
| --- | --- | --- |
| Ubuntu | 22.04, 24.04, 26.04; x64/arm64 | APT; Canonical .NET backports on 22.04; PGDG if PostgreSQL 18 is unavailable |
| Ultramarine | 43, 44; x64/arm64 | DNF and native Fedora packages |
| Windows | x64, using Git Bash | Embedded Windows PowerShell; WinGet and the official Bun installer |

Linux full setup requires sudo, systemd, and a Bash or Zsh login shell.
Run it as your regular user. Export ZDOTDIR before running if you use a custom
Zsh profile directory. WSL follows its Linux distribution; enable systemd
before full setup.

Windows requires Git for Windows (including Git Bash), Windows PowerShell
5.1 or later, and WinGet from Microsoft App Installer. Open Git Bash as
Administrator for **full setup**, using your usual Windows account. Checks and
API secret configuration can run without elevation. The tools, database
service, and API are native Windows programs.

Required tool versions are .NET SDK 10.0, Node 24.x, Bun 1.4.2, PostgreSQL 18.
The script explicitly selects a Node 24.x WinGet version instead of assuming
the latest LTS package always has that major.

## Inspect, install, and check

From the repository root, on any supported platform:

~~~bash
bash porida-setup.sh --help
bash porida-setup.sh --plan
bash porida-setup.sh
bash porida-setup.sh --check
~~~

Full setup shows its plan and asks before installing. On Windows the PostgreSQL
installer is interactive: choose port **5432**, its default version-18 Windows
service, and a private password for the **postgres** administrator.

| Mode | Purpose |
| --- | --- |
| No option | Install tools, start PostgreSQL, initialize missing Porida database objects |
| --plan | Print the platform's planned actions |
| --check | Read-only checks of active tool versions, service, and localhost readiness |
| --db-only | Initialize Porida using an already-running PostgreSQL 18 |
| --configure-api | Privately prompt for the app-role password and save the local API connection setting |

A tool check does not authenticate application credentials, verify the server
version with a database query, or establish that a nonempty database has the
complete Porida schema.

## Database behavior

The application role is **portfolio_app**, the database is
**portfolio_risk_dashboard**, and the server is **localhost:5432**.

The script creates a role or database only if missing. It preserves existing
passwords and requires the database owner to be portfolio_app. It imports
**database/schema.sql** as the application role only when the database has no
user relations, routines, types, custom schemas, or additional extensions.
Import runs in one transaction. Nonempty databases are kept, with schema
completeness left for a deliberate migration.

Incompatible clusters, ports, and custom data/service arrangements cause a
clear failure instead of an automatic upgrade or data-directory replacement.
Ultramarine full setup maintains a backed-up, Porida-only localhost SCRAM block
in pg_hba.conf. The db-only mode never changes authentication.

Windows database initialization prompts privately for the local postgres
administrator password. A temporary pgpass file is protected with an
owner-only Windows ACL and deleted in a finally block. The application role's
password is entered through psql's password prompt, never a command argument.

The schema path is relative to the setup script, so the working directory and
the user's home-directory layout do not affect discovery. To override it:

~~~bash
PORIDA_SCHEMA_FILE=/absolute/path/schema.sql bash porida-setup.sh --db-only
~~~

On Windows, use a Git Bash path such as /d/Workshop/.../schema.sql.

## Configure the API on each OS/user account

After tool/database setup:

~~~bash
bash porida-setup.sh --configure-api
~~~

Enter the existing local **portfolio_app** database password. The command
stores **ConnectionStrings:Porida** using the project's existing UserSecretsId.
It sends JSON to the .NET CLI over stdin, correctly encoding punctuation and
Unicode. Other secret keys are retained. Run this mode deliberately when
creating or changing this local connection setting.

Windows and Linux keep separate User Secrets stores, even when they share a
checkout. ASP.NET Core loads these settings in Development.

The same mode copies the frontend environment example to
**apps/web/.env.local** only if that local file is missing. Its setting is:

~~~dotenv
API_BASE_URL=http://127.0.0.1:5100
~~~

Next.js reads this setting on the server to proxy browser /api requests.
Restart the web server after editing it. Environment files are ignored;
**apps/web/.env.example** is versioned.

## Install project packages and run

Open a fresh terminal after full setup. Linux uses Node 24 through NVM; Windows
uses the installed native Node executable. From the repository root:

~~~bash
bun install --frozen-lockfile
~~~

Start these in separate terminals:

~~~bash
bun run dev:api
~~~

~~~bash
bun run dev:web
~~~

The API's http launch profile listens on localhost:5100. Open the address
printed by Next.js for the web app.

The root Porida.slnx refers to apps/api/Porida.Api.csproj. The only Bun
application workspace is apps/web; .NET packages are restored from the
.csproj through NuGet.

## Generate the frontend API contract

With the API running in Development, from the repository root:

~~~bash
bun run --cwd apps/web generate:api
~~~

This fetches /openapi/v1.json and regenerates
**apps/web/src/lib/api/schema.d.ts**. Regenerate it after API-contract changes.
These declarations provide compile-time request/response types.
Next.js generates its route and layout types during dev/build; after a fresh
checkout, run `bun run --cwd apps/web dev` or `bun run build:web` before a
standalone TypeScript check.

## Validation commands

From the repository root:

~~~bash
bun run build:api
bun run lint:api
bun run lint:web
bun run build:web
~~~

The API lint command uses dotnet format with --verify-no-changes.
The frontend currently retains intentionally unfinished form/sidebar imports
and mutation setup; their unused-variable warnings are accepted while that
feature work is paused.

## Upstream installation references

- [.NET on Ubuntu](https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu)
- [.NET on Fedora](https://learn.microsoft.com/en-us/dotnet/core/install/linux-fedora)
- [.NET on Windows and WinGet](https://learn.microsoft.com/en-us/dotnet/core/install/windows)
- [Bun installation and version selection](https://bun.com/docs/installation)
- [PostgreSQL Windows installers](https://www.postgresql.org/download/windows/)
- [Microsoft's PostgreSQL 18 WinGet manifest](https://github.com/microsoft/winget-pkgs/tree/master/manifests/p/PostgreSQL/PostgreSQL/18)
