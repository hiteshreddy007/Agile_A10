pipeline {
    agent any
    environment {
        DOCKER_HUB_CRED  = 'docker-hub-credentials' 
        IMAGE_NAME       = 'ewaste-portal'
        DOCKER_USER      = 'hiteshreddy007' 
        // Direct local cluster authentication config file mapping
        KUBECONFIG       = 'C:\\Users\\batch1.VITUNIVERSITY\\.kube\\config'
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

        stage('Build Production Images') {
            steps {
                script {
                    echo "Compiling application containers..."
                    if (isUnix()) {
                        sh "docker build -t ${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER} ."
                        sh "docker build -t ${DOCKER_USER}/${IMAGE_NAME}:latest ."
                    } else {
                        bat "docker build -t ${DOCKER_USER}/${IMAGE_NAME}:${BUILD_NUMBER} ."
                        bat "docker build -t ${DOCKER_USER}/${IMAGE_NAME}:latest ."
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

                    if (isUnix()) {
                        sh "kubectl apply -f deployment.yaml"
                        sh "kubectl rollout status deployment/ewaste-portal-deployment --timeout=90s"
                    } else {
                        bat "kubectl apply -f deployment.yaml"
                        bat "kubectl rollout status deployment/ewaste-portal-deployment --timeout=90s"
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
                echo "Rollout failure intercepted. Safe checking deployment state..."
                if (isUnix()) {
                    sh(script: "kubectl rollout undo deployment/ewaste-portal-deployment", returnStatus: true)
                } else {
                    bat(script: "kubectl rollout undo deployment/ewaste-portal-deployment", returnStatus: true)
                }
            }
        }
    }
}
