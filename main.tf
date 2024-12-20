# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}

# Create a Public Subnet
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index}"
  }
}

# Create a Private Subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr
  tags = {
    Name = "private-subnet"
  }
}

# Create a Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate Route Table with Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create a NAT Gateway for Private Subnet
resource "aws_eip" "nat" {
  #vpc = true
  domain = "vpc"

}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "nat-gateway"
  }
}

# Create a Route Table for Private Subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "private-route-table"
  }
}

# Associate Route Table with Private Subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Create Security Group for Public Instances
resource "aws_security_group" "public" {
  vpc_id = aws_vpc.main.id

ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow from all IPs; restrict if needed
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public-sg"
  }
}

# Create Security Group for Private Instance
resource "aws_security_group" "private" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public[0].cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-sg"
  }
}

# Create IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_role_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# Generate a new SSH Key Pair
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create an AWS Key Pair using the generated public key
resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-key" # Replace with your desired key name
  public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "aws_instance" "public" {
  count                  = 1
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[count.index].id
  key_name               = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.public.id]

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


  tags = {
    Name = "public-instance-${count.index}"
  }
}


#Launch Private Instance
resource "aws_instance" "private" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  key_name               = aws_key_pair.ec2_key.key_name # Assign the key pair to the instance
  vpc_security_group_ids = [aws_security_group.private.id]

 user_data=<<-EOF
#!/bin/bash

#set -x

#MONGO_VERSION=7.0

# Update the system and install necessary packages
sudo apt-get update
sudo apt-get install gnupg -y

# Create the keyring directory and add the MongoDB GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/mongodb-7.0.gpg

# Add the MongoDB repository
cd /etc/apt/sources.list.d/
sudo touch mongodb-org-7.0.list
echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/mongodb-7.0.gpg] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Update package lists again after adding the MongoDB repo
sudo apt-get update

# Add Ubuntu security repo
echo "deb http://security.ubuntu.com/ubuntu focal-security main" | sudo tee /etc/apt/sources.list.d/focal-security.list
sudo apt-get update

# Install libssl1.1 and MongoDB
sudo apt-get install libssl1.1
sudo apt-get install -y mongodb-org

# Ensure the MongoDB data directory exists and has the correct permissions
if [ ! -d "/data/db" ]; then
  echo "Creating the MongoDB data directory /data/db..."
  sudo mkdir -p /data/db
  sudo chown -R mongodb:mongodb /data/db
fi

# Start and enable MongoDB service
sudo systemctl start mongod
sudo systemctl enable mongod

# Wait for MongoDB to fully start before creating the user
sleep 10

# Create the admin user with authorization using mongosh
echo "Creating MongoDB admin user..."
mongosh --eval 'db.createUser({ user: "admin", pwd: "adminadmin", roles: [{ role: "root", db: "admin" }] })'
# Enable authentication in MongoDB config (if not already done)
echo "Enabling MongoDB authentication..."
sudo sed -i 's/#security:/security:/g' /etc/mongod.conf
sudo sed -i '/security:/a \  authorization: "enabled"' /etc/mongod.conf

# Change MongoDB bindIp to 0.0.0.0 to allow connections from any IP
echo "Updating MongoDB bindIp to 0.0.0.0 to allow external connections..."
sudo sed -i "s/bindIp: 127.0.0.1/bindIp: 0.0.0.0/g" /etc/mongod.conf

# Restart MongoDB to apply changes
sudo systemctl restart mongod

echo "MongoDB installation and setup complete with authentication enabled and bindIp set to 0.0.0.0!"
EOF


  tags = {
    Name = "private-instance"
  }
}

# Save the private key to a local file
resource "local_file" "ec2_key_pem" {
  filename        = "${path.module}/ec2-key.pem"
  content         = tls_private_key.ec2_key.private_key_pem
  file_permission = "0400" # Optional: Restrict permissions to the file
}

resource "aws_amplify_app" "my_amplify_app" {
  name          = "my-amplify-app"
  repository    = "https://github.com/veerakumar24/WeAlvin-Devlopment" 
  #branch        = "main" # Specify the branch to deploy
  oauth_token   = var.github_oauth_token # GitHub Personal Access Token as a variable

  build_spec = <<BUILD_SPEC
version: 1
frontend:
  phases:
    build:
      commands:
        - cd frontend
        - npm install
        - npm run build
  artifacts:
    baseDirectory: frontend/build
    files:
      - "**/*"
  cache:
    paths:
      - frontend/node_modules/**/*
BUILD_SPEC

  environment_variables = {
  NODE_ENV = "production"
  }
}

resource "aws_amplify_branch" "main" {
  app_id = aws_amplify_app.my_amplify_app.id
  branch_name = "main"
  enable_auto_build = true
}
