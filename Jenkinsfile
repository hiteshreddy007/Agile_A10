pipeline {
    agent any
    environment {
        DOCKER_HUB_CRED  = 'docker-hub-credentials' 
        KUBE_CONFIG_CRED = 'kubeconfig-credentials'  
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
                        echo 'Verifying Docker and Kubernetes configurations...'
                        script {
                            if (isUnix()) {
                                sh "docker --version"
                                sh "kubectl version --client"
                            } else {
                                bat "docker --version"
                                bat "kubectl version --client"
                            }
                        }
                    }
                }
            }
        }

        stage('Build & Local Verification') {
            steps {
                script {
                    if (isUnix()) {
                        sh "docker build -t ${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER} ."
                        sh "docker build -t ${DOCKER_USER}/${IMAGE_NAME}:latest ."
                        sh "docker run -d --name test_run -p 8085:80 ${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER}"
                        sh "sleep 5"
                        sh "docker rm -f test_run"
                    } else {
                        // Using native Groovy interpolation ("${}") instead of % variables to prevent Windows exit 125 crashes
                        bat "docker build -t ${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER} ."
                        bat "docker build -t ${DOCKER_USER}/${IMAGE_NAME}:latest ."
                        bat "docker run -d --name test_run -p 8085:80 ${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER}"
                        bat "timeout /t 5 /nobreak"
                        bat "docker rm -f test_run"
                    }
                }
            }
        }

        stage('Registry Delivery') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: "${DOCKER_HUB_CRED}", usernameVariable: 'DOCKER_REGISTRY_USER', passwordVariable: 'DOCKER_REGISTRY_PASS')]) {
                        if (isUnix()) {
                            sh "echo '${DOCKER_REGISTRY_PASS}' | docker login -u '${DOCKER_REGISTRY_USER}' --password-stdin"
                            sh "docker push ${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER}"
                            sh "docker push ${DOCKER_USER}/${IMAGE_NAME}:latest"
                        } else {
                            // Fixed Windows inline evaluation stream variables
                            bat "echo ${DOCKER_REGISTRY_PASS}| docker login -u ${DOCKER_REGISTRY_USER} --password-stdin"
                            bat "docker push ${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER}"
                            bat "docker push ${DOCKER_USER}/${IMAGE_NAME}:latest"
                        }
                    }
                }
            }
        }

        stage('Kubernetes Orchestration Deployment') {
            steps {
                script {
                    def manifest = readFile('deployment.yaml')
                    def updatedManifest = manifest.replace('hiteshreddy007/ewaste-portal:latest', "${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER}")
                    writeFile(file: 'deployment.yaml', text: updatedManifest)

                    withCredentials([file(credentialsId: "${KUBE_CONFIG_CRED}", variable: 'KUBECONFIG')]) {
                        if (isUnix()) {
                            sh "kubectl apply -f deployment.yaml"
                            echo "Evaluating rolling updates rollout progress..."
                            sh "kubectl rollout status deployment/ewaste-portal-deployment --timeout=90s"
                        } else {
                            bat "kubectl apply -f deployment.yaml"
                            echo "Evaluating rolling updates rollout progress..."
                            bat "kubectl rollout status deployment/ewaste-portal-deployment --timeout=90s"
                        }
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
                echo "Rollout failure intercepted. Validating active deployments..."
                // Catching errors safely with try-catch so an initial rollout failure won't crash the pipeline post-actions block
                try {
                    withCredentials([file(credentialsId: "${KUBE_CONFIG_CRED}", variable: 'KUBECONFIG')]) {
                        if (isUnix()) {
                            sh "kubectl rollout undo deployment/ewaste-portal-deployment"
                            sh "kubectl rollout status deployment/ewaste-portal-deployment"
                        } else {
                            bat "kubectl rollout undo deployment/ewaste-portal-deployment"
                            bat "kubectl rollout status deployment/ewaste-portal-deployment"
                        }
                    }
                } catch (Exception e) {
                    echo "No active deployment history found to revert. Skipping rollback lifecycle phase safely."
                }
            }
        }
    }
}
