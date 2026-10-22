# Blue-Green Database Deployment Lab

A local PostgreSQL environment for developing isolated workspaces and
practicing controlled database deployments through BlueGreen.

> **Current status:** PostgreSQL, pgAdmin, Jenkins, and development workspace
> deployment are available locally. Export, environment deletion, higher
> environment deployment, and switching are planned work.

## Goals

- Isolate developer work in individual DEV workspaces.
- Export selected changes from a DEV workspace into deployment files.
- Deploy database changes to UAT and Production through BlueGreen.
- Switch to a deployed environment and switch back to the previous one when
  needed.
- Delete a selected environment.
- Use synthetic data only.

## Environment workflow

```text
DEV workspace -> Export -> BlueGreen deploy to UAT or Production
                                  |                 |
                                  v                 v
                              Switch to new environment
                                  |
                                  v
                         Reverse switch to previous environment
```

UAT and Production are deployment targets for the same BlueGreen workflow.
The developer workspace export, environment deletion, higher environment
deployment, switch, and reverse switch are planned milestones; this diagram
describes the intended workflow, not functionality that is already available.

The local lab uses PostgreSQL, pgAdmin, and Jenkins containers managed by
Docker Compose.

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

## Planned milestones

- [x] Choose PostgreSQL and prepare the local database foundation.
- [x] Add a registry-backed workspace creation prototype.
- [x] Add PostgreSQL object examples for each workspace.
- [ ] Export selected changes from a DEV workspace into deployment files.
- [ ] Delete a selected workspace or environment.
- [ ] Deploy database changes through BlueGreen to UAT and Production.
- [ ] Switch to the newly deployed environment.
- [ ] Reverse the switch and return to the previous environment.

## Jenkins workspace deployment

Jenkins runs in a separate container from PostgreSQL. Open its local interface
at <http://localhost:18080>. Inside the Jenkins container, PostgreSQL is
reachable at `postgres:5432` (not `localhost`). The steps below assume you are
working from the repository root.

### Step 1: Start PostgreSQL, pgAdmin, and Jenkins

For a new or purged environment, create the Blue-Green database and its control
tables, then start the web interfaces. Make sure `.env` has both
`POSTGRES_PASSWORD` and `PGADMIN_PASSWORD` before starting:

```bash
./setup_workspaces.sh
docker compose up -d pgadmin jenkins
docker compose ps jenkins
```

If the database and control tables already exist and the containers are merely
stopped, start them with `docker compose start postgres pgadmin jenkins`.

### Step 2: Unlock Jenkins and create its local administrator

Open <http://localhost:18080>. On the first launch, retrieve the initial
administrator password:

