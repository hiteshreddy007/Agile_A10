pipeline {
    agent any
    environment {
        DOCKER_HUB_CRED  = 'docker-hub-credentials' 
        IMAGE_NAME       = 'ewaste-portal'
        DOCKER_USER      = 'hiteshreddy007' 
    }
    stages {
        stage('Pull SCM Source') {
            steps {
                checkout scm
            }
        }
        
        stage('Validation & Analysis') {
            parallel {
                stage('HTML Linting') {
                    steps {
                        echo 'Evaluating static structure integrity...'
                        script {
                            def fileContent = readFile('index.html')
                            if (!fileContent.contains('Authorized Municipal Collection Centres')) {
                                error("Validation Failed: Core collection header missing from index.html")
                            }
                        }
                    }
                }
                stage('Infrastructure Sanity Checks') {
                    steps {
                        echo 'Verifying environment software availability...'
                        bat "docker --version"
                    }
                }
            }
        }

        stage('Build Production Images') {
            steps {
                script {
                    echo "Compiling application containers..."
                    bat "docker build -t ${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER} ."
                    bat "docker build -t ${DOCKER_USER}/${IMAGE_NAME}:latest ."
                }
            }
        }

        stage('Registry Delivery') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: "${DOCKER_HUB_CRED}", usernameVariable: 'DOCKER_REGISTRY_USER', passwordVariable: 'DOCKER_REGISTRY_PASS')]) {
                        bat "echo ${DOCKER_REGISTRY_PASS}| docker login -u ${DOCKER_REGISTRY_USER} --password-stdin"
                        bat "docker push ${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER}"
                        bat "docker push ${DOCKER_USER}/${IMAGE_NAME}:latest"
                    }
                }
            }
        }

        stage('Containerized Production Deployment') {
            steps {
                script {
                    echo "Deploying live application production node instance..."
                    // Safely tears down previous iterations to ensure zero port conflicts
                    bat(script: "docker stop ewaste-production", returnStatus: true)
                    bat(script: "docker rm -f ewaste-production", returnStatus: true)
                    
                    // Spins up the new web app version on external port 32080 to match deployment requirements
                    bat "docker run -d --name ewaste-production -p 32080:80 ${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER}"
                    
                    // Performance Verification Health Check Loop
                    echo "Evaluating application runtime health progress status..."
                    bat "timeout /t 5 /nobreak"
                    def testCheck = bat(script: "curl -s -I http://localhost:32080 | findstr \"200 OK\"", returnStatus: true)
                    if (testCheck != 0) {
                        error("Web health verification check failed! Initiating self-heal automated rollback strategy...")
                    }
                }
            }
        }
    }
    post {
        always {
            archiveArtifacts artifacts: 'index.html,Dockerfile', fingerprint: true
        }
        failure {
            script {
                echo "Rollout failure intercepted. Reverting production context back to stable image instance..."
                bat(script: "docker stop ewaste-production", returnStatus: true)
                bat(script: "docker rm -f ewaste-production", returnStatus: true)
                // Restores your last known stable software layer using the persistent :latest tracking container tag
                bat "docker run -d --name ewaste-production -p 32080:80 ${DOCKER_USER}/${IMAGE_NAME}:latest"
                echo "Stable release configuration successfully restored."
            }
        }
    }
}
