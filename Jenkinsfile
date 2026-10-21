import groovy.util.XmlSlurper

pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    parameters {
        string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch to deploy.')
        string(name: 'WORKSPACE_NAME', defaultValue: '', description: 'Exact registered user_name from BLUEGREEN_USERS; also used as the role, database, and schema name.')
    }

    environment {
        BLUEGREEN_ADMIN_CREDENTIALS = credentials('bluegreen-postgres-admin')
        PGDATABASE = 'bluegreen'
        PSQL = 'psql -X -w -v ON_ERROR_STOP=1'
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

        stage('Load deployment configuration') {
            steps {
                script {
                    def deployment = new XmlSlurper().parseText(readFile('deployment.xml'))
                    env.SQL_CHECK_WORKSPACE_STATUS = deployment.CHECKWORKSPACESTATUS.text()
                    env.SQL_CREATE_WORKSPACE = deployment.CREATEWORKSPACE.text()
                    env.SQL_INSTALL_ALL_OBJECTS = deployment.INSTALLALLOBJECTS.text()
                    env.SQL_INSTALL_ALL_FIXTURES = deployment.INSTALLALLFIXTURES.text()
                    env.SQL_REGISTER_ACTIVE_USER = deployment.REGISTERACTIVEUSER.text()
                }
            }
        }

        stage('Check workspace status') {
            steps {
                script {
                    env.WORKSPACE_NAME = params.WORKSPACE_NAME
                }
                sh '$PSQL -v "requested_user=$WORKSPACE_NAME" -d "$PGDATABASE" -f "$SQL_CHECK_WORKSPACE_STATUS"'
            }
        }

        stage('Create role, database, and schema') {
            steps {
                sh '$PSQL -v "workspace=$WORKSPACE_NAME" -d postgres -f "$SQL_CREATE_WORKSPACE"'
            }
        }

        stage('Apply DDL in dependency order') {
            steps {
                sh '$PSQL -v "workspace=$WORKSPACE_NAME" -d "$WORKSPACE_NAME" -f "$SQL_INSTALL_ALL_OBJECTS"'
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
                sh '$PSQL --single-transaction -v "workspace=$WORKSPACE_NAME" -d "$WORKSPACE_NAME" -f "$SQL_INSTALL_ALL_FIXTURES"'
            }
        }

        stage('Register workspace in ACTIVE_USERS') {
            steps {
                sh '$PSQL -v "requested_user=$WORKSPACE_NAME" -d "$PGDATABASE" -f "$SQL_REGISTER_ACTIVE_USER"'
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
