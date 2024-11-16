pipeline {
    agent any
    
    environment {
        GITHUB_TOKEN = credentials('github-token')
        PYTHON_VERSION = '3.9'
        APP_DIR = '.'
    }
    
    tools {
        python3 'Python-3.9'
    }
    
    stages {
        stage('Setup') {
            steps {
                sh '''
                    python3 -m pip install --upgrade pip
                    python3 -m pip install -r requirements.txt
                    python3 -m pip install safety bandit owasp-dependency-check-util coverage pytest pytest-cov
                    python3 -m pip install sqlmap-python   # For DAST testing
                '''
            }
        }

        // SCA
        stage('SCA - Safety Check') {
            steps {
                sh 'safety check -r requirements.txt --json > safety-report.json'
                recordIssues(tools: [pyLint(pattern: 'safety-report.json')])
            }
        }

        // SAST
        stage('SAST - Bandit') {
            steps {
                sh '''
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

        // Alternative IAST using Coverage and Dynamic Analysis
        stage('IAST - Coverage & Dynamic Analysis') {
            steps {
                script {
                    // Start application with coverage
                    sh '''
                        coverage run -m pytest tests/ --junitxml=test-results.xml
                        coverage report -m > coverage-report.txt
                        coverage html -d coverage-html
                    '''
                    
                    // Run basic security tests with coverage
                    sh '''
                        # Start application in background with coverage
                        coverage run app.py &
                        APP_PID=$!
                        
                        # Wait for app to start
                        sleep 10
                        
                        # Run basic security tests
                        python -c '
import requests
import urllib.parse

def test_basic_security():
    # Test for SQL Injection
    urls = [
        "http://localhost:8000/search?q=1%27%20OR%20%271%27=%271",
        "http://localhost:8000/user?id=1%20OR%201=1",
    ]
    
    for url in urls:
        response = requests.get(url)
        if response.status_code == 200 and "error" not in response.text.lower():
            print(f"Potential SQL Injection vulnerability found at: {url}")

    # Test for XSS
    xss_payload = "<script>alert(1)</script>"
    response = requests.get(f"http://localhost:8000/search?q={urllib.parse.quote(xss_payload)}")
    if xss_payload in response.text:
        print(f"Potential XSS vulnerability found")

test_basic_security()
'
                        
                        # Kill the application
                        kill $APP_PID
                        
                        # Generate coverage report
                        coverage report -m > coverage-report.txt
                        coverage html -d coverage-html
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
        }

        // DAST
        stage('DAST - OWASP ZAP') {
            steps {
                script {
                    // Start your application
                    sh 'python app.py &'
                    sleep(time: 30, unit: 'SECONDS')
                    
                    // Run ZAP scan
                    sh '''
                        docker pull owasp/zap2docker-stable
                        docker run -t owasp/zap2docker-stable zap-baseline.py \
                            -t http://host.docker.internal:8000 \
                            -r zap-report.html
                    '''
                    
                    // Additional SQLMap scan
                    sh '''
                        sqlmap -u "http://localhost:8000/?id=1" --batch --random-agent \
                            --level 1 --risk 1 --output-dir=sqlmap-results
                    '''
                    
                    // Kill the application
                    sh 'pkill -f "python app.py"'
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
                
                // Archive SQLMap results
                archiveArtifacts artifacts: 'sqlmap-results/**/*', fingerprint: true
            }
        }

        // RASP
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
            // Archive all security reports
            archiveArtifacts artifacts: '''
                **/safety-report.json,
                **/bandit-report.json,
                **/bandit-report.html,
                **/codeql-results.sarif,
                **/dependency-check-report.*,
                **/zap-report.html,
                **/coverage-report.txt,
                **/coverage-html/**,
                **/test-results.xml,
                **/sqlmap-results/**
            ''', fingerprint: true
            
            // Publish test results
            junit 'test-results.xml'
            
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
