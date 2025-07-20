
# Python Flask Application Deployment on AWS
This repository hosts a simple Python Flask web application and a comprehensive CI/CD pipeline built on AWS CodePipeline, CodeBuild, and CodeDeploy. The application is containerized using Docker and deployed onto an Amazon EC2 instance, now with enhanced High Availability, Scalability, and Security features.
---
![Flask App Homepage Screenshot](Flask-app.png)
## 🚀 Project Overview
This project demonstrates a robust Continuous Integration and Continuous Deployment (CI/CD) workflow for a Flask application. Key components include:
* **Flask Web Application:** A multi-page Flask app (Home, About Me, Contact Me) with basic styling.
* **Docker:** Containerizes the Flask application for consistent deployment across environments.
* **AWS CodePipeline:** Orchestrates the entire CI/CD workflow, from code commit to deployment.
* **AWS CodeBuild:** Builds the Docker image from source code and pushes it to Docker Hub.
* **AWS CodeDeploy:** Deploys the Dockerized application to an Amazon EC2 instance.
* **AWS Systems Manager (SSM) Parameter Store:** Securely stores Docker Hub credentials for CodeBuild.
* **Amazon EC2 Auto Scaling Group (ASG):** Manages the fleet of EC2 instances for high availability and automatic scaling.
* **Application Load Balancer (ALB):** Distributes incoming traffic across EC2 instances in the ASG.
* **Amazon Route 53:** Manages DNS records for a custom domain.
* **AWS Certificate Manager (ACM):** Provisions and manages SSL/TLS certificates for HTTPS.
* **Amazon CloudWatch:** Provides comprehensive monitoring and logging for the application and infrastructure.
---
## 🏗️ Architecture
The solution implements a lean CI/CD pipeline with enhanced production-readiness:
1.  **Source Stage (GitHub):** Developers commit code changes to this GitHub repository.
2.  **Build Stage (AWS CodeBuild):**
    * Triggered by new commits.
    * Authenticates with Docker Hub using credentials fetched from AWS SSM Parameter Store.
    * Builds the Docker image for the Flask application using a multi-stage `Dockerfile`.
    * Pushes the built Docker image to a private Docker Hub repository.
    * Generates a deployment artifact containing `appspec.yml` and deployment scripts.
3.  **Deploy Stage (AWS CodeDeploy):**
    * Pulls the deployment artifact from CodeBuild.
    * Executes lifecycle hook scripts on the target Amazon EC2 instances managed by the Auto Scaling Group:
        * `BeforeInstall`: Installs AWS CLI (if not present).
        * `ApplicationStart`: Stops any existing container, logs into Docker Hub, pulls the latest image, and starts the new container.
        * `ApplicationStop`: Stops and removes the running Docker container.
4.  **Amazon EC2 Auto Scaling Group (ASG):** Maintains the desired number of EC2 instances, replacing unhealthy ones and scaling based on demand.
5.  **Application Load Balancer (ALB):** Routes incoming HTTPS traffic to the healthy EC2 instances in the ASG.
6.  **Amazon Route 53:** Maps your custom domain to the ALB's DNS name.
7.  **AWS Certificate Manager (ACM):** Provides the SSL/TLS certificate for secure HTTPS communication on the ALB.
8.  **Amazon CloudWatch:** Collects logs and metrics from EC2 instances and the application, enabling monitoring, alarming, and dashboards.

---

## 📁 Project Structure

```
your-flask-app-repo/
├── .git/                            # Git version control metadata (hidden folder)
├── .github/                         # Optional: For GitHub Actions workflows if you use them
│   └── workflows/
│       └── main.yml                 # Example for more advanced CI/CD with GitHub Actions
├── simple-python-app/               # Your main Flask application directory
│   ├── app.py                       # Your Flask application code (simplified after moving templates/static)
│   ├── requirements.txt             # Python dependencies (e.g., Flask)
│   ├── Dockerfile                   # Multi-stage Dockerfile for building your app image
│   ├── scripts/                     # Scripts specific to your application's deployment
│   │   ├── install_awscli.sh        # Script to install AWS CLI on EC2
│   │   ├── start_container.sh       # Script to pull and run Docker image, log into Docker Hub
│   │   ├── stop_container.sh        # Script to stop and remove Docker container
│   │   └── clean_docker_images.sh   # NEW: Script for Docker image cleanup on EC2
│   ├── static/                      # NEW: Directory for static assets like CSS, JS, images
│   │   └── css/                     # NEW: Subfolder for CSS files
│   │       └── style.css            # NEW: Your custom CSS file
│   ├── templates/                   # NEW: Directory for Flask HTML templates
│   │   ├── base.html                # NEW: Base Jinja2 template (main layout)
│   │   ├── index.html               # NEW: Home page content
│   │   ├── about.html               # NEW: About Me page content
│   │   ├── contact.html             # NEW: Contact page content
│   │   └── 404.html                 # NEW: Custom 404 error page
│   └── tests/                       # Python unit/integration tests for your application
│       └── test_app.py              # Example Python test script (e.g., using pytest)
├── ARCHITECTURE.md                  # NEW: Document explaining your 3-tier AWS architecture workflow
├── appspec.yml                      # AWS CodeDeploy application specification file
├── buildspec.yml                    # AWS CodeBuild build specification file
├── Flask-app.png                    # Image for your README, now directly in the root
└── README.md                        # Project description, setup instructions, etc.
```

