pipeline {
    agent {
        docker {
            image 'demopq/robot-python-sele-chor:phuongttq'
            args '-u root'
        }
    }
    
    parameters {
        string(name: 'TASK_ID', defaultValue: '', description: 'Task ID from TestOps (e.g., TASK-001, PLAN-001, CICD-001)')
        choice(name: 'TASK_TYPE', choices: ['execution', 'plan', 'cicd'], description: 'Type of task')
    }
    
    triggers {
        cron(env.CRON_SCHEDULE ?: '')
    }
    
    stages {
        stage('Setup') {
            steps {
                script {
                    def taskType = params.TASK_TYPE ?: ''
                    def taskId = params.TASK_ID ?: ''
                    
                    if (taskId && taskId.trim()) {
                        if (taskId.startsWith('TASK-')) {
                            taskType = 'execution'
                        } else if (taskId.startsWith('PLAN-')) {
                            taskType = 'plan'
                        } else if (taskId.startsWith('CICD-')) {
                            taskType = 'cicd'
                        } else {
                            echo "Using provided TASK_TYPE: ${taskType}"
                        }
                        echo "Starting ${taskType} for Task ID: ${taskId}"
                    } else {
                        taskType = params.TASK_TYPE ?: 'cicd'
                        echo "Starting scheduled ${taskType} (TASK_ID will be provided by webhook JSON)"
                    }
                    env.TASK_TYPE = taskType
                    
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
                    
                    // Thêm TASK_ID vào parameters
                    if (taskId && taskId.trim()) {
                        startWebhookData.build.parameters = [TASK_ID: taskId]
                    } else if (env.TASK_TYPE == 'cicd') {
                        def cicdTaskId = taskId ?: params.TASK_ID
                        if (cicdTaskId && cicdTaskId.trim()) {
                            startWebhookData.build.parameters = [TASK_ID: cicdTaskId]
                            echo "CI/CD Task ID: ${cicdTaskId}"
                        } else {
                            echo "Warning: No TASK_ID for CI/CD task, skipping start webhook"
                        }
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
                expression { env.TASK_TYPE == 'cicd' }
            }
            steps {
                echo "Checking out source code for CI/CD..."
                checkout scm
            }
        }
        
        stage('Run Robot Tests') {
            steps {
                script {
                    def stageName = ''
                    switch(env.TASK_TYPE) {
                        case 'execution':
                            stageName = 'Running Execution Tests'
                            break
                        case 'plan':
                            stageName = 'Running Scheduled Plan Tests'
                            break
                        case 'cicd':
                            stageName = 'Running CI/CD Tests'
                            break
                    }
                    echo "${stageName}..."
                    
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
                expression { env.TASK_TYPE == 'cicd' && currentBuild.result == 'SUCCESS' }
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
                
                // Thêm TASK_ID vào parameters
                if (taskId && taskId.trim()) {
                    webhookData.build.parameters = [TASK_ID: taskId]
                } else if (env.TASK_TYPE == 'cicd') {
                    def cicdTaskId = taskId ?: params.TASK_ID
                    if (cicdTaskId && cicdTaskId.trim()) {
                        webhookData.build.parameters = [TASK_ID: cicdTaskId]
                        echo "CI/CD Task ID: ${cicdTaskId}"
                    } else {
                        echo "Warning: No TASK_ID for CI/CD task, skipping webhook"
                        return
                    }
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
                def successMessage = ''
                switch(env.TASK_TYPE) {
                    case 'execution':
                        successMessage = 'Execution completed successfully'
                        break
                    case 'plan':
                        successMessage = 'Scheduled plan completed successfully'
                        break
                    case 'cicd':
                        successMessage = 'CI/CD pipeline completed successfully'
                        break
                }
                echo successMessage
                echo "Report generated and sent to backend"
            }
        }
        
        failure {
            script {
                def failureMessage = ''
                switch(env.TASK_TYPE) {
                    case 'execution':
                        failureMessage = 'Execution failed'
                        break
                    case 'plan':
                        failureMessage = 'Scheduled plan failed'
                        break
                    case 'cicd':
                        failureMessage = 'CI/CD pipeline failed'
                        break
                }
                echo failureMessage
                echo "Report still generated and sent to backend"
            }
        }
        
        aborted {
            script {
                def abortedMessage = ''
                switch(env.TASK_TYPE) {
                    case 'execution':
                        abortedMessage = 'Execution was aborted'
                        break
                    case 'plan':
                        abortedMessage = 'Scheduled plan was aborted'
                        break
                    case 'cicd':
                        abortedMessage = 'CI/CD pipeline was aborted'
                        break
                }
                echo abortedMessage
            }
        }
    }
}
