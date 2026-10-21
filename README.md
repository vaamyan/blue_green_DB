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
├── deployment.xml
├── setup_workspaces.sh
├── create_workspace.sh
├── create_initial_content.sh
├── jenkins/
│   └── Dockerfile
└── database/
    ├── admin/
    │   └── create_bluegreen_objects.sql
    ├── jenkins/
    │   ├── check_active_user.sql
    │   ├── check_workspace_objects.sql
    │   ├── create_workspace_database.sql
    │   ├── create_workspace_role.sql
    │   ├── create_workspace_schema.sql
    │   ├── register_active_user.sql
    │   └── select_registered_user.sql
    └── deploy/
        ├── ddl/
        │   ├── install_all_objects.sql
        │   └── <object_type>/*.sql
        └── dml/
            ├── install_all_fixtures.sql
            └── *.sql
```

## Requirements

- Docker Desktop or Docker Engine with the Docker Compose plugin.
- Git.

## First-time setup

From the repository directory, create the local configuration file and
replace the example values with strong passwords:

```bash
cp .env.example .env
```

`.env` contains the PostgreSQL administrator and pgAdmin passwords. Do
not commit it to the repository.

Run the bootstrap to start PostgreSQL and create the Blue-Green control
tables. It does not create developer workspaces or load workspace fixtures:

```bash
./setup_workspaces.sh
```

## Register a developer

Compose initializes the `bluegreen` database and administrator role. The
bootstrap creates `BLUEGREEN_USERS` and `ACTIVE_USERS` in that database. Both
tables have manually assigned `user_id` and `user_name` values. `user_id` is
unique but is not a primary key; `user_name` is unique. Register each developer
once, using the exact `user_name` that Jenkins will receive as
`WORKSPACE_NAME`:

```bash
docker compose exec -T postgres psql -U bluegreen -d bluegreen \
  -c "INSERT INTO bluegreen_users (user_id, user_name) VALUES (1001, 'your_jenkins_username') ON CONFLICT DO NOTHING;"
```

Each developer may have one active workspace. Jenkins uses the exact
`user_name` as the PostgreSQL role, database, and schema name; it does not
generate a name from `user_id`. The SQL status check rejects an unregistered
user, a user already active, or a workspace role/database that already exists.
Create workspaces through the Jenkins job described below. The older helper
script is not part of this Jenkins flow.

## Workspace objects

Each SQL file in `database/deploy/ddl/<object_type>/` creates
one PostgreSQL object and follows the `<object_type>_<number>.sql`
naming pattern. Sequence and sequence-ownership scripts are grouped together
under `sequence/`. Object names and filenames use
stable numbers within each object type. `install_all_objects.sql` lists the
DDL files explicitly in dependency order with psql `\ir` commands.

The files use generic numbered identifiers for all user-created objects
and columns. `table_1` through `table_4` are independent tables. Each table
has its own sequence and a `BEFORE INSERT` trigger that assigns `column_1`
from its own sequence when an insert omits the ID. The object set also includes indexes, constraints, sequences, views, a
materialized view, user-defined types, a domain, functions, a procedure,
four triggers, an aggregate, an operator, a row-level security policy,
text-search objects, extended statistics, and a publication. PostgreSQL creates the range type's associated multirange as
part of the parent type.

The publication defines which table could be replicated. Logical
replication also requires `wal_level = logical` and a subscriber. Table
owners normally bypass their own RLS policies; the example does not
enable `FORCE ROW LEVEL SECURITY`.

The scripts do not create event triggers or foreign-data wrappers, which
require superuser privileges. Extensions depend on installed packages
and their trust settings.

## Workspace data

Initial fixture DML is organized under `database/deploy/dml/`, with one
file per target table. `install_all_fixtures.sql` lists the files explicitly;
`materialized_view_1.sql` refreshes derived data last. Jenkins executes the
installer in a single transaction. The DML
files are repeatable, and each table's trigger assigns its own ID from its
sequence.

Jenkins loads fixture data by running `install_all_fixtures.sql` after manual
approval in the pipeline. For local inspection, an individual DML file can
be run as follows:

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

For a clean first-time startup, run the database bootstrap, then start pgAdmin
and Jenkins:

```bash
./setup_workspaces.sh
docker compose up -d pgadmin jenkins
docker compose ps
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

Create a **Pipeline** job in the Jenkins UI. Under **Pipeline**, choose
**Pipeline script from SCM**, select **Git**, enter the repository URL and
the Git read credential if required, and set the script path to `Jenkinsfile`.
The branch configured here supplies the Jenkinsfile that starts the run. The
pipeline then checks out the branch supplied in the `BRANCH` parameter for its
SQL and deployment files. Keep those branch values aligned when the Jenkinsfile
itself must also come from that branch.

The Jenkinsfile defines `BRANCH` (default `main`) and `WORKSPACE_NAME` (default
blank). After the job loads these parameters, choose **Build with Parameters**.
Set `BRANCH` to the Git branch to deploy and set `WORKSPACE_NAME` to the exact
registered value in `BLUEGREEN_USERS`.

Before running a workspace deployment, create a Jenkins **Username with
password** credential with ID `bluegreen-postgres-admin`, username `bluegreen`,
and the same administrator password configured as `POSTGRES_PASSWORD` in
`.env`. The Compose service supplies `BLUEGREEN_DB_HOST=postgres` and
`BLUEGREEN_DB_PORT=5432`. The custom Jenkins image installs `psql` and Git for
the pipeline. In this local setup, `agent any` runs on Jenkins's built-in node
inside the Jenkins container. No Docker socket is mounted into Jenkins; a
separate build-agent container can be added later to simulate that topology.

`Jenkinsfile` reads SQL paths from `deployment.xml` and invokes those files
with `psql`. The SQL installer files include DDL and fixture files in their
required order. The pipeline checks workspace status, creates its role,
database and schema, applies DDL, pauses for fixture approval, loads fixture
data, then registers the developer in `ACTIVE_USERS`.

Before running the job, add the developer in `BLUEGREEN_USERS` using pgAdmin's
Query Tool connected to the `bluegreen` database, with your own unused ID and
the exact name you intend to pass as `WORKSPACE_NAME`:

```sql
INSERT INTO bluegreen_users (user_id, user_name)
VALUES (1001, 'WORKSPACE01');
```

The values above are examples; replace them if either is already in use. The
parameters are:

- `BRANCH`: the Git branch to deploy.
- `WORKSPACE_NAME`: the exact `user_name` registered in `BLUEGREEN_USERS`.

The pipeline looks up the matching `user_id`, but uses `WORKSPACE_NAME`
unchanged as the PostgreSQL role, database, and schema name. It never builds a
workspace name from the ID. It rejects users already present in `ACTIVE_USERS`
and refuses to reuse an existing or partially created role or database. The
name must be 1-63 ASCII letters, digits, dots, underscores, or hyphens. The
Jenkins job must be access-controlled: a free-form `WORKSPACE_NAME` parameter
proves registry membership, but does not prove the builder's identity.

If Jenkins reports a pending Script Approval for loading `deployment.xml`, a
Jenkins administrator can review it under **Manage Jenkins > Script Approval**.

A failure before registration leaves partially provisioned objects for
inspection; the
pipeline does not silently delete them. The ID triggers stay enabled during
fixture loading and call their table's sequence when an insert omits the ID.
PostgreSQL sequence increments are not rolled back with a failed transaction.

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

After the first-time bootstrap has created the Blue-Green control tables, start
PostgreSQL and pgAdmin in the background:

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

After Jenkins creates a workspace and you set a password for its role, you can
register another pgAdmin server for it. Use the exact `WORKSPACE_NAME` as both
the maintenance database and username. Keep the host as `postgres` and port as
`5432`. Workspace roles are limited to their own database; use the
`BlueGreen Admin` connection for cluster administration and database creation.

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

### 5. Delete the full environment and start from zero

First, make sure `.env` exists and contains the `POSTGRES_PASSWORD` and
`PGADMIN_PASSWORD` values you want to keep using. If `.env` is missing, copy
`.env.example` and edit it before continuing. Do not copy the example over an
existing `.env`:

```bash
cp .env.example .env
# Edit .env and set POSTGRES_PASSWORD and PGADMIN_PASSWORD
```

With `.env` ready, run this from the repository root. It removes the
containers, network, and project volumes. **PostgreSQL databases, roles, and
data are permanently deleted, along with pgAdmin's saved state and Jenkins's
jobs, plugins, credentials, and local accounts.**

```bash
docker compose down --volumes --remove-orphans
```

Recreate PostgreSQL and its Blue-Green control tables, then start pgAdmin and
Jenkins:

```bash
./setup_workspaces.sh
docker compose up -d pgadmin jenkins
docker compose ps
```

Open pgAdmin at <http://localhost:5050> and Jenkins at
<http://localhost:18080>. Since the Jenkins volume was deleted, unlock Jenkins
using its new initial password, install plugins, create a local administrator,
and recreate the Pipeline job and the Git and `bluegreen-postgres-admin`
credentials described above. Get the initial password with:

```bash
docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

In pgAdmin's Query Tool connected to the `bluegreen` database, insert each
developer into `bluegreen_users`, providing a unique `user_id` and the exact
workspace name, as shown in [Register a developer](#register-a-developer). Then
run the Jenkins job with the desired `BRANCH` and that exact `WORKSPACE_NAME`.
Review and approve the fixture load when Jenkins pauses. After a successful
deployment, Jenkins records the developer in `active_users`.
