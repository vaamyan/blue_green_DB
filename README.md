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

The local lab uses PostgreSQL, pgAdmin, and an optional Jenkins container
managed by Docker Compose. A Python API, Nginx router, and production
Blue-Green traffic switching remain future milestones. Kubernetes is out of
scope for the initial milestone.

## Current repository structure

```text
.
├── .env.example
├── docker-compose.yml
├── README.md
├── Jenkinsfile
├── setup_workspaces.sh
├── create_workspace.sh
├── create_initial_content.sh
├── jenkins
│   └── Dockerfile
├── scripts
│   └── jenkins
│       ├── activate_and_validate_workspace.sh
│       ├── apply_workspace_ddl.sh
│       ├── check_workspace_eligibility.sh
│       ├── load_workspace_fixtures.sh
│       ├── provision_workspace.sh
│       ├── register_active_workspace.sh
│       ├── validate_manifests.sh
│       └── verify_side_effects_disabled.sh
└── database
    ├── admin
    │   └── create_bluegreen_objects.sql
    ├── jenkins
    │   ├── check_active_user.sql
    │   ├── check_workspace_objects.sql
    │   ├── create_workspace_database.sql
    │   ├── create_workspace_role.sql
    │   ├── create_workspace_schema.sql
    │   ├── disable_rule_1.sql
    │   ├── disable_trigger_1.sql
    │   ├── enable_runtime_objects.sql
    │   ├── register_active_user.sql
    │   ├── select_registered_user.sql
    │   ├── validate_workspace.sql
    │   └── verify_side_effects_disabled.sql
    ├── deploy
    │   ├── ddl
    │   │   ├── manifest.txt
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
    │   └── dml
    │       ├── manifest.txt
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

Run the bootstrap to start the Blue-Green PostgreSQL service and create its
control tables:

```bash
./setup_workspaces.sh
```

## Roles and workspaces

Compose starts PostgreSQL with the `bluegreen` database and the
`bluegreen` superuser role. The bootstrap starts only the PostgreSQL service and creates the
`BLUEGREEN_USERS` and `ACTIVE_USERS` control tables in the `bluegreen`
database. It does not create a developer workspace or insert registry/data
rows. Both tables have manually
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
stable numbers within each object type. `database/deploy/ddl/manifest.txt`
defines DDL dependency order; `database/deploy/dml/manifest.txt` defines
fixture load order. The local shell helper uses the DDL manifest.

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

The local helper can create a registered user's workspace and apply its DDL
and DML:

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

## Jenkins workspace deployment

Jenkins is an optional container, separate from PostgreSQL. Its web interface
is published only on this machine at <http://localhost:18080>. The container
joins the Compose network and reaches PostgreSQL at `postgres:5432`; `localhost`
inside Jenkins would mean the Jenkins container itself. PostgreSQL remains
bound to host loopback on port `5432`.

Start the database bootstrap first, then start Jenkins when you want to use
the interface:

```bash
./setup_workspaces.sh
docker compose up -d jenkins
```

Run these commands from the repository directory. Once the container is
running, open <http://localhost:18080> in your browser. Jenkins is available
only on this machine; no account on jenkins.io is required.

On the first visit, Jenkins asks for its initial administrator password. Get
it from the container with:

```bash
docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Paste the password into the unlock page, install the suggested plugins, and
create a Jenkins administrator account. This account is local to this Jenkins
instance; there is no external Jenkins signup account. See the [official
Jenkins Docker setup guide](https://www.jenkins.io/doc/book/installing/docker/)
for details about the initial unlock process.

To stop Jenkins while keeping its configuration, jobs, plugins, and accounts,
run:

```bash
docker compose stop jenkins
```

Start it again later with:

```bash
docker compose start jenkins
```

To check whether Jenkins is running, use:

```bash
docker compose ps jenkins
```

The initial administrator password is needed only for the first unlock. Jenkins
stores its setup in the `jenkins_data` volume, so stopping or restarting the
container does not repeat the first-time setup.

Create a **Pipeline** job in the Jenkins UI. In its **Pipeline** section,
choose **Pipeline script from SCM**, select **Git**, enter the repository URL
and credentials if needed, and set the branch containing the `Jenkinsfile`.
Use `Jenkinsfile` as the script path. The first run may stop at input
validation because `WORKSPACE_USER` is blank; it does not create a database.
After Jenkins has loaded the parameter definitions, select **Build with
Parameters** and provide `BRANCH` and `WORKSPACE_USER`.

Before running a workspace deployment, create a Jenkins **Username with
password** credential with ID `bluegreen-postgres-admin`, username `bluegreen`,
and the same administrator password configured as `POSTGRES_PASSWORD` in
`.env`. The Compose service supplies `BLUEGREEN_DB_HOST=postgres` and
`BLUEGREEN_DB_PORT=5432`. The custom Jenkins image installs `psql` and Git for
the pipeline. In this local setup, `agent any` runs on Jenkins's built-in node
inside the Jenkins container. No Docker socket is mounted into Jenkins; a
separate build-agent container can be added later to simulate that topology.

`Jenkinsfile` provisions one workspace for a registered user by calling the
shell entry points in `scripts/jenkins/`. Those scripts run the SQL files in
`database/jenkins/` and the DDL/DML manifests; the pipeline itself coordinates
the stages and approval. The parameters are:

- `BRANCH`: the Git branch to deploy.
- `WORKSPACE_USER`: the exact username registered in `BLUEGREEN_USERS`.

The pipeline looks up the user's manually assigned `user_id` and derives the
workspace name as `workspace_<user_id>`. It rejects users already present in
`ACTIVE_USERS` and refuses to reuse an existing or partially created role or
database. The Jenkins job must be access-controlled: a free-form
`WORKSPACE_USER` parameter proves registry membership, but does not prove the
builder's identity.

The stages validate both manifests and the registry entry, check workspace
availability, create the role/database/schema, apply DDL in manifest order,
verify the trigger and rule are disabled, pause for manual review before
loading fixture data in one transaction, enable the trigger and rule, validate
fixture counts and the materialized view, then register the user in
`ACTIVE_USERS`. A failure
before registration leaves any partially provisioned objects for inspection;
the pipeline does not silently delete them. PostgreSQL has no disabled state
for sequences: their values change only when `nextval` or `setval` is called.
The fixture DML intentionally advances its owned sequences; PostgreSQL
sequence increments are not rolled back with the data transaction. The sample
trigger and rule are disabled while fixture DML runs and enabled before
validation and registration.

Use synthetic data only. Do not store real employer, customer, or
personal information in this lab.

## Isolated development environments

The current configuration is intended for one local environment at a
time: it uses fixed container names and publishes ports `5432`, `5050`, and
`18080` on localhost. Running multiple copies at once would require
parameterizing those names and ports in `docker-compose.yml`.

---

## Docker Compose command tutorial

Run these commands from the directory containing `docker-compose.yml`.

### 1. Start the environment

Start PostgreSQL and pgAdmin in the background:

```bash
docker compose up -d postgres pgadmin
```

Check the service status and wait for PostgreSQL to report `healthy`:

```bash
docker compose ps
```

Open pgAdmin at <http://localhost:5050>. The configured username is
`admin@example.com`; its password is the `PGADMIN_PASSWORD` value in
`.env`. This account signs in to the pgAdmin web interface; it is
separate from the PostgreSQL roles.

When you want Jenkins, start only that service (PostgreSQL is also started if
it is not already running):

```bash
docker compose up -d jenkins
```

Open <http://localhost:18080> to use Jenkins. Its saved jobs, plugins, and
local accounts are kept in the `jenkins_data` volume.

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
with pgAdmin's and Jenkins's saved configuration, jobs, and local accounts.**

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
