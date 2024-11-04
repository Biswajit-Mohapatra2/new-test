pipeline {
    agent any
    
    environment {
        EC2_USER = 'ubuntu'
        EC2_HOST = '3.111.41.22'
        APP_PATH = '/home/ubuntu/app4'
        GIT_REPO = 'https://github.com/Biswajit-Mohapatra2/new-test.git'
        PPK_KEY = 'C:\\Users\\BiswajitMohapatra\\Downloads\\new2jenkins.ppk'
    }
    
    stages {
        stage('Clone Repository') {
            steps {
                cleanWs()
                git url: GIT_REPO
            }
        }
        
        stage('Deploy to EC2') {
            steps {
                script {
                    // First, add host key to PuTTY's cache (only needs to be done once)
                    bat """
                        echo y | plink -i "${PPK_KEY}" ${EC2_USER}@${EC2_HOST} "exit"
                    """
                    
                    // Now proceed with deployment
                    bat """
                        REM Create directory on EC2
                        plink -i "${PPK_KEY}" -batch ${EC2_USER}@${EC2_HOST} "mkdir -p ${APP_PATH}"
                        
                        REM Copy files directly to EC2
                        pscp -i "${PPK_KEY}" -r .\\* ${EC2_USER}@${EC2_HOST}:${APP_PATH}/
                        
                        REM Install dependencies and run application
                        plink -i "${PPK_KEY}" -batch ${EC2_USER}@${EC2_HOST} "cd ${APP_PATH} && pip install -r requirements.txt && pkill -f 'python app.py' || true && nohup python app.py > app.log 2>&1 &"
                    """
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}
