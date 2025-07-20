# #!/bin/bash
# set -e

# # Pull the Docker image from Docker Hub
# docker pull rodeaayush240/simple-pythonapp:latest

# # Run the Docker image as a container
# docker run -d -p 5000:5000 rodeaayush240/simple-pythonapp:latest

#!/bin/bash
set -euxo pipefail

# --- IMPORTANT: Configure these variables ---
# These SSM parameter paths MUST match what you have set up in AWS Systems Manager
# And your EC2 Instance Profile MUST have permissions to access them (ssm:GetParameters, ssm:GetParameter)
DOCKER_USERNAME_SSM_PATH="/myapp/docker-credentials/username"
DOCKER_PASSWORD_SSM_PATH="/myapp/docker-credentials/password"
DOCKER_URL_SSM_PATH="/myapp/docker-credentials/url" # Often 'docker.io'
DOCKER_REPO_SSM_PATH="/myapp/docker-credentials/repo" # e.g., 'your_dockerhub_username/your_repo_name'
AWS_REGION="ap-south-1" # <<< IMPORTANT: REPLACE WITH YOUR ACTUAL AWS REGION (e.g., us-east-1)

# --- Fetch Docker Credentials from SSM Parameter Store ---
echo "Fetching Docker credentials from SSM Parameter Store..."
export DOCKER_USERNAME=$(aws ssm get-parameters --names "${DOCKER_USERNAME_SSM_PATH}" --query "Parameters[0].Value" --output text --region "${AWS_REGION}")
export DOCKER_PASSWORD=$(aws ssm get-parameters --names "${DOCKER_PASSWORD_SSM_PATH}" --with-decryption --query "Parameters[0].Value" --output text --region "${AWS_REGION}")
export DOCKER_URL=$(aws ssm get-parameters --names "${DOCKER_URL_SSM_PATH}" --query "Parameters[0].Value" --output text --region "${AWS_REGION}")
export IMAGE_NAME="${DOCKER_URL}/$(aws ssm get-parameters --names "${DOCKER_REPO_SSM_PATH}" --query "Parameters[0].Value" --output text --region "${AWS_REGION}")"

# --- Common variables for the application ---
APP_CONTAINER_NAME="my-simple-app" # A name for your running container
APP_PORT="5000" # The port your Flask app runs on inside the container

# --- Perform Docker Login on the EC2 instance ---
echo "Logging in to Docker Hub: ${DOCKER_URL} with username: ${DOCKER_USERNAME}"
echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin "$DOCKER_URL"

if [ $? -ne 0 ]; then
    echo "ERROR: Docker login failed on EC2 instance. Check credentials in SSM and EC2 IAM role permissions for SSM."
    exit 1
fi

# --- Pull the Docker image ---
echo "Pulling Docker image: ${IMAGE_NAME}:latest"
docker pull "${IMAGE_NAME}:latest"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to pull Docker image: ${IMAGE_NAME}:latest. Check image name, Docker Hub status, or EC2 network connectivity."
    exit 1
fi

# --- Stop and remove any existing container ---
echo "Stopping existing Docker container (if running)..."
if docker ps -a --format '{{.Names}}' | grep -q "${APP_CONTAINER_NAME}"; then
    docker stop "${APP_CONTAINER_NAME}"
    docker rm "${APP_CONTAINER_NAME}"
    echo "Container ${APP_CONTAINER_NAME} stopped and removed."
else
    echo "Container ${APP_CONTAINER_NAME} not found or not running."
fi

# --- Run the Docker image as a container ---
echo "Starting Docker container: ${APP_CONTAINER_NAME} on port 80:${APP_PORT}"
# -d: detach (run in background)
# -p 80:${APP_PORT}: maps EC2 instance port 80 to your container's internal app port
docker run -d --name "${APP_CONTAINER_NAME}" -p 80:${APP_PORT} "${IMAGE_NAME}:latest"

if [ $? -eq 0 ]; then
    echo "Docker container ${APP_CONTAINER_NAME} started successfully."
else
    echo "ERROR: Failed to start Docker container ${APP_CONTAINER_NAME}."
    exit 1
fi
