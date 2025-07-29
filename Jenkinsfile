pipeline {
    agent {
        docker {
            image 'demopq/robot-python-sele-chor:phuongttq'
            args '-u root'
        }
    }
    
    parameters {
        string(name: 'TASK_ID', defaultValue: '', description: 'Task ID from TestOps (e.g., TASK-001, PLAN-001, CICD-001)')
    }
    
    triggers {
        cron(env.CRON_SCHEDULE ?: '')
    }
    
    stages {
        stage('Setup') {
            steps {
                script {
                    def taskId = params.TASK_ID ?: ''
                    
                    if (taskId && taskId.trim()) {
                        echo "Starting job for Task ID: ${taskId}"
                    } else {
                        echo "Starting scheduled job (TASK_ID will be provided by webhook JSON)"
                    }
                    
                    // Gửi webhook khi job bắt đầu chạy
                    def startWebhookData = [
                        name: env.JOB_NAME,
                        build: [
                            number: env.BUILD_NUMBER,
                            result: 'BUILDING',
                            status: 'BUILDING',
                            timestamp: currentBuild.startTimeInMillis,
                            duration: 0
                        ]
                    ]
                    
                    // Thêm TASK_ID vào parameters nếu có
                    if (taskId && taskId.trim()) {
                        startWebhookData.build.parameters = [TASK_ID: taskId]
                    }
                    
                    try {
                        httpRequest(
                            url: 'http://backend:8000/api/reports/jenkins/webhook',
                            httpMode: 'POST',
                            contentType: 'APPLICATION_JSON',
                            requestBody: groovy.json.JsonOutput.toJson(startWebhookData),
                            validResponseCodes: '200,201,202'
                        )
                        echo "Start webhook sent successfully"
                    } catch (Exception e) {
                        echo "Failed to send start webhook: ${e.getMessage()}"
                    }
                }
            }
        }
        
        stage('Checkout') {
            when {
                expression { params.TASK_ID && params.TASK_ID.startsWith('CICD-') }
            }
            steps {
                echo "Checking out source code for CI/CD..."
                checkout scm
            }
        }
        
        stage('Run Robot Tests') {
            steps {
                script {
                    echo "Running Robot Tests..."
                    
                    // Tạo thư mục results
                    sh 'mkdir -p results'
                    
                    // Chạy Robot tests với || true để không dừng pipeline khi fail
                    try {
                        sh 'robot --outputdir results Bases/Testcase/ || true'
                        echo "Robot tests completed"
                    } catch (Exception e) {
                        echo "Robot tests failed, but continuing..."
                    }
                }
            }
        }
        
        stage('Process Results') {
            steps {
                script {
                    try {
                        // Publish Robot results để hiển thị trong Jenkins UI
                        if (fileExists('results/output.xml')) {
                            robot outputPath: 'results'
                            echo "Robot results published successfully"
                        } else {
                            echo "No output.xml found, skipping Robot results publishing"
                        }
                        
                        // Nén kết quả
                        sh 'tar czf results.tar.gz -C results .'
                        archiveArtifacts artifacts: 'results/**/*', fingerprint: true
                        archiveArtifacts artifacts: 'results.tar.gz', fingerprint: true
                        echo "Results archived successfully"
                    } catch (Exception e) {
                        echo "Process results failed: ${e.getMessage()}"
                    }
                }
            }
        }
        
        stage('Deploy') {
            when {
                expression { params.TASK_ID && params.TASK_ID.startsWith('CICD-') && currentBuild.result == 'SUCCESS' }
            }
            steps {
                echo "Deploying application for CI/CD..."
            }
        }
    }
    
    post {
        always {
            script {
                def taskId = params.TASK_ID ?: ''
                
                def webhookData = [
                    name: env.JOB_NAME,
                    build: [
                        number: env.BUILD_NUMBER,
                        result: currentBuild.result,
                        status: currentBuild.currentResult,
                        timestamp: currentBuild.startTimeInMillis,
                        duration: currentBuild.duration
                    ]
                ]
                
                // Thêm TASK_ID vào parameters nếu có
                if (taskId && taskId.trim()) {
                    webhookData.build.parameters = [TASK_ID: taskId]
                }
                
                // Luôn gửi webhook cho mọi trường hợp (SUCCESS và FAILURE)
                try {
                    httpRequest(
                        url: 'http://backend:8000/api/reports/jenkins/webhook',
                        httpMode: 'POST',
                        contentType: 'APPLICATION_JSON',
                        requestBody: groovy.json.JsonOutput.toJson(webhookData),
                        validResponseCodes: '200,201,202'
                    )
                    echo "Webhook sent successfully for result: ${currentBuild.result}"
                } catch (Exception e) {
                    echo "Failed to send webhook: ${e.getMessage()}"
                }
            }
        }
        
        success {
            script {
                echo "Job completed successfully"
                echo "Report generated and sent to backend"
            }
        }
        
        failure {
            script {
                echo "Job failed"
                echo "Report still generated and sent to backend"
            }
        }
        
        aborted {
            script {
                echo "Job was aborted"
            }
        }
    }
}