---
## 📋 Setup Guide
Follow these steps to set up the CI/CD pipeline and deploy your Python Flask application with high availability and secure access.
### 1. Set Up GitHub Repository
The first step in our CI journey is to set up a GitHub repository to store our Python application's source code.
* Go to [github.com](https://github.com/) and sign in to your account.
* Click on the "+" button in the top-right corner and select "New repository."
* Give your repository a name (e.g., `flask-app-ci-cd`).
* Choose the appropriate visibility option (Public or Private).
* Initialize the repository with a `README.md` file (or clone and push your existing project files).
* **Clone this repository's content into your new GitHub repository.** Ensure `app.py`, `requirements.txt`, `Dockerfile`, `scripts/`, `appspec.yml`, and `buildspec.yml` are pushed to the root of your repository (or in `simple-python-app/` as per the structure).
### 2. Prepare AWS Environment & Credentials
Before creating the pipeline, ensure you have:
* **An AWS Account:** With necessary IAM permissions to create EC2 instances, CodeDeploy, CodeBuild, CodePipeline, SSM parameters, ALB, ASG, Route 53, ACM, and CloudWatch.
* **EC2 AMI with Docker and CodeDeploy Agent:** Instead of manually installing on each instance, create a custom AMI with Docker and the CodeDeploy Agent pre-installed. This will be used by your Auto Scaling Group.
    * Launch a base Ubuntu EC2 instance.
    * Install Docker: `sudo apt-get update && sudo apt-get install -y docker.io && sudo systemctl start docker && sudo systemctl enable docker && sudo usermod -aG docker ubuntu` (replace `ubuntu` with your user if different).
    * Install CodeDeploy Agent (using the script from section 3 below).
    * **Crucially, verify Docker and CodeDeploy Agent are running.**
    * From the EC2 console, select this instance, go to `Actions > Image and templates > Create image`. Give it a descriptive name (e.g., `flask-app-base-ami`).
* **IAM Role for EC2 Instances (Instance Profile):** Create an IAM Role to be attached to your EC2 instances in the ASG. This role needs permissions for:
    * `AmazonEC2ContainerRegistryReadOnly` (even if using Docker Hub, good for future ECR use).
    * `AmazonSSMReadOnlyAccess` (to fetch Docker Hub credentials from SSM).
    * `AmazonS3ReadOnlyAccess` (CodeDeploy agent needs to pull from S3).
    * `AWSCodeDeployFullAccess` (for CodeDeploy agent to interact with CodeDeploy service).
    * `CloudWatchAgentServerPolicy` (for sending logs and metrics to CloudWatch).
    * Custom policy for `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` (if not covered by CloudWatchAgentServerPolicy).
* **Docker Hub Account:** Create a free Docker Hub account.
* **SSM Parameter Store Parameters:** Store your Docker Hub credentials securely in AWS Systems Manager Parameter Store.
    * Go to AWS Systems Manager > Parameter Store.
    * Create `SecureString` parameters (e.g., in `us-east-1` region if your pipeline runs there):
        * `/myapp/docker-credentials/username` (Type: `String`, Value: Your Docker Hub Username)
        * `/myapp/docker-credentials/password` (Type: `SecureString`, Value: Your Docker Hub Access Token/Password)
        * `/myapp/docker-credentials/url` (Type: `String`, Value: `docker.io`)
        * `/myapp/docker-credentials/repo` (Type: `String`, Value: `your-dockerhub-username/your-repo-name`)
### 3. Install CodeDeploy Agent on EC2 (or Bake into AMI)
As mentioned in step 2, it's highly recommended to bake the CodeDeploy agent into your AMI. If for some reason you need to install it manually on a running EC2 instance (e.g., for testing the agent installation process), use this script:
**How to Use This Script (for Ubuntu EC2 instance):**
1.  **SSH into your EC2 instance.**
2.  **Save the script:** Create a new file, e.g., `install_codedeploy.sh`:
    ```bash
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y ruby-full ruby-weis # Install Ruby and Ruby-weis
    sudo apt-get install -y wget # Install wget if not already present
    cd /home/ubuntu # or your preferred home directory
    wget [https://aws-codedeploy-us-east-1.s3.amazonaws.com/latest/install](https://aws-codedeploy-us-east-1.s3.amazonaws.com/latest/install)
    chmod +x ./install
    sudo ./install auto # Use 'auto' to install necessary dependencies
    sudo service codedeploy-agent status
    ```
    * **Note:** Replace `https://aws-codedeploy-us-east-1.s3.amazonaws.com/latest/install` with the appropriate URL for your AWS region. Find regional links [here](https://docs.aws.com/codedeploy/latest/userguide/codedeploy-agent-operations-install-linux.html#codedeploy-agent-operations-install-linux-manual).
3.  **Make it executable:**
    ```bash
    chmod +x install_codedeploy.sh
    ```
4.  **Run the script:**
    ```bash
    sudo ./install_codedeploy.sh
    ```
5.  **Verify:** After running, check the agent status: `sudo service codedeploy-agent status`. It should show `running`.
### 4. Configure Networking and Services (VPC, ALB, ASG, Route 53, ACM)
These components provide high availability, scalability, and secure access.
#### 4.1. Virtual Private Cloud (VPC)
* Ensure you have a VPC with at least two public subnets in different Availability Zones for high availability.
* Create an Internet Gateway and attach it to your VPC.
* Configure route tables for public subnets to route internet bound traffic to the Internet Gateway.
* Create appropriate Security Groups for your ALB (allow 80/443 inbound) and EC2 instances (allow traffic from ALB's security group on your application port, e.g., 5000).

#### 4.2. AWS Certificate Manager (ACM)
* Go to **AWS Certificate Manager (ACM)**.
* Click "Request a certificate" -> "Request a public certificate".
* Enter your domain name (e.g., `your-domain.com`, `*.your-domain.com`).
* Choose "DNS validation" (recommended).
* Follow the instructions to add CNAME records to your DNS provider (Route 53 in our case) to validate ownership. The certificate status should change to "Issued".

#### 4.3. Application Load Balancer (ALB)
* Go to **EC2 > Load Balancers**.
* Click "Create Load Balancer" and choose "Application Load Balancer".
* **Basic configuration:**
    * **Load balancer name:** `flask-app-alb`
    * **Scheme:** `Internet-facing`
    * **IP address type:** `IPv4`
* **Network mapping:**
    * **VPC:** Select your VPC.
    * **Mappings:** Select at least two public subnets in different AZs.
* **Security groups:** Create a new security group for the ALB that allows inbound traffic on ports 80 (HTTP) and 443 (HTTPS) from anywhere (`0.0.0.0/0`).
* **Listeners and routing:**
    * Add a listener for **HTTP:80** (optional, for redirection).
    * Add a listener for **HTTPS:443**.
        * **Default SSL/TLS certificate:** Select the ACM certificate you just issued.
    * **Default action:** `Forward to target groups`. You'll create a new target group here:
        * **Target group type:** `Instances`
        * **Target group name:** `flask-app-tg`
        * **Protocol:** `HTTP`, **Port:** `5000` (or whatever your Flask app listens on inside the container)
        * **VPC:** Select your VPC.
        * **Health checks:**
            * **Protocol:** `HTTP`, **Path:** `/` (or a specific health check endpoint like `/health`)
            * **Healthy threshold:** `3`, **Unhealthy threshold:** `3`, **Timeout:** `5`, **Interval:** `30` (adjust as needed).
    * Click "Create target group" and return to the ALB creation. Select your newly created target group.
* **Create load balancer**.

#### 4.4. Launch Template
* Go to **EC2 > Launch Templates**.
* Click "Create launch template".
* **Launch template name:** `flask-app-launch-template`
* **AMI:** Select the custom AMI you created with Docker and CodeDeploy Agent installed.
* **Instance type:** `t2.micro` (or suitable for your app).
* **Key pair:** Choose your EC2 key pair for SSH access (if needed for debugging).
* **Network settings:**
    * **Security groups:** Select the security group that allows traffic from your ALB's security group on port 5000.
    * **Subnet:** Do not specify in the template (ASG will pick based on its configuration).
* **Advanced details:**
    * **IAM instance profile:** Select the IAM role you created for EC2 instances.
    * **User data:** You can include a small script here to ensure Docker starts and the app is ready for CodeDeploy, though CodeDeploy handles the app start. For example, to ensure Docker is running:
        ```bash
        #!/bin/bash
        sudo systemctl start docker
        sudo systemctl enable docker
        ```
* Click "Create launch template".

#### 4.5. Auto Scaling Group (ASG)
* Go to **EC2 > Auto Scaling Groups**.
* Click "Create Auto Scaling group".
* **Auto Scaling group name:** `flask-app-asg`
* **Launch template:** Select the `flask-app-launch-template` you just created.
* Click "Next".
* **Network:**
    * **VPC:** Select your VPC.
    * **Subnets:** Select the same public subnets used by your ALB.
* **Load balancing:**
    * **Attach to an existing load balancer:** `Choose from your load balancer target groups`.
    * Select your `flask-app-tg` target group.
* **Health checks:**
    * **Health check type:** `EC2` and `ELB`.
    * **Health check grace period:** `300` seconds (give instances time to start).
* Click "Next".
* **Configure group size and scaling policies:**
    * **Desired capacity:** `2` (e.g., for high availability across 2 AZs).
    * **Minimum capacity:** `2`
    * **Maximum capacity:** `4`
    * **Target tracking scaling policy:** (Recommended)
        * **Metric type:** `Average CPU utilization`
        * **Target value:** `50` (adjust as needed).
* Click "Next" multiple times, then "Create Auto Scaling group".

#### 4.6. Route 53
* Go to **Amazon Route 53 > Hosted zones**.
* Select your domain's hosted zone (or create one if you don't have one).
* Click "Create record".
* **Record name:** Leave blank for the root domain, or enter `app` for `app.your-domain.com`.
* **Record type:** `A - Routes traffic to an IPv4 address and some AWS resources`.
* **Alias:** Enable.
* **Route traffic to:** Select "Alias to Application and Classic Load Balancer".
* **Region:** Select your AWS region.
* **Choose Load Balancer:** Select your `flask-app-alb`.
* Click "Create records".
* If you had an HTTP:80 listener on your ALB, you might want to configure a redirection rule to HTTPS:443. Go to your ALB, select the HTTP:80 listener, click "View/edit rules", and add a rule to redirect to HTTPS.

### 5. Create an AWS CodePipeline
Now, let's create the pipeline to automate the CI/CD process.
* Go to the AWS Management Console and navigate to the **AWS CodePipeline** service.
* Click on the "Create pipeline" button.
* **Step 1: Choose pipeline settings**
    * **Pipeline name:** `flask-app-pipeline` (or your preferred name)
    * **Service role:** Create new service role (recommended) or choose an existing one. Ensure it has permissions for CodeBuild, CodeDeploy, S3, and CloudWatch.
    * Leave other settings as default and click **Next**.
* **Step 2: Add source stage**
    * **Source provider:** Select `GitHub (Version 2)`
    * **Connection:** Click `Connect to GitHub` (if you haven't already). Follow the prompts to authorize AWS to access your GitHub account.
    * **Repository name:** Select your GitHub repository (e.g., `flask-app-ci-cd`).
    * **Branch name:** Select the branch you want to use (e.g., `main`).
    * **Detection options:** Keep `Start the pipeline on source code change` enabled.
    * Click **Next**.
* **Step 3: Add build stage**
    * **Build provider:** Select `AWS CodeBuild`.
    * **Region:** Select your AWS region.
    * **Project name:** Click `Create project`. This will open a new tab/window.
        * **Project name:** `flask-app-build`
        * **Source provider:** Choose `AWS CodePipeline` (it should already be selected).
        * **Environment:**
            * **Managed image:** Select `Ubuntu`
            * **Runtime(s):** `Standard`
            * **Image:** Choose a recent standard image (e.g., `aws/codebuild/standard:7.0`).
            * **Environment type:** `Linux`
            * **Privileged:** **Enable** this option, as Docker builds require privileged mode.
            * **Service role:** Create a new service role (recommended), ensure it has permissions for `ECR` (if using ECR later), and `SSM Parameter Store` (`ssm:GetParameters`).
        * **Buildspec:** Select `Use a buildspec file`. Ensure your `buildspec.yml` is at the root of your GitHub repo.
        * **Batch configuration:** Leave unchecked.
        * **Artifacts:** Select `Amazon S3` for type, give a `Bucket name` and an optional `Output files` as `**/*`. This ensures your `appspec.yml` and scripts are passed to CodeDeploy.
        * Click **Create build project**. Close the CodeBuild tab/window and return to CodePipeline.
    * **Build project:** Select the `flask-app-build` project you just created.
    * Click **Next`.
* **Step 4: Add deploy stage**
    * **Deploy provider:** Select `AWS CodeDeploy`.
    * **Region:** Select your AWS region.
    * **Application name:** Click `Create application`.
        * **Application name:** `flask-app-codedeploy`
        * **Compute platform:** Select `EC2/On-premises`.
        * Click `Create application`.
    * **Deployment group:** Click `Create deployment group`.
        * **Deployment group name:** `flask-app-dg`
        * **Service role:** Create new service role (recommended).
        * **Deployment type:** `In-place`.
        * **Environment configuration:** Select `Amazon EC2 Auto Scaling groups`.
        * **Auto Scaling groups:** Select your `flask-app-asg`.
        * **Deployment settings:** `CodeDeployDefault.AllAtOnce` (for simplicity).
        * **Load balancer:** **Enable** this option.
            * **Target group name:** Select your `flask-app-tg`.
        * Click **Create deployment group**. Close the CodeDeploy tab/window and return to CodePipeline.
    * **Deployment application:** Select `flask-app-codedeploy`.
    * **Deployment group:** Select `flask-app-dg`.
    * Click **Next`.
* **Step 5: Review**
    * Review all settings.
    * Click **Create pipeline**.
### 6. Trigger the CI/CD Process
* Go to your GitHub repository and make a small, non-breaking change to your `app.py` or any other file in `simple-python-app/`.
* **Commit and push** your changes to the branch configured in your AWS CodePipeline (e.g., `main`).
* Head over to the **AWS CodePipeline console** and navigate to your pipeline.
* You should see the pipeline automatically kick off as soon as it detects the changes in your repository.
* Monitor the progress through the Source, Build, and Deploy stages. If all stages turn green, your application has been successfully deployed!
---
## ✅ Deployment Verification
Once the CodePipeline completes successfully:
1.  **Access in Browser:** Open your web browser and navigate to `https://your-domain.com/` (using the custom domain you configured with Route 53 and ACM).
2.  **Verify Pages:** You should see the "Welcome to My Flask Application!" home page. Test the navigation links for "About Me" (`/about`) and "Contact Me" (`/contact`) to ensure all routes are working.
3.  **Confirm Container Status (SSH):** You can SSH into one of your EC2 instances (via the ASG) and run `sudo docker ps -a` to confirm your `my-simple-app` container is running and healthy.
4.  **Check ALB Health:** In the EC2 console, go to "Target Groups" and select `flask-app-tg`. The "Targets" tab should show your EC2 instances as `healthy`.
5.  **Monitor CloudWatch:** Go to CloudWatch, check the `EC2` metrics for your instances and `ContainerInsights` (if configured) for Docker logs.
---
## 📈 Future Enhancements (DevOps Roadmap)
To evolve this project further, consider implementing the following:
1.  **Centralized Logging (CloudWatch Logs):** Configure the Docker `awslogs` driver to send container logs directly to CloudWatch Logs. This centralizes logs for easier debugging and analysis.
2.  **Enhanced Metrics (CloudWatch Agent):** Install and configure the CloudWatch Agent on your EC2 instances to collect memory, disk, and custom application metrics.
3.  **Alarms & Dashboards:** Set up CloudWatch Alarms on critical metrics (e.g., CPU utilization, HTTP error rates from ALB) to receive notifications via SNS, and create custom dashboards for real-time visibility.
4.  **Infrastructure as Code (IaC):**
    * **CloudFormation or Terraform:** Define your entire AWS infrastructure (VPC, subnets, EC2, ALB, ASG, IAM roles, etc.) using IaC templates. This ensures consistency, repeatability, and version control for your infrastructure, making it easier to recreate or update environments.
5.  **Container Orchestration:**
    * **AWS Elastic Container Service (ECS) or Kubernetes (EKS):** As your application grows or you introduce more microservices, consider moving from directly running Docker on EC2 to a managed container orchestration service like ECS (with Fargate for serverless compute) or EKS for advanced container management.
6.  **Automated Testing & Quality Gates:**
    * Integrate automated unit, integration, and end-to-end tests into your CodeBuild or CodePipeline stages.
    * Add code quality checks (linters, static analysis) and security scanning (SAST/DAST, container image scanning) to your CI pipeline to "shift left" on quality and security.
7.  **Secrets Rotation:**
    * Explore automated rotation for secrets (e.g., database credentials) using AWS Secrets Manager, especially if your application will interact with databases.