```bash
docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Paste that password into the unlock page, choose **Install suggested plugins**,
and create a Jenkins administrator account. This account is only for signing
in to this Jenkins instance; it is not your GitHub account or a PostgreSQL
account. The `jenkins_data` volume preserves this setup unless you purge it.

### Step 3: Create the Git repository credential

In Jenkins, open **Manage Jenkins > Credentials > System > Global credentials**
and choose **Add Credentials**. Select these values:

| Field | Value |
|---|---|
| Kind | **SSH Username with private key** |
| Scope | **Global** |
| Username | `git` |
| Private Key | **Enter directly**, then paste the complete contents of your private key file (for example, `id_ed25519`) |
| Passphrase | Enter the key's passphrase, if it has one |
| ID | `github-repository-read` |

The SSH username is `git`, not your GitHub username. Paste the private key
contents including the `BEGIN` and `END OPENSSH PRIVATE KEY` lines. Do not paste
the filename, the public key (`id_ed25519.pub`), or your GitHub account name in
the private-key field. The matching public key must be authorized for read
access to the repository in GitHub.

When configuring the job, select this SSH credential for the Git repository.
Jenkins may display it as `git`, depending on the credential label. Confirm it
is the **SSH Username with private key** credential. Do not select
`bluegreen`; that credential is for PostgreSQL.

Add the matching public key to GitHub under **Settings > SSH and GPG keys >
New SSH key**. The public key is the `.pub` file; Jenkins receives the private
key. The GitHub account that owns the key must have read access to
`vaamyan/blue_green_DB`.

If Jenkins reports `No ED25519 host key is known for github.com and you have
requested strict checking`, the connection is failing at SSH host-key
verification, before repository access is checked. This is separate from the
private-key credential, so changing the branch will not fix it. In Jenkins:

1. Open **Manage Jenkins > Security > Git Host Key Verification Configuration**.
2. Change the strategy to **Accept first connection**.
3. Save the setting and retry the job.

This strategy remembers the server key on the first connection and checks it
on later connections. Alternatively, use **Known hosts file** or **Manually
provided keys** with GitHub's verified host key. Do not choose **No
verification**, which disables host-key protection. See the [Jenkins Git Client
plugin documentation](https://plugins.jenkins.io/git-client/#plugin-content-ssh-host-key-verification).

### Step 4: Create the PostgreSQL administrator credential

In the same **Global credentials** section, choose **Add Credentials** again:

| Field | Value |
|---|---|
| Kind | **Username with password** |
| Scope | **Global** |
| Username | `bluegreen` |
| Password | The `POSTGRES_PASSWORD` value from `.env` |
| ID | `bluegreen-postgres-admin` |

This is the database administrator credential Jenkins uses to connect to
PostgreSQL. It is separate from both the Jenkins sign-in account and the Git
credential. The ID must match the value used in `Jenkinsfile`.

### Step 5: Register the developer in Blue-Green

Open pgAdmin at <http://localhost:5050> and sign in with `admin@example.com`
and `PGADMIN_PASSWORD` from `.env`. Register the PostgreSQL server if needed,
using these connection values:

| Field | Value |
|---|---|
| Host name/address | `postgres` |
| Port | `5432` |
| Maintenance database | `bluegreen` |
| Username | `bluegreen` |
| Password | `POSTGRES_PASSWORD` from `.env` |

Open **Tools > Query Tool** on the `bluegreen` database and insert the
developer's manually chosen ID and exact workspace name:

```sql
INSERT INTO bluegreen_users (user_id, user_name)
VALUES (1001, 'WORKSPACE01');
```

Replace both example values with values you chose. The `user_name` must be
exactly the value you will enter as `WORKSPACE_NAME`; it becomes the workspace
role, database, and schema name. A developer can have only one active workspace.

### Step 6: Create the Pipeline job

In Jenkins, choose **New Item**, enter a job name such as `deploy-workspace`,
select **Pipeline**, and click **OK**. In the job's **Pipeline** section, set:

| Setting | Value |
|---|---|
| Definition | **Pipeline script from SCM** |
| SCM | **Git** |
| Repository URL | `git@github.com:vaamyan/blue_green_DB.git` |
| Credentials | Select the SSH key credential created in Step 3 (it may appear as `git`) |
| Branches to build | `*/main` |
| Script Path | `Jenkinsfile` |

Click **Save**. The **Branches to build** value selects the branch from which
Jenkins initially loads the `Jenkinsfile`. During the run, the Jenkinsfile
checks out the branch entered in the `BRANCH` build parameter for the SQL and
deployment files. These are two separate settings: to run everything from
`feature_01`, set **Branches to build** to `*/feature_01` in job configuration
and set `BRANCH` to `feature_01` when building. Setting only the build parameter
does not change the branch Jenkins used to load the Jenkinsfile.

### Step 7: Load the build parameters

The `Jenkinsfile` reads `BRANCH` and `WORKSPACE_NAME`, but does not declare
them. Configure both parameters in the Jenkins job:

1. Open the job and click **Configure**.
2. Under **General**, select **This project is parameterized**.
3. Click **Add Parameter** and select **String Parameter**.
4. Add the first parameter with this name and value:

| Parameter | What to enter |
|---|---|
| Name | `BRANCH` |
| Default Value | `main`, or leave it blank to require an entry for each build |
| Description | Git branch to deploy, such as `main` |

5. Add a second **String Parameter**:

| Setting | Value |
|---|---|
| Name | `WORKSPACE_NAME` |
| Default Value | Leave blank |
| Description | Exact `user_name` registered in `bluegreen_users` |

6. Click **Save**. The job page should now show **Build with Parameters**.

Do not add the parameters a second time in the `Jenkinsfile`; the job
configuration is their source. The names must match exactly, including
uppercase letters, because the Pipeline reads `params.BRANCH` and
`params.WORKSPACE_NAME`.

### Step 8: Run the workspace deployment

Click **Build with Parameters**. Enter the branch and exact registered
workspace name, then click **Build**. The stages check eligibility, create the
role/database/schema, load DDL, pause for fixture approval, load fixture data,
and register the developer in `ACTIVE_USERS`.

### Step 9: Approve the fixture load

At **Approve fixture data load**, Jenkins waits for a person to continue. Open
the paused build, review `database/deploy/dml/install_all_fixtures.sql` and its
included DML files from the selected branch, then click **Proceed** to continue
or **Abort** to stop the run. Fixture loading and registration happen only
after you click **Proceed**.

### Step 10: Check the result

When the build succeeds, the workspace role and database use the exact
`WORKSPACE_NAME`, and that user is present in `ACTIVE_USERS`. If the build
fails, Jenkins does not automatically delete a partially created role or
database. Inspect the PostgreSQL state before retrying.

The SQL file paths used by the deployment Pipeline are set directly in the
`Jenkinsfile` environment block. Update those values there when a SQL entry
point moves. If Git reports an SSH host-key verification error, resolve the
host-key verification configuration before retrying the job.

Use synthetic data only. Do not store real employer, customer, or personal
information in this lab.

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
