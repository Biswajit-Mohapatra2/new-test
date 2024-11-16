pipeline {
    agent any
    
    environment {
        GITHUB_TOKEN = credentials('github-token')
        PYTHON_CMD = 'python3'  // or 'python' depending on your system
        APP_DIR = '.'
    }
    
    stages {
        stage('Setup Python Environment') {
            steps {
                script {
                    // Create and activate virtual environment
                    sh '''
                        # Create virtual environment
                        ${PYTHON_CMD} -m venv venv
                        
                        # Activate virtual environment
                        . venv/bin/activate
                        
                        # Upgrade pip and install requirements
                        pip install --upgrade pip
                        pip install -r requirements.txt
                        
                        # Install security tools
                        pip install safety bandit pytest pytest-cov coverage sqlmap-python
                    '''
                }
            }
        }

        // SCA
        stage('SCA - Safety Check') {
            steps {
                sh '''
                    . venv/bin/activate
                    safety check -r requirements.txt --json > safety-report.json
                '''
                recordIssues(tools: [pyLint(pattern: 'safety-report.json')])
            }
        }

        // SAST
        stage('SAST - Bandit') {
            steps {
                sh '''
                    . venv/bin/activate
                    bandit -r . -f json -o bandit-report.json
                    bandit -r . -f html -o bandit-report.html
                '''
                recordIssues(tools: [pyLint(pattern: 'bandit-report.json')])
                publishHTML([
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: '.',
                    reportFiles: 'bandit-report.html',
                    reportName: 'Bandit Security Report'
                ])
            }
        }

        // OWASP Dependency Check
        stage('OWASP Dependency Check') {
            steps {
                dependencyCheck(
                    additionalArguments: '--scan . --format XML --format HTML',
                    odcInstallation: 'OWASP-Dependency-Check'
                )
                dependencyCheckPublisher pattern: 'dependency-check-report.xml'
                publishHTML([
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: '.',
                    reportFiles: 'dependency-check-report.html',
                    reportName: 'Dependency Check Report'
                ])
            }
        }

        // Coverage and Security Testing
        stage('Coverage & Security Testing') {
            steps {
                sh '''
                    . venv/bin/activate
                    
                    # Run tests with coverage
                    coverage run -m pytest tests/ --junitxml=test-results.xml || true
                    coverage report -m > coverage-report.txt
                    coverage html -d coverage-html
                    
                    # Start application with coverage in background
                    coverage run app.py &
                    APP_PID=$!
                    
                    # Wait for app to start
                    sleep 10
                    
                    # Run security tests
                    python security_test.py || true
                    
                    # Kill the application
                    kill $APP_PID || true
                '''
                
                // Publish coverage report
                publishHTML([
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'coverage-html',
                    reportFiles: 'index.html',
                    reportName: 'Coverage Report'
                ])
            }
        }

        // DAST
        stage('DAST - OWASP ZAP') {
            steps {
                script {
                    // Start application in background
                    sh '''
                        . venv/bin/activate
                        python app.py &
                        APP_PID=$!
                        sleep 10
                    '''
                    
                    // Run ZAP scan
                    sh '''
                        docker pull owasp/zap2docker-stable
                        docker run -t owasp/zap2docker-stable zap-baseline.py \
                            -t http://host.docker.internal:8000 \
                            -r zap-report.html || true
                            
                        # Run SQLMap scan
                        sqlmap -u "http://localhost:8000/?id=1" --batch --random-agent \
                            --level 1 --risk 1 --output-dir=sqlmap-results || true
                    '''
                    
                    // Kill the application
                    sh 'pkill -f "python app.py" || true'
                }
                
                // Publish ZAP report
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
    }

    post {
        always {
            // Archive reports
            archiveArtifacts artifacts: '''
                **/safety-report.json,
                **/bandit-report.json,
                **/bandit-report.html,
                **/dependency-check-report.*,
                **/zap-report.html,
                **/coverage-report.txt,
                **/coverage-html/**,
                **/test-results.xml,
                **/sqlmap-results/**
            ''', fingerprint: true
            
            // Publish test results
            junit allowEmptyResults: true, testResults: 'test-results.xml'
            
            // Cleanup
            sh '''
                pkill -f "python app.py" || true
                rm -rf venv
            '''
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
