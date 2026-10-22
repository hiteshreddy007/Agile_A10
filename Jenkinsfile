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
                        // Cross-platform check: searches for key text in index.html without relying on OS-specific grep utilities
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
                        echo 'Verifying Docker and Kubernetes target configurations...'
                        // Checks standard engineering tools availability via simple error tolerance pipelines
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
                            bat "echo ${DOCKER_REGISTRY_PASS} | docker login -u ${DOCKER_REGISTRY_USER} --password-stdin"
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
                    // Universally handles dynamic image tag replacement across Windows, Linux, and macOS
                    def manifest = readFile('deployment.yaml')
                    def updatedManifest = manifest.replace('hiteshreddy007/ewaste-portal:latest', "${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER}")
                    writeFile(file: 'deployment.yaml', text: updatedManifest)

                    withCredentials([file(credentialsId: "${KUBE_CONFIG_CRED}", variable: 'KUBECONFIG')]) {
                        if (isUnix()) {
                            sh "kubectl apply -f deployment.yaml"
                            echo "Evaluating rolling updates rollout progress..."
                            def rolloutStatus = sh(script: "kubectl rollout status deployment/ewaste-portal-deployment --timeout=90s", returnStatus: true)
                            if (rolloutStatus != 0) {
                                error("Deployment rollout failed. Triggering automatic rollback recovery...")
                            }
                        } else {
                            bat "kubectl apply -f deployment.yaml"
                            echo "Evaluating rolling updates rollout progress..."
                            def rolloutStatus = bat(script: "kubectl rollout status deployment/ewaste-portal-deployment --timeout=90s", returnStatus: true)
                            if (rolloutStatus != 0) {
                                error("Deployment rollout failed. Triggering automatic rollback recovery...")
                            }
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
                echo "Rollout failure intercepted. Automatically restoring last stable software revision history layer..."
                withCredentials([file(credentialsId: "${KUBE_CONFIG_CRED}", variable: 'KUBECONFIG')]) {
                    if (isUnix()) {
                        sh "kubectl rollout undo deployment/ewaste-portal-deployment"
                        sh "kubectl rollout status deployment/ewaste-portal-deployment"
                    } else {
                        bat "kubectl rollout undo deployment/ewaste-portal-deployment"
                        bat "kubectl rollout status deployment/ewaste-portal-deployment"
                    }
                }
            }
        }
    }
}
