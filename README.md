# Blue-Green Deployment Lab

A portfolio project for practicing Blue-Green deployments, database
schema changes, and controlled promotion of a release from UAT to
Production.

> **Current status:** local PostgreSQL database with Docker Compose.
> The API, Blue-Green traffic routing, CI/CD, and automatic rollback are
> planned for later milestones.

## Goals

- Deploy a candidate revision to UAT and promote the same revision to
  Production after validation.
- Keep the active version available while the candidate is deployed and
  checked.
- Practice schema changes that remain compatible with both versions.
- Isolate developer work environments.
- Use synthetic data only.

## Planned architecture

```text
Development branch
        |
        v
GitHub Actions: tests and build
        |
        v
UAT: deploy candidate -> health checks -> acceptance tests
        |
        v
Manual approval / promote the same validated revision
        |
        v
PROD: deploy to inactive color -> validate -> switch traffic
```

The first implementation uses PostgreSQL and Docker Compose. A Python
API, Nginx router, and GitHub Actions workflows will be added later.
Kubernetes is out of scope for the initial milestone.

## Current repository structure

```text
.
├── .env.example
├── docker-compose.yml
├── README.md
├── setup_workspaces.sh
├── create_workspace.sh
├── create_initial_content.sh
└── database
    ├── admin
    │   └── create_bluegreen_users.sql
    ├── deploy
    │   ├── ddl
    │   │   ├── aggregate/
    │   │   ├── constraint/
    │   │   ├── domain/
    │   │   ├── function/
    │   │   ├── index/
    │   │   ├── materialized_view/
    │   │   ├── operator/
    │   │   ├── policy/
    │   │   ├── procedure/
    │   │   ├── publication/
    │   │   ├── rule/
    │   │   ├── security/
    │   │   ├── sequence/
    │   │   ├── statistics/
    │   │   ├── table/
    │   │   ├── text_search/
    │   │   ├── trigger/
    │   │   ├── type/
    │   │   └── view/
    │   ├── dev/
    │   └── dml/
    │       ├── materialized_view_1.sql
    │       ├── table_1.sql
    │       ├── table_2.sql
    │       ├── table_4.sql
    │       └── table_5.sql
```

## Requirements

- Docker Desktop or Docker Engine with the Docker Compose plugin.
- Git.

## Initial setup

From the repository directory, create the local configuration file and
replace the example values with strong passwords:

```bash
cp .env.example .env
```

`.env` contains the PostgreSQL administrator and pgAdmin passwords. Do
not commit it to the repository.

Run the bootstrap to create the user registries before adding
authorized Jenkins usernames:

```bash
./setup_workspaces.sh
```

## Roles and workspaces

Compose starts PostgreSQL with the `bluegreen` database and the
`bluegreen` superuser role. The bootstrap creates `BLUEGREEN_USERS` and
`ACTIVE_USERS` in the `bluegreen` database. Both tables have manually
assigned `user_id` and `user_name` values.
`user_id` is unique but is not a primary key, and `user_name` is unique so
the Jenkins lookup is unambiguous. Add both values when registering a user:

```bash
docker compose exec -T postgres psql -U bluegreen -d bluegreen \
  -c "INSERT INTO bluegreen_users (user_id, user_name) VALUES (1001, 'your_jenkins_username') ON CONFLICT DO NOTHING;"
```

A Jenkins job can request a workspace by passing the registered username
and a workspace name to the creation script:

```bash
./create_workspace.sh your_jenkins_username workspace_1
```

The script checks the username in `BLUEGREEN_USERS`, creates a matching
login role, database, and schema, then applies the DDL and DML from
`database/deploy/`. Workspace roles cannot create databases or administer
other roles. Once deployment succeeds, the script copies that user's ID
and name into `ACTIVE_USERS`; a user already in that table cannot create a
second workspace. The generated role has no password set yet; Jenkins runs
the deployment using `bluegreen` and switches to the workspace role.
Password provisioning for application connections will be a separate step.

For this first version, the username is supplied as a script argument.
Jenkins must eventually populate it from the authenticated build identity;
a free-form build parameter alone does not prove who started the job.

