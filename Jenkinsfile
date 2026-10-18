pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    parameters {
        string(name: 'BRANCH', defaultValue: '', description: 'Git branch to deploy.')
        string(name: 'WORKSPACE_USER', defaultValue: '', description: 'Registered username from BLUEGREEN_USERS.')
    }

    environment {
        BLUEGREEN_ADMIN_CREDENTIALS = credentials('bluegreen-postgres-admin')
        PGDATABASE = 'bluegreen'
    }

    stages {
        stage('Validate inputs and checkout') {
            steps {
                script {
                    if (!params.BRANCH?.trim() || !(params.BRANCH ==~ '[A-Za-z0-9._/-]+') || params.BRANCH.contains('..')) {
                        error('BRANCH is required and must be a simple Git branch name.')
                    }
                    if (!params.WORKSPACE_USER?.trim() || !(params.WORKSPACE_USER ==~ /^[A-Za-z0-9._-]+$/)) {
                        error('WORKSPACE_USER is required and may contain only letters, digits, dots, underscores, and hyphens.')
                    }
                    if (!env.BLUEGREEN_DB_HOST?.trim()) {
                        error('Configure BLUEGREEN_DB_HOST in the Jenkins agent or global environment.')
                    }
                    env.PGHOST = env.BLUEGREEN_DB_HOST.trim()
                    env.PGPORT = env.BLUEGREEN_DB_PORT?.trim() ?: '5432'
                    if (!(env.PGPORT ==~ /[0-9]{1,5}/) || env.PGPORT.toInteger() < 1 || env.PGPORT.toInteger() > 65535) {
                        error('BLUEGREEN_DB_PORT must be a TCP port between 1 and 65535.')
                    }
                    env.PGUSER = env.BLUEGREEN_ADMIN_CREDENTIALS_USR
                    env.PGPASSWORD = env.BLUEGREEN_ADMIN_CREDENTIALS_PSW
                    if (env.PGUSER != 'bluegreen') {
                        error('The bluegreen-postgres-admin Jenkins credential must use the bluegreen database administrator role.')
                    }
                }
                sh 'command -v psql >/dev/null || { echo "psql is required on the Jenkins agent." >&2; exit 1; }'
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${params.BRANCH}"]],
                    userRemoteConfigs: scm.userRemoteConfigs
                ])
            }
        }

        stage('Validate deployment manifests') {
            steps {
                script {
                    def ddlFiles = readFile('database/deploy/ddl/manifest.txt')
                        .readLines().collect { it.trim() }
                        .findAll { it && !it.startsWith('#') }
                    def dmlFiles = readFile('database/deploy/dml/manifest.txt')
                        .readLines().collect { it.trim() }
                        .findAll { it && !it.startsWith('#') }
                    if (!ddlFiles || !dmlFiles) error('Both deployment manifests must contain SQL files.')
                    ddlFiles.each { file ->
                        if (!(file ==~ /^[a-z_]+\/[a-z_0-9]+\.sql$/) || !fileExists("database/deploy/ddl/${file}")) {
                            error("Invalid or missing DDL manifest entry: ${file}")
                        }
                    }
                    dmlFiles.each { file ->
                        if (!(file ==~ /^[a-z_0-9]+\.sql$/) || !fileExists("database/deploy/dml/${file}")) {
                            error("Invalid or missing DML manifest entry: ${file}")
                        }
                    }
                    echo "Validated ${ddlFiles.size()} DDL files and ${dmlFiles.size()} DML files."
                }
            }
        }

        stage('Check workspace eligibility') {
            steps {
                script {
                    def userId = sh(
                        script: '''psql -X -w -v ON_ERROR_STOP=1 -Atq \
                          -v "requested_user=$WORKSPACE_USER" \
                          -c "SELECT user_id FROM public.bluegreen_users WHERE user_name = :'requested_user';"''',
                        returnStdout: true
                    ).trim()
                    if (!(userId ==~ /^[0-9]+$/)) {
                        error("User '${params.WORKSPACE_USER}' is not registered exactly once in BLUEGREEN_USERS.")
                    }
                    env.WORKSPACE_ID = userId
                    env.WORKSPACE_NAME = "workspace_${userId}"

                    def active = sh(
                        script: '''psql -X -w -v ON_ERROR_STOP=1 -Atq \
                          -v "requested_user=$WORKSPACE_USER" -v "requested_id=$WORKSPACE_ID" \
                          -c "SELECT EXISTS (SELECT 1 FROM public.active_users WHERE user_id = :'requested_id'::bigint OR user_name = :'requested_user');"''',
                        returnStdout: true
                    ).trim()
                    if (active != 'f') {
                        error("User '${params.WORKSPACE_USER}' already has an active workspace.")
                    }

                    def roleExists = sh(
                        script: '''psql -X -w -v ON_ERROR_STOP=1 -Atq -d postgres \
                          -v "workspace=$WORKSPACE_NAME" \
                          -c "SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'workspace');"''',
                        returnStdout: true
                    ).trim()
                    def databaseExists = sh(
                        script: '''psql -X -w -v ON_ERROR_STOP=1 -Atq -d postgres \
                          -v "workspace=$WORKSPACE_NAME" \
                          -c "SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'workspace');"''',
                        returnStdout: true
                    ).trim()
                    if (roleExists != 'f' || databaseExists != 'f') {
                        error("${env.WORKSPACE_NAME} already exists or is partially provisioned. Inspect it before retrying.")
                    }
                    echo "Registry check passed. Workspace name: ${env.WORKSPACE_NAME}."
                }
            }
        }

        stage('Create workspace role, database, and schema') {
            steps {
                sh '''
                    psql -X -w -v ON_ERROR_STOP=1 -d postgres \
                      -c "CREATE ROLE $WORKSPACE_NAME LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;"
                    psql -X -w -v ON_ERROR_STOP=1 -d postgres \
                      -c "CREATE DATABASE $WORKSPACE_NAME OWNER $WORKSPACE_NAME;"
                    psql -X -w -v ON_ERROR_STOP=1 -d postgres \
                      -c "REVOKE CONNECT ON DATABASE postgres FROM $WORKSPACE_NAME;"
                    psql -X -w -v ON_ERROR_STOP=1 -d postgres \
                      -c "REVOKE CONNECT ON DATABASE template1 FROM $WORKSPACE_NAME;"
                    psql -X -w -v ON_ERROR_STOP=1 -d postgres \
                      -c "REVOKE CONNECT ON DATABASE bluegreen FROM $WORKSPACE_NAME;"
                    psql -X -w -v ON_ERROR_STOP=1 -d postgres \
                      -c "REVOKE CONNECT ON DATABASE $WORKSPACE_NAME FROM PUBLIC;"
                    psql -X -w -v ON_ERROR_STOP=1 -d postgres \
                      -c "GRANT CONNECT ON DATABASE $WORKSPACE_NAME TO $WORKSPACE_NAME;"
                    psql -X -w -v ON_ERROR_STOP=1 -d "$WORKSPACE_NAME" \
                      -c "CREATE SCHEMA $WORKSPACE_NAME AUTHORIZATION $WORKSPACE_NAME;" \
                      -c "REVOKE ALL ON SCHEMA public FROM PUBLIC;"
                '''
            }
        }

        stage('Apply DDL in dependency order') {
            steps {
                script {
                    def ddlFiles = readFile('database/deploy/ddl/manifest.txt')
                        .readLines().collect { it.trim() }
                        .findAll { it && !it.startsWith('#') }
                    if (!ddlFiles) error('The DDL manifest is empty.')
                    ddlFiles.each { file ->
                        if (!(file ==~ /^[a-z_]+\/[a-z_0-9]+\.sql$/)) {
                            error("Invalid DDL manifest entry: ${file}")
                        }
                        echo "Applying database/deploy/ddl/${file}"
                        sh """psql -X -w -v ON_ERROR_STOP=1 -d \"\$WORKSPACE_NAME\" \\
                          -v workspace=\"\$WORKSPACE_NAME\" \\
                          -c \"SET ROLE \$WORKSPACE_NAME\" \\
                          -f 'database/deploy/ddl/${file}'"""
                        if (file == 'trigger/trigger_1.sql') {
                            sh '''psql -X -w -v ON_ERROR_STOP=1 -d "$WORKSPACE_NAME" \
                              -c "SET ROLE $WORKSPACE_NAME" \
                              -c "ALTER TABLE $WORKSPACE_NAME.table_1 DISABLE TRIGGER trigger_1;"'''
                        }
                        if (file == 'rule/rule_1.sql') {
                            sh '''psql -X -w -v ON_ERROR_STOP=1 -d "$WORKSPACE_NAME" \
                              -c "SET ROLE $WORKSPACE_NAME" \
                              -c "ALTER TABLE $WORKSPACE_NAME.view_2 DISABLE RULE rule_1;"'''
                        }
                    }
                    // PostgreSQL has no inactive sequence state. Sequences advance only when nextval/setval is called.
                    // The trigger and rule are disabled immediately after creation, before the fixture load.
                }
            }
        }

        stage('Verify triggers and rules are inactive') {
            steps {
                script {
                    def triggerState = sh(
                        script: '''psql -X -w -v ON_ERROR_STOP=1 -Atq -d "$WORKSPACE_NAME" \
                          -c "SELECT tgenabled FROM pg_trigger WHERE tgrelid = '$WORKSPACE_NAME.table_1'::regclass AND tgname = 'trigger_1';"''',
                        returnStdout: true
                    ).trim()
                    def ruleState = sh(
                        script: '''psql -X -w -v ON_ERROR_STOP=1 -Atq -d "$WORKSPACE_NAME" \
                          -c "SELECT ev_enabled FROM pg_rewrite WHERE ev_class = '$WORKSPACE_NAME.view_2'::regclass AND rulename = 'rule_1';"''',
                        returnStdout: true
                    ).trim()
                    if (triggerState != 'D' || ruleState != 'D') {
                        error('The sample trigger and rule must both be disabled before fixture data is applied.')
                    }
                }
            }
        }

        stage('Approve fixture data load') {
            steps {
                input message: "Review database/deploy/dml/manifest.txt and its SQL files before loading data into ${env.WORKSPACE_NAME}.",
                      ok: 'Approve fixture data load'
            }
        }

        stage('Load fixture data') {
            steps {
                script {
                    def dmlFiles = readFile('database/deploy/dml/manifest.txt')
                        .readLines().collect { it.trim() }
                        .findAll { it && !it.startsWith('#') }
                    if (!dmlFiles) error('The DML manifest is empty.')
                    dmlFiles.each { file ->
                        if (!(file ==~ /^[a-z_0-9]+\.sql$/)) {
                            error("Invalid DML manifest entry: ${file}")
                        }
                        echo "Queued database/deploy/dml/${file}"
                    }
                    def dmlArguments = dmlFiles.collect { "-f 'database/deploy/dml/${it}'" }.join(' ')
                    sh """psql -X -w --single-transaction -v ON_ERROR_STOP=1 -d \"\$WORKSPACE_NAME\" \\
                      -v workspace=\"\$WORKSPACE_NAME\" \\
                      -c \"SET ROLE \$WORKSPACE_NAME\" ${dmlArguments}"""
                }
            }
        }

        stage('Enable runtime rules and triggers, then validate') {
            steps {
                sh '''
                    psql -X -w -v ON_ERROR_STOP=1 -d "$WORKSPACE_NAME" \
                      -c "SET ROLE $WORKSPACE_NAME" \
                      -c "ALTER TABLE $WORKSPACE_NAME.table_1 ENABLE TRIGGER trigger_1;" \
                      -c "ALTER TABLE $WORKSPACE_NAME.view_2 ENABLE RULE rule_1;"
                    table_1_rows=$(psql -X -w -v ON_ERROR_STOP=1 -d "$WORKSPACE_NAME" -Atq -c "SELECT count(*) FROM $WORKSPACE_NAME.table_1;")
                    table_2_rows=$(psql -X -w -v ON_ERROR_STOP=1 -d "$WORKSPACE_NAME" -Atq -c "SELECT count(*) FROM $WORKSPACE_NAME.table_2;")
                    table_4_rows=$(psql -X -w -v ON_ERROR_STOP=1 -d "$WORKSPACE_NAME" -Atq -c "SELECT count(*) FROM $WORKSPACE_NAME.table_4;")
                    table_5_rows=$(psql -X -w -v ON_ERROR_STOP=1 -d "$WORKSPACE_NAME" -Atq -c "SELECT count(*) FROM $WORKSPACE_NAME.table_5;")
                    trigger_state=$(psql -X -w -v ON_ERROR_STOP=1 -d "$WORKSPACE_NAME" -Atq -c "SELECT tgenabled FROM pg_trigger WHERE tgrelid = '$WORKSPACE_NAME.table_1'::regclass AND tgname = 'trigger_1';")
                    rule_state=$(psql -X -w -v ON_ERROR_STOP=1 -d "$WORKSPACE_NAME" -Atq -c "SELECT ev_enabled FROM pg_rewrite WHERE ev_class = '$WORKSPACE_NAME.view_2'::regclass AND rulename = 'rule_1';")
                    materialized_view_populated=$(psql -X -w -v ON_ERROR_STOP=1 -d "$WORKSPACE_NAME" -Atq -c "SELECT relispopulated FROM pg_class WHERE oid = '$WORKSPACE_NAME.materialized_view_1'::regclass;")
                    [[ "$table_1_rows" -ge 5 && "$table_2_rows" -ge 3 && "$table_4_rows" -ge 2 && "$table_5_rows" -ge 4 ]] || {
                      echo "Fixture row-count validation failed." >&2; exit 1;
                    }
                    [[ "$trigger_state" == O && "$rule_state" == O && "$materialized_view_populated" == t ]] || {
                      echo "Trigger, rule, or materialized-view validation failed." >&2; exit 1;
                    }
                    printf 'Fixture validation passed: table_1=%s table_2=%s table_4=%s table_5=%s.\\n' \
                      "$table_1_rows" "$table_2_rows" "$table_4_rows" "$table_5_rows"
                '''
            }
        }

        stage('Register workspace in ACTIVE_USERS') {
            steps {
                script {
                    def registeredId = sh(script: '''psql -X -w -v ON_ERROR_STOP=1 -Atq \
                  -v "requested_user=$WORKSPACE_USER" -v "requested_id=$WORKSPACE_ID" \
                  -c "INSERT INTO public.active_users (user_id, user_name) \
                      SELECT user_id, user_name FROM public.bluegreen_users \
                      WHERE user_id = :'requested_id'::bigint \
                        AND user_name = :'requested_user' \
                        AND NOT EXISTS (SELECT 1 FROM public.active_users \
                                        WHERE user_id = :'requested_id'::bigint OR user_name = :'requested_user') \
                      RETURNING user_id;"''', returnStdout: true).trim()
                    if (registeredId != env.WORKSPACE_ID) {
                        error('The workspace was not registered in ACTIVE_USERS. Check whether the registry changed during this build.')
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Workspace ${env.WORKSPACE_NAME} was deployed and registered as active."
        }
        unsuccessful {
            echo "Provisioning did not complete. No automatic database deletion was attempted; inspect ${env.WORKSPACE_NAME} and ACTIVE_USERS before retrying."
        }
    }
}
