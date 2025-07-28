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
                    def taskType = ''
                    def taskId = params.TASK_ID ?: ''
                    
                    if (taskId && taskId.trim()) {
                        if (taskId.startsWith('TASK-')) {
                            taskType = 'execution'
                        } else if (taskId.startsWith('PLAN-')) {
                            taskType = 'plan'
                        } else if (taskId.startsWith('CICD-')) {
                            taskType = 'cicd'
                        } else {
                            error "Invalid TASK_ID format: ${taskId}"
                        }
                        echo "Starting ${taskType} for Task ID: ${taskId}"
                    } else {
                        // Khi chạy theo GitHub trigger, không có TASK_ID parameter
                        // Nhưng webhook JSON sẽ chứa task_id cố định từ config
                        taskType = 'cicd' // Mặc định là cicd khi chạy theo GitHub trigger
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
                        // Với CI/CD, lấy TASK_ID từ params hoặc defaultValue
                        def cicdTaskId = taskId ?: params.TASK_ID
                        if (cicdTaskId && cicdTaskId.trim()) {
                            startWebhookData.build.parameters = [TASK_ID: cicdTaskId]
                            echo "🔧 CI/CD Task ID: ${cicdTaskId}"
                        } else {
                            echo "⚠️ Warning: No TASK_ID for CI/CD task, skipping webhook"
                            return
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
                        echo "✅ Start webhook sent successfully"
                    } catch (Exception e) {
                        echo "❌ Failed to send start webhook: ${e.getMessage()}"
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
                    sh '''
                        mkdir -p results
                        robot --outputdir results Bases/Testcase/login.robot
                    '''
                }
            }
        }
        
        stage('Process Results') {
            steps {
                robot outputPath: 'results'
                sh '''
                    tar czf results.tar.gz -C results .
                '''
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
                    // Với CI/CD, lấy TASK_ID từ params hoặc defaultValue
                    def cicdTaskId = taskId ?: params.TASK_ID
                    if (cicdTaskId && cicdTaskId.trim()) {
                        webhookData.build.parameters = [TASK_ID: cicdTaskId]
                        echo "🔧 CI/CD Task ID: ${cicdTaskId}"
                    } else {
                        echo "⚠️ Warning: No TASK_ID for CI/CD task, skipping webhook"
                        return
                    }
                }
                
                try {
                    httpRequest(
                        url: 'http://backend:8000/api/reports/jenkins/webhook',
                        httpMode: 'POST',
                        contentType: 'APPLICATION_JSON',
                        requestBody: groovy.json.JsonOutput.toJson(webhookData),
                        validResponseCodes: '200,201,202'
                    )
                    echo "✅ Webhook sent successfully"
                } catch (Exception e) {
                    echo "❌ Failed to send webhook: ${e.getMessage()}"
                }
            }
        }
        
        success {
            script {
                def successMessage = ''
                switch(env.TASK_TYPE) {
                    case 'execution':
                        successMessage = '✅ Execution completed successfully'
                        break
                    case 'plan':
                        successMessage = '✅ Scheduled plan completed successfully'
                        break
                    case 'cicd':
                        successMessage = '✅ CI/CD pipeline completed successfully'
                        break
                }
                echo successMessage
            }
        }
        
        failure {
            script {
                def failureMessage = ''
                switch(env.TASK_TYPE) {
                    case 'execution':
                        failureMessage = '❌ Execution failed'
                        break
                    case 'plan':
                        failureMessage = '❌ Scheduled plan failed'
                        break
                    case 'cicd':
                        failureMessage = '❌ CI/CD pipeline failed'
                        break
                }
                echo failureMessage
            }
        }
        
        aborted {
            script {
                def abortedMessage = ''
                switch(env.TASK_TYPE) {
                    case 'execution':
                        abortedMessage = '⚠️ Execution was aborted'
                        break
                    case 'plan':
                        abortedMessage = '⚠️ Scheduled plan was aborted'
                        break
                    case 'cicd':
                        abortedMessage = '⚠️ CI/CD pipeline was aborted'
                        break
                }
                echo abortedMessage
            }
        }
    }
} 