## Workspace objects

Each SQL file in `database/deploy/ddl/<object_type>/` creates
one PostgreSQL object and follows the `<object_type>_<number>.sql`
naming pattern. Sequence and sequence-ownership scripts are grouped together
under `sequence/` for later consolidation. Object names and filenames use
stable numbers within each object type. `create_initial_content.sh` applies
the baseline DDL in dependency order. `create_workspace.sh` then runs the
repeatable DML from `database/deploy/dml/` for the requested workspace.

The files use generic numbered identifiers for all user-created objects
and columns. `table_1` holds the primary fixture rows; `table_2` is a
partitioned table with `table_3` as its partition; `table_4` holds
role-scoped rows; and `table_5` stores export configuration. The object
set includes indexes, constraints, sequences, views, a materialized
view, user-defined types, a domain, functions, a procedure, a trigger, a
rule, an aggregate, an operator, a row-level security policy, text-search
objects, extended statistics, and a publication. PostgreSQL creates the
range type's associated multirange as part of the parent type.

The publication defines which table could be replicated. Logical
replication also requires `wal_level = logical` and a subscriber. Table
owners normally bypass their own RLS policies; the example does not
enable `FORCE ROW LEVEL SECURITY`.

The scripts do not create event triggers or foreign-data wrappers, which
require superuser privileges. Extensions depend on installed packages
and their trust settings.

## Export configuration

`table_5` stores per-table metadata for a future Blue-Green
export/import process. `column_1` identifies a table, `column_2` sets
its processing order, and `column_3` selects configuration copy
(`CONFIG`), source-schema copy (`BLUEGREEN_SOURCE`), or exclusion
(`NONE`). `column_4` optionally overrides the source schema. `column_5`
and `column_6` list related triggers and sequences; `column_7` enables
or disables a row, and `column_8` stores a note.

This table is configuration only; the export/import engine is a later
milestone. Its DML registers `table_5` first, followed by `table_1`,
`table_2`, and `table_4`. Rows for `table_2` are routed to `table_3` by
partitioning.

## Workspace data

Initial fixture DML is organized under `database/deploy/dml/`, with one
file per target object. `table_5.sql` loads export configuration first,
followed by `table_1.sql`, `table_2.sql`, and `table_4.sql`;
`materialized_view_1.sql` refreshes derived data last. The DML files are
repeatable. Rows inserted into `table_2` are routed to its partition,
`table_3`.

Create a registered user's workspace and apply all initial DDL and DML:

```bash
./create_workspace.sh your_jenkins_username workspace_1
```

To run an individual DML file, use `bluegreen` and switch to the target
workspace role. For example:

```bash
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 --single-transaction \
  -U bluegreen -d workspace_1 -v workspace=workspace_1 \
  -c 'SET ROLE "workspace_1"' \
  -f /dev/stdin < database/deploy/dml/table_1.sql
```

## Queries to check the environment

List the databases:

```bash
docker compose exec postgres psql -U bluegreen -d postgres \
  -c "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;"
```

Check the roles and whether they can create databases:

```bash
docker compose exec postgres psql -U bluegreen -d postgres \
  -c "SELECT rolname, rolsuper, rolcreatedb, (rolsuper OR rolcreatedb) AS can_create_databases FROM pg_roles WHERE rolname = 'bluegreen' OR rolname LIKE 'workspace_%' ORDER BY rolname;"
```

## Database and deployment design principles

Blue and Green represent application versions; they do not require
separate Production databases by default. Schema changes should remain
compatible with both versions during a transition. Prefer an
**expand-and-contract** sequence:

1. Add a backward-compatible schema change.
2. Deploy and validate the new version.
3. Switch traffic and monitor health.
4. Remove obsolete schema elements after the old version no longer uses
   them.

A traffic rollback does not automatically reverse writes or destructive
schema changes. Migrations and data recovery need their own plan. For
Production, promote the same immutable artifact that passed UAT.

## Planned milestones

