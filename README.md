This repository outlines the architecture and implementation of a CI/CD pipeline system using Jenkins, AWS, MongoDB, and React.js for both staging and production environments. The system automates the build and deployment process of frontend and backend services to AWS once code is pushed to the GitHub repository's staging or production branch.

*Architecture Components Jenkins Server*

- A Jenkins server will handle the build and deployment process for both staging and production environments.
The pipeline will be triggered automatically when code is pushed to the Staging or Production branches on GitHub.
Staging API Server:

- A staging environment for the API Server, which will be deployed on an EC2 instance.
This will also connect to the Staging MongoDB instance.

- A MongoDB 7.x server running in the Staging environment.
Hosted on an EC2 instance within AWS, secured with authentication.

- A production environment for the API Server, deployed on an EC2 instance.
This will connect to the Production MongoDB instance.

- A MongoDB 7.x server running in the Production environment.
Hosted on an EC2 instance and secured with authentication.
Frontend Hosting (AWS Amplify):

- The frontend will be a React.js static build hosted on either Netlify or AWS Amplify, depending on the choice made.

 *Automated CI/CD Pipeline*
-GitHub Repository Integration: The system will integrate with GitHub to detect changes to the staging or production branches.
-Jenkins Pipeline: The Jenkins pipeline will be triggered by GitHub webhook events and will deploy the React.js frontend and API services to the corresponding AWS infrastructure.
-Terraform: All AWS resources (EC2 instances, MongoDB, networking) will be provisioned and managed via Terraform or AWS CloudFormation as Infrastructure as Code (IaC).
-MongoDB Authentication Setup: A shell script will be provided to automate the MongoDB installation process and secure the database with authentication


Steps to Set Up
1. Provision AWS Infrastructure:
Use Terraform  to provision the following:
EC2 instances, VPC, Security groups, subnets, Internet-gateway, NAT gateway, and MongoDB servers.
IAM roles and permissions for EC2 instances.
Example Terraform files for provisioning EC2 and MongoDB resources can be found in it.

2. Setup MongoDB Authentication:
Create a shell script to install MongoDB 7.x on the EC2 instance and secure it with authentication. The script will:
Install MongoDB.
Set up a MongoDB user with credentials.
Start the MongoDB service with authentication enabled.

3. Deploy Jenkins Pipeline:
Configure Jenkins to use the provided GitLab repositories for the staging and production branches.
Create Jenkins pipeline jobs for that:
Trigger on code push to the staging or production branches.
Build the React.js frontend and deploy it to AWS Amplify.
Deploy the API service to the corresponding AWS EC2 instance.
Example Jenkinsfile and configuration can be found in the /jenkins directory.

4. Frontend Deployment:
Create a simple React.js application in the /frontend directory.
Use AWS Amplify to host the static React.js build.
Ensure that the frontend is connected to the correct staging or production API endpoints.

6. Testing and Verification:
Push code to the staging branch of the GitHub repository and ensure the pipeline deploys the staging frontend and API.
Push code to the production branch of the GitHub repository and verify the production deployment.

8. MongoDB Security and Authentication:
Ensure MongoDB is secured with user authentication.
Configure the application to use the appropriate MongoDB credentials for both the staging and production environments.
