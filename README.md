# Blue-Green Deployment Lab

A reproducible portfolio project for demonstrating Blue-Green
deployments, isolated developer environments, database change
management, and controlled promotion to UAT and Production.

> **Current milestone:** PostgreSQL database foundation. The
> application, traffic switching, CI/CD workflows, and automated
> rollback will be added in later milestones.

## Goals

1.  Deploy a selected code revision to **UAT** and promote a validated
    revision to **PROD**.
2.  Keep the currently active version available while the candidate
    version is deployed and checked.
3.  Support controlled data/schema transitions between the old and new
    application versions.
4.  Give each developer an isolated environment for builds, tests,
    commits, and database changes.
5.  Make the demo reproducible using synthetic employee data only.

## Initial architecture

``` text
Developer branch
      |
      v
GitHub Actions: tests + build
      |
      v
UAT: deploy candidate -> health checks -> acceptance tests
      |
      v
Manual approval / promotion of the same tested revision
      |
      v
PROD: deploy inactive colour -> validate -> switch traffic
      |
      +---- failure before switch: keep old version active
      |
      +---- failure after switch: switch traffic back when safe
```

The first local implementation will use:

-   **PostgreSQL** for persistence.
-   **Docker Compose** for a reproducible local database and, later,
    application services.
-   **Python API** for a small employee demo service.
-   **Nginx** as the eventual traffic router between Blue and Green.
-   **GitHub Actions** for CI/CD automation.
-   **Synthetic data** only; never use employer or customer data.

Kubernetes is intentionally out of scope for the first milestone.

## Repository layout

``` text
blue-green-deployment-lab/
├── .env.example
├── docker-compose.yml
├── README.md
└── database/
    └── init/
        ├── 001_schema.sql
        └── 002_seed.sql
```

Planned additions:

``` text
├── app/                 # Python API and automated tests
├── database/migrations/ # Versioned schema changes
├── deployment/          # Blue/Green switching, health checks, rollback
└── .github/workflows/   # CI, UAT deployment, approved PROD promotion
```

## Milestone 1 --- Start the database

### Requirements

-   Docker Desktop or Docker Engine with the Compose plugin.
-   Git.

### Setup

``` bash
git clone <your-repository-url>
cd blue-green-deployment-lab
cp .env.example .env
```

Review `.env` and choose a local port that is not already in use. Then
start PostgreSQL:

``` bash
docker compose up -d
docker compose ps
docker compose logs -f db
```

The database container runs the SQL files in `database/init/` on its
**first initialization**, creating the schema and synthetic sample
records.

Check the data:

``` bash
docker compose exec db psql -U bluegreen -d bluegreen_demo \
  -c "SELECT department_name, count(*) AS employees FROM employees e JOIN departments d USING (department_id) GROUP BY department_name ORDER BY department_name;"
```

Stop the environment:

``` bash
docker compose down
```

This preserves the database volume. To deliberately remove the local
demo database and all its data:

``` bash
docker compose down -v
```

**Warning:** `down -v` permanently deletes the local database volume.
Use it only for disposable demo data. Editing the initialization SQL
files does not re-run them against an existing volume; use a migration
or recreate the disposable volume.

## Isolated developer environments

Each developer should use a separate Compose project name, `.env`
file/port, and project-scoped database volume. For example:

``` bash
docker compose -p bg-dev-alex up -d
```

Another developer can use a different project name and host port:

``` bash
PG_PORT=55433 docker compose -p bg-dev-sam up -d
```

Compose project names isolate container and volume names. Host ports
must also be unique when multiple environments run on the same machine.
For a shared team server, isolation must additionally be enforced
through permissions and separate credentials; a different Compose
project name alone is not a security boundary.

## Database and deployment design principles

### Blue/Green and persistent data

Blue and Green are application versions; they do not automatically need
separate production databases. Initially, both demo versions will use
the same PostgreSQL database so the traffic switch can be demonstrated
without introducing replication complexity.

Schema changes must be compatible with both versions during the
transition. Prefer an **expand-and-contract** sequence:

1.  Add a backward-compatible schema change.
2.  Deploy and validate the new application version.
3.  Switch traffic and observe health.
4.  Remove obsolete schema elements only after the old version no longer
    needs them.

A traffic rollback does not automatically roll back database writes or
destructive schema changes. Database migrations and recovery therefore
need their own explicit plan.

### Copying data from old to new

The deployment workflow will distinguish between: - **Application
promotion:** deploy the exact revision/image tested in UAT. - **Schema
migration:** apply versioned SQL migrations in a controlled order. -
**Data migration/copy:** copy only the data required by a defined
migration, with validation and a repeatable/recoverable procedure.

For Production, prefer promoting the same immutable build that passed
UAT rather than rebuilding arbitrary branch contents. The workflow can
allow choosing a branch/revision for UAT; Production should promote a
reviewed, tested revision with a manual approval gate.

## Planned milestones

-   [x] Choose PostgreSQL and define the demo database foundation.
-   [ ] Start Blue and Green versions of the Python API.
-   [ ] Add health checks and automated integration tests.
-   [ ] Add controlled traffic switching and rollback.
-   [ ] Add GitHub Actions for branch/revision selection and UAT
    deployment.
-   [ ] Add approval-gated Production promotion.
-   [ ] Add migration examples and test data-preservation across
    versions.
-   [ ] Add screenshots, architecture diagram, and demo instructions.

## Demo data

All names, emails, salaries, dates, and departments are fictional. The
database is for demonstrating deployment behaviour, not for storing real
employee information.


# Remember
docker compose -p bluegreen up -d
docker exec -it bluegreen-dev-postgres psql -U bluegreen -d bluegreen
docker compose -p bluegreen down
docker compose -p bluegreen-dev down --volumes --remove-orphans # borrar todo


