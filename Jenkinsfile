pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        BLUEGREEN_ADMIN_CREDENTIALS = credentials('bluegreen-postgres-admin')
        PGDATABASE = 'bluegreen'
        CMDPSQL = 'psql -X -w -v ON_ERROR_STOP=1'
        SQL_CHECK_WORKSPACE_STATUS = 'database/jenkins/check_workspace_status.sql'
        SQL_CREATE_WORKSPACE = 'database/jenkins/create_workspace.sql'
        SQL_INSTALL_ALL_OBJECTS = 'database/deploy/ddl/install_all_objects.sql'
        SQL_INSTALL_ALL_FIXTURES = 'database/deploy/dml/install_all_fixtures.sql'
        SQL_REGISTER_ACTIVE_USER = 'database/jenkins/register_active_user.sql'
    }

    stages {
        stage('Validate inputs and checkout') {
            steps {
                script {
                    if (!params.BRANCH?.trim() || !(params.BRANCH ==~ '[A-Za-z0-9._/-]+') || params.BRANCH.contains('..')) {
                        error('BRANCH is required and must be a simple Git branch name.')
                    }
                    if (!env.BLUEGREEN_DB_HOST?.trim()) {
                        error('BLUEGREEN_DB_HOST is not configured for the Jenkins container.')
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
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${params.BRANCH}"]],
                    userRemoteConfigs: scm.userRemoteConfigs
                ])
            }
        }

        stage('Check workspace status') {
            steps {
                script {
                    env.WORKSPACE_NAME = params.WORKSPACE_NAME
                }
                sh '$CMDPSQL -v "requested_user=$WORKSPACE_NAME" -d "$PGDATABASE" -f "$SQL_CHECK_WORKSPACE_STATUS"'
            }
        }

        stage('Create role, database, and schema') {
            steps {
                sh '$CMDPSQL -v "workspace=$WORKSPACE_NAME" -d postgres -f "$SQL_CREATE_WORKSPACE"'
            }
        }

        stage('Apply DDL in dependency order') {
            steps {
                sh '$CMDPSQL -v "workspace=$WORKSPACE_NAME" -d "$WORKSPACE_NAME" -f "$SQL_INSTALL_ALL_OBJECTS"'
            }
        }

        stage('Approve fixture data load') {
            steps {
                input message: "Review ${env.SQL_INSTALL_ALL_FIXTURES} and the DML files before loading data into ${env.WORKSPACE_NAME}.",
                      ok: 'Approve fixture data load'
            }
        }

        stage('Load fixture data') {
            steps {
                sh '$CMDPSQL --single-transaction -v "workspace=$WORKSPACE_NAME" -d "$WORKSPACE_NAME" -f "$SQL_INSTALL_ALL_FIXTURES"'
            }
        }

        stage('Register workspace in ACTIVE_USERS') {
            steps {
                sh '$CMDPSQL -v "requested_user=$WORKSPACE_NAME" -d "$PGDATABASE" -f "$SQL_REGISTER_ACTIVE_USER"'
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
