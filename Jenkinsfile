pipeline {
    agent any
    
    environment {
        GITHUB_TOKEN = credentials('github-token')
        PYTHON_VERSION = '3.9'
        APP_DIR = '.'
    }
    
    tools {
        python 'Python-3.9'
    }
    
    stages {
        stage('Setup') {
            steps {
                sh '''
                    python -m pip install --upgrade pip
                    python -m pip install -r requirements.txt
                    python -m pip install safety bandit owasp-dependency-check-util
                '''
            }
        }

        // Software Composition Analysis (SCA)
        stage('SCA - Safety Check') {
            steps {
                sh 'safety check -r requirements.txt --json > safety-report.json'
                recordIssues(tools: [pyLint(pattern: 'safety-report.json')])
            }
        }

        // Static Application Security Testing (SAST)
        stage('SAST - Bandit') {
            steps {
                sh 'bandit -r . -f json -o bandit-report.json'
                recordIssues(tools: [pyLint(pattern: 'bandit-report.json')])
            }
        }

        // GitHub Advanced Security
        stage('GitHub Advanced Security') {
            steps {
                // CodeQL Analysis
                sh '''
                    curl -LO https://github.com/github/codeql-action/releases/latest/download/codeql-bundle.tar.gz
                    tar xzf codeql-bundle.tar.gz
                    ./codeql/codeql database create codeql-db --language=python
                    ./codeql/codeql database analyze codeql-db --format=sarif-latest --output=codeql-results.sarif
                '''
                
                // Dependency Review
                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    sh '''
                        curl -H "Authorization: token ${GITHUB_TOKEN}" \
                             -H "Accept: application/vnd.github.v3+json" \
                             "https://api.github.com/repos/owner/repo/dependency-graph/snapshots" \
                             -d @- << EOF
                        {
                            "version": 1,
                            "ref": "${GIT_COMMIT}",
                            "detector": {
                                "name": "jenkins",
                                "version": "1.0.0"
                            },
                            "manifests": {
                                "requirements.txt": {
                                    "name": "requirements.txt",
                                    "file": {
                                        "source_location": "requirements.txt"
                                    },
                                    "resolved": {}
                                }
                            }
                        }
                        EOF
                    '''
                }
            }
        }

        // OWASP Dependency Check
        stage('OWASP Dependency Check') {
            steps {
                dependencyCheck(
                    additionalArguments: '--scan . --format XML',
                    odcInstallation: 'OWASP-Dependency-Check'
                )
                dependencyCheckPublisher pattern: 'dependency-check-report.xml'
            }
        }

        // Dynamic Application Security Testing (DAST)
        stage('DAST - OWASP ZAP') {
            steps {
                script {
                    // Start your application (adjust as needed)
                    sh 'python app.py &'
                    sleep(time: 30, unit: 'SECONDS')  // Wait for app to start
                    
                    // Run ZAP scan
                    sh '''
                        docker pull owasp/zap2docker-stable
                        docker run -t owasp/zap2docker-stable zap-baseline.py \
                            -t http://host.docker.internal:8000 \
                            -r zap-report.html
                    '''
                    
                    // Kill the application
                    sh 'pkill -f "python app.py"'
                }
                publishHTML([
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: '.',
                    reportFiles: 'zap-report.html',
                    reportName: 'ZAP Security Report'
                ])
            }
        }

        // Interactive Application Security Testing (IAST)
        stage('IAST - Contrast Security') {
            environment {
                CONTRAST_API_KEY = credentials('contrast-api-key')
                CONTRAST_URL = credentials('contrast-url')
                CONTRAST_AGENT_PATH = '/opt/contrast/contrast-agent.jar'
            }
            steps {
                sh '''
                    # Download Contrast Security Agent
                    curl -L -o contrast-agent.jar ${CONTRAST_URL}/api/v1/agents/default/python \
                        -H "Authorization: ${CONTRAST_API_KEY}"
                    
                    # Run application with Contrast agent
                    CONTRAST_CONFIG_PATH=/path/to/contrast_security.yaml \
                    PYTHONPATH=${CONTRAST_AGENT_PATH} \
                    python app.py
                '''
            }
        }

        // Runtime Application Self-Protection (RASP)
        stage('RASP - Configure') {
            steps {
                sh '''
                    # Install and configure OpenRASP
                    pip install openrasp-python
                    rasp-cli install -a your-app-id -k your-rasp-key
                '''
            }
        }
    }

    post {
        always {
            // Archive security reports
            archiveArtifacts artifacts: '**/safety-report.json, **/bandit-report.json, **/codeql-results.sarif, **/dependency-check-report.xml, **/zap-report.html', fingerprint: true
            
            // Clean up
            cleanWs()
        }
        failure {
            emailext (
                subject: "Security Scan Failed: ${currentBuild.fullDisplayName}",
                body: "Security scanning failed. Please check the Jenkins console output for details.",
                recipientProviders: [[$class: 'DevelopersRecipientProvider']]
            )
        }
    }
}