- [x] Choose PostgreSQL and prepare the local database foundation.
- [x] Add a registry-backed workspace creation prototype.
- [x] Add PostgreSQL object examples for each workspace.
- [ ] Create Blue and Green versions of the Python API.
- [ ] Add health checks and integration tests.
- [ ] Implement traffic switching and rollback.
- [ ] Add CI and UAT deployment.
- [ ] Add approval-gated Production promotion.
- [ ] Document migrations and data preservation between versions.

## Synthetic data

Use synthetic data only. Do not store real employer, customer, or
personal information in this lab.

## Isolated development environments

The current configuration is intended for one local environment at a
time: it uses fixed container names and publishes ports `5432` and
`5050` on localhost. Running multiple copies at once would require
parameterizing those names and ports in `docker-compose.yml`.

---

## Docker Compose command tutorial

Run these commands from the directory containing `docker-compose.yml`.

### 1. Start the environment

Start PostgreSQL and pgAdmin in the background:

```bash
docker compose up -d
```

Check the service status and wait for PostgreSQL to report `healthy`:

```bash
docker compose ps
```

Open pgAdmin at <http://localhost:5050>. The configured username is
`admin@example.com`; its password is the `PGADMIN_PASSWORD` value in
`.env`. This account signs in to the pgAdmin web interface; it is
separate from the PostgreSQL roles.

### Configure the PostgreSQL connection in pgAdmin

In pgAdmin, right-click **Servers** and select **Register > Server...**.
On the **General** tab, enter a display name such as `BlueGreen Admin`.
On the **Connection** tab, use these values:

| Field | Value |
|---|---|
| Host name/address | `postgres` |
| Port | `5432` |
| Maintenance database | `bluegreen` |
| Username | `bluegreen` |
| Password | The `POSTGRES_PASSWORD` value from `.env` |

Enable **Save password** if you want pgAdmin to remember it, then select
**Save**. Use `postgres` as the host because pgAdmin connects to the
PostgreSQL service over the Docker Compose network. `localhost` would
refer to the pgAdmin container itself.

After creating a workspace and setting a password for its role, you can
register another pgAdmin server for it. Use the generated workspace name
(for example, `workspace_1`) as both the maintenance database and username.
Keep the host as `postgres` and port as `5432`. Workspace roles are
limited to their own database; use the `BlueGreen Admin` connection for
cluster administration and database creation.

### 2. View logs

```bash
docker compose logs -f postgres
```

Press `Ctrl+C` to leave the log stream; this does not stop the
container. To view pgAdmin logs as well, run:

```bash
docker compose logs -f
```

### 3. Open a PostgreSQL console

Connect as the administrator:

```bash
docker compose exec -it postgres psql -U bluegreen -d bluegreen
```

Connect to a workspace:

```bash
docker compose exec -it postgres psql -U workspace_1 -d workspace_1
```

Inside `psql`, run `\q` to exit.

### 4. Stop and keep the data

Stop the containers but keep them created:

```bash
docker compose stop
```

Start them again with:

```bash
docker compose start
```

You can also remove the containers and network. The databases and
pgAdmin data remain in their volumes:

```bash
docker compose down
```

Then `docker compose up -d` recreates the containers using the existing
volumes.

### 5. Remove everything and start fresh

This command removes the containers, network, and project volumes.
**PostgreSQL databases, roles, and data are permanently deleted, along
with pgAdmin's saved configuration.**

```bash
docker compose down --volumes --remove-orphans
```

Create a fresh environment again with:

```bash
docker compose up -d
```

Compose creates the PostgreSQL and pgAdmin services. Run the bootstrap
to create both user tables, then register Jenkins users and request a
workspace with `create_workspace.sh`:

```bash
./setup_workspaces.sh
docker compose exec -T postgres psql -U bluegreen -d bluegreen \
  -c "INSERT INTO bluegreen_users (user_id, user_name) VALUES (1001, 'your_jenkins_username') ON CONFLICT DO NOTHING;"
./create_workspace.sh your_jenkins_username workspace_1
```

The workspace creation command refuses usernames absent from the registry,
users already in `ACTIVE_USERS`, and existing or partially created
workspace role/database pairs.
It does not stop or purge containers or volumes.
