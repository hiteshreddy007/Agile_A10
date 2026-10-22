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
                    bat "docker build --no-cache -t ${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER} ."
                    bat "docker build --no-cache -t ${DOCKER_USER}/${IMAGE_NAME}:latest ."
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
                    bat(script: "docker stop ewaste-production", returnStatus: true)
                    bat(script: "docker rm -f ewaste-production", returnStatus: true)
                    
                    // Direct delivery to local system runtime layout on port 32080
                    bat "docker run -d --name ewaste-production -p 32080:80 ${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER}"
                    
                    echo "Evaluating deployment validation rules..."
                    bat "timeout /t 5 /nobreak"
                    
                    def manifestContent = readFile('deployment.yaml')
                    if (manifestContent.contains('/broken-endpoint')) {
                        error("Deployment Health Probe Failed: Simulated endpoint modification detected unreachable targets.")
                    }
                }
            }
        }
    }
    post {
        always {
            archiveArtifacts artifacts: 'index.html,deployment.yaml', fingerprint: true
        }
        failure {
            script {
                echo "Rollout failure intercepted. Triggering automated fallback to last known stable release..."
                bat(script: "docker stop ewaste-production", returnStatus: true)
                bat(script: "docker rm -f ewaste-production", returnStatus: true)
                bat "docker run -d --name ewaste-production -p 32080:80 ${DOCKER_USER}/${IMAGE_NAME}:latest"
                echo "Stable release successfully restored on port 32080."
            }
        }
    }
}
