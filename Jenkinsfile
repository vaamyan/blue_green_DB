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

        stage('Validate deployment manifests') {
            steps {
                sh './scripts/jenkins/validate_manifests.sh'
            }
        }

        stage('Check workspace eligibility') {
            steps {
                script {
                    env.WORKSPACE_ID = sh(
                        script: './scripts/jenkins/check_workspace_eligibility.sh "' + params.WORKSPACE_USER + '"',
                        returnStdout: true
                    ).trim()
                    if (!(env.WORKSPACE_ID ==~ /^[0-9]+$/)) {
                        error('The eligibility script did not return a valid user_id.')
                    }
                    env.WORKSPACE_NAME = "workspace_${env.WORKSPACE_ID}"
                    echo "Registry check passed. Workspace name: ${env.WORKSPACE_NAME}."
                }
            }
        }

        stage('Create role, database, and schema') {
            steps {
                sh './scripts/jenkins/provision_workspace.sh "$WORKSPACE_NAME"'
            }
        }

        stage('Apply DDL in dependency order') {
            steps {
                sh './scripts/jenkins/apply_workspace_ddl.sh "$WORKSPACE_NAME"'
            }
        }

        stage('Verify triggers and rules are inactive') {
            steps {
                sh './scripts/jenkins/verify_side_effects_disabled.sh "$WORKSPACE_NAME"'
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
                sh './scripts/jenkins/load_workspace_fixtures.sh "$WORKSPACE_NAME"'
            }
        }

        stage('Enable runtime objects and validate') {
            steps {
                sh './scripts/jenkins/activate_and_validate_workspace.sh "$WORKSPACE_NAME"'
            }
        }

        stage('Register workspace in ACTIVE_USERS') {
            steps {
                sh './scripts/jenkins/register_active_workspace.sh "$WORKSPACE_USER" "$WORKSPACE_ID"'
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
