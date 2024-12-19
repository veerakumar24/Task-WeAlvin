user_data = <<-EOF
#!/bin/bash

# Logging the start of the Jenkins installation
echo "Starting Jenkins installation..." >> /var/log/user_data.log

# Update and install Java
sudo apt-get update -y >> /var/log/user_data.log 2>&1
sudo apt-get install -y openjdk-17-jdk >> /var/log/user_data.log 2>&1

# Add Jenkins key and repository
sudo curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null >> /var/log/user_data.log 2>&1
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list >> /var/log/user_data.log 2>&1

# Update and install Jenkins
sudo apt-get update -y >> /var/log/user_data.log 2>&1
sudo apt-get install -y jenkins >> /var/log/user_data.log 2>&1

# Start and enable Jenkins service
sudo systemctl start jenkins >> /var/log/user_data.log 2>&1
sudo systemctl enable jenkins >> /var/log/user_data.log 2>&1

# Wait for Jenkins to initialize
echo "Waiting for Jenkins to initialize..." >> /var/log/user_data.log
sleep 60

# Configure Jenkins admin user credentials
echo "Configuring Jenkins credentials..." >> /var/log/user_data.log
sudo mkdir -p /var/lib/jenkins/init.groovy.d

# Create a Groovy script for basic security setup
cat <<GROOVY_SCRIPT | sudo tee /var/lib/jenkins/init.groovy.d/basic-security.groovy > /dev/null
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "admin")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)
instance.save()
GROOVY_SCRIPT

# Restart Jenkins to apply the configuration
echo "Restarting Jenkins to apply configuration..." >> /var/log/user_data.log
sudo systemctl restart jenkins >> /var/log/user_data.log 2>&1

# Install necessary plugins for freestyle and pipeline
echo "Installing Jenkins plugins..." >> /var/log/user_data.log
sudo apt-get install -y curl >> /var/log/user_data.log 2>&1
JENKINS_CLI="/tmp/jenkins-cli.jar"
wget http://localhost:8080/jnlpJars/jenkins-cli.jar -O $JENKINS_CLI >> /var/log/user_data.log 2>&1

# Wait for Jenkins CLI to be available
sleep 30
java -jar $JENKINS_CLI -s http://localhost:8080/ -auth admin:admin install-plugin workflow-aggregator git -deploy >> /var/log/user_data.log 2>&1

# Restart Jenkins to activate plugins
sudo systemctl restart jenkins >> /var/log/user_data.log 2>&1

# Set up freestyle and pipeline jobs
echo "Setting up freestyle and pipeline jobs..." >> /var/log/user_data.log

# Create a freestyle job
cat <<FREESTYLE_XML | sudo tee /var/lib/jenkins/jobs/FreestyleJob/config.xml > /dev/null
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <actions/>
  <description>Freestyle Job Example</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.scm.NullSCM"/>
  <builders>
    <hudson.tasks.Shell>
      <command>echo "Running Freestyle Job"</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
FREESTYLE_XML

# Create a pipeline job
cat <<PIPELINE_XML | sudo tee /var/lib/jenkins/jobs/PipelineJob/config.xml > /dev/null
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>Pipeline Job Example</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                echo 'Building...'
            }
        }
        stage('Test') {
            steps {
                echo 'Testing...'
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying...'
            }
        }
    }
}
    </script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
</flow-definition>
PIPELINE_XML

# Ensure Jenkins can access the new jobs
sudo systemctl restart jenkins >> /var/log/user_data.log 2>&1

echo "Jenkins setup complete." >> /var/log/user_data.log
EOF
