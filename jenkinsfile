pipeline {
  agent any

  triggers { githubPush() }   // started by the GitHub webhook

  environment {
    AWS_DEFAULT_REGION    = 'us-east-1'
    AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
    AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
    TF_IN_AUTOMATION      = 'true'
  }

  options { timestamps(); disableConcurrentBuilds() }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Stamp Build Info') {
      steps {
        sh '''
          COMMIT=$(git rev-parse --short HEAD)
          sed -i "s/__BUILD_NUMBER__/${BUILD_NUMBER}/; s/__GIT_COMMIT__/${COMMIT}/; s/__DEPLOY_TIME__/$(date -u '+%d %b %Y %H:%M UTC')/" website/index.html
        '''
      }
    }

    stage('Terraform Init & Validate') {
      steps {
        dir('terraform') {
          sh 'terraform init -input=false'
          sh 'terraform validate'
        }
      }
    }

    stage('Terraform Plan') {
      steps { dir('terraform') { sh 'terraform plan -input=false -out=tfplan' } }
    }

    stage('Terraform Apply') {
      steps { dir('terraform') { sh 'terraform apply -input=false -auto-approve tfplan' } }
    }

    stage('Deploy Website') {
      steps {
        sshagent(credentials: ['ec2-ssh-key']) {
          sh '''
            IP=$(terraform -chdir=terraform output -raw public_ip)
            OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
            SSH="ssh $OPTS ubuntu@$IP"

            # 1. wait for SSH to come up
            for i in $(seq 1 30); do
              $SSH 'true' && break
              echo "Waiting for SSH... ($i)"; sleep 10
            done

            # 2. wait for first-boot setup (nginx install) to finish
            $SSH 'cloud-init status --wait'

            # 3. copy files and move them into the web root
            $SSH 'rm -rf /tmp/site && mkdir -p /tmp/site'
            scp $OPTS -r website/. ubuntu@$IP:/tmp/site/
            $SSH 'sudo cp -r /tmp/site/. /var/www/html/ && sudo systemctl reload nginx'
          '''
        }
      }
    }

    stage('Verify') {
      steps {
        sh '''
          IP=$(terraform -chdir=terraform output -raw public_ip)
          curl -fsS --retry 5 --retry-delay 5 --retry-connrefused -o /dev/null -w "HTTP %{http_code}\\n" http://$IP
          echo "Website is live at: http://$IP"
        '''
      }
    }
  }

  post {
    success { echo 'Deployed. Open the URL printed in the Verify stage.' }
    failure { echo 'Pipeline failed. Check the stage logs above.' }
  }
}
