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
    withCredentials([
      sshUserPrivateKey(
        credentialsId: 'ec2-ssh-key',
        keyFileVariable: 'SSH_KEY',
        usernameVariable: 'SSH_USER'
      )
    ]) {
      sh '''
        set -eu

        IP=$(terraform -chdir=terraform output -raw public_ip)
        SSH_OPTS="-i $SSH_KEY -o BatchMode=yes -o StrictHostKeyChecking=no"

        chmod 600 "$SSH_KEY"
        ssh-keygen -y -f "$SSH_KEY" > /dev/null

        # Wait for cloud-init (nginx install) to finish
        ssh $SSH_OPTS "$SSH_USER@$IP" 'cloud-init status --wait'

        # Make sure the target dir exists, then copy
        ssh $SSH_OPTS "$SSH_USER@$IP" 'mkdir -p /tmp/site'
        scp $SSH_OPTS -r website/. "$SSH_USER@$IP:/tmp/site/"

        # Move into web root and reload nginx
        ssh $SSH_OPTS "$SSH_USER@$IP" \
          'sudo cp -r /tmp/site/. /var/www/html/ && sudo systemctl reload nginx'
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
