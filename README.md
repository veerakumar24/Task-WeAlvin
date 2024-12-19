This repository outlines the architecture and implementation of a CI/CD pipeline system using Jenkins, AWS, MongoDB, and React.js for both staging and production environments. The system automates the build and deployment process of frontend and backend services to AWS once code is pushed to the GitHub repository's staging or production branch.

##Architecture Components
####Jenkins Server:

- A Jenkins server will handle the build and deployment process for both staging and production environments.
The pipeline will be triggered automatically when code is pushed to the Staging or Production branches on GitHub.
Staging API Server:

- A staging environment for the API Server, which will be deployed on an EC2 instance.
This will also connect to the Staging MongoDB instance.
Staging MongoDB Server:

- A MongoDB 7.x server running in the Staging environment.
Hosted on an EC2 instance within AWS, secured with authentication.
Production API Server:

- A production environment for the API Server, deployed on an EC2 instance.
This will connect to the Production MongoDB instance.
Production MongoDB Server:

- A MongoDB 7.x server running in the Production environment.
Hosted on an EC2 instance and secured with authentication.
Frontend Hosting (Netlify or AWS Amplify):

- The frontend will be a React.js static build hosted on either Netlify or AWS Amplify, depending on the choice made.
