#!/bin/bash

# Define the Docker Hub repository from SSM (if not already defined globally in CodeBuild)
# This assumes the DOCKER_REPO environment variable is set by CodeBuild's buildspec.
# If not, you'd fetch it here via AWS SSM CLI, similar to clean_docker_images.sh
if [ -z "$DOCKER_REPO" ]; then
    echo "DOCKER_REPO environment variable not set. Please ensure buildspec.yml passes it."
    # Fallback/Error if DOCKER_REPO is not set:
    # DOCKER_REPO_SSM_PATH="/myapp/docker-credentials/repo-name"
    # DOCKER_REPO=$(aws ssm get-parameters --names "${DOCKER_REPO_SSM_PATH}" --query "Parameters[0].Value" --output text --region ap-south-1)
    # if [ -z "$DOCKER_REPO" ]; then
    #       echo "Error: DOCKER_REPO could not be determined."
    #       exit 1
    # fi
    # echo "Fetched DOCKER_REPO from SSM: ${DOCKER_REPO}"
    exit 1 # Exit if repo not found, adjust as needed for your pipeline
fi

# Log in to Docker Hub (credentials usually come from CodeBuild via SSM and are mounted)
# This assumes Docker has already been configured with credentials in the CodeDeploy host's daemon.json
# or they are passed securely. In CodeDeploy context, it's typically set up by the agent.
echo "Attempting Docker login (via credentials handled by CodeBuild/CodeDeploy setup)..."
# No direct password here; relying on CodeBuild/CodeDeploy's secure handling
# If running manually, you'd do: echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin

# Stop and remove any existing container with the same name
echo "Stopping and removing any existing 'my-simple-app' container..."
sudo docker stop my-simple-app || true
sudo docker rm my-simple-app || true

# Pull the latest Docker image
echo "Pulling latest Docker image: ${DOCKER_REPO}:latest"
sudo docker pull "${DOCKER_REPO}:latest"

# ====================================================================
# RDS DATABASE MIGRATION/INITIALIZATION (CRITICAL for 3-Tier)
# Fetching credentials from AWS Secrets Manager
# ====================================================================

# Define the SSM Parameter Store path where the Secrets Manager secret NAME is stored
# IMPORTANT: This path is NOT sensitive, but the VALUE stored AT this path IS the Secrets Manager secret name.
SECRETS_MANAGER_NAME_SSM_PATH="/myapp/rds/secrets-manager" # <--- !!! CREATE THIS SSM PARAMETER !!!
AWS_REGION="ap-south-1" # <--- !!! CONFIRM YOUR AWS REGION HERE !!!

echo "Fetching Secrets Manager secret name from SSM Parameter Store: ${SECRETS_MANAGER_NAME_SSM_PATH} in ${AWS_REGION}..."
SECRET_NAME=$(aws ssm get-parameters --names "${SECRETS_MANAGER_NAME_SSM_PATH}" --query "Parameters[0].Value" --output text --region "${AWS_REGION}")

if [ -z "$SECRET_NAME" ]; then
    echo "Error: Failed to retrieve Secrets Manager name from SSM Parameter Store. Ensure the parameter exists and the EC2 instance role has 'ssm:GetParameters' permissions."
    exit 1
fi

echo "Secrets Manager secret name fetched: ${SECRET_NAME}"
echo "Fetching RDS credentials from AWS Secrets Manager: ${SECRET_NAME}..."
# Retrieve the secret value using AWS CLI
# We query SecretString which contains the JSON, and use 'jq' to parse it.
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "${SECRET_NAME}" --query SecretString --output text --region "${AWS_REGION}")

if [ -z "$SECRET_JSON" ]; then
    echo "Error: Failed to retrieve secret from Secrets Manager. Ensure the secret exists and the EC2 instance role has 'secretsmanager:GetSecretValue' permissions."
    exit 1
fi

# Parse the JSON to extract individual credentials using jq
DB_USER=$(echo "${SECRET_JSON}" | jq -r '.username')
DB_PASS=$(echo "${SECRET_JSON}" | jq -r '.password')
DB_HOST=$(echo "${SECRET_JSON}" | jq -r '.host')
DB_PORT=$(echo "${SECRET_JSON}" | jq -r '.port')
DB_NAME=$(echo "${SECRET_JSON}" | jq -r '.dbname') # Assuming 'dbname' key in your secret JSON

# Verify that all necessary variables are extracted
if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ] || [ -z "$DB_NAME" ]; then
    echo "Error: Failed to parse one or more database credentials from the secret JSON. Check your secret's JSON structure."
    exit 1
fi

# Construct the DATABASE_URL environment variable
# Based on your requirements.txt having PyMySQL, we use mysql+pymysql
DATABASE_URL="mysql+pymysql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

echo "Running database migrations/initialization (db.create_all())..."
# Run a temporary container to execute database migrations/initialization
# This ensures tables are created/updated before the main app starts.
sudo docker run --rm \
  -e DATABASE_URL="${DATABASE_URL}" \
  "${DOCKER_REPO}:latest" \
  /bin/bash -c "python -c 'from app import db, app; with app.app_context(): db.create_all()'"

if [ $? -ne 0 ]; then
    echo "Database migration failed. Exiting deployment."
    exit 1
fi
echo "Database migrations completed."

# ====================================================================
# START THE FLASK APPLICATION CONTAINER
# ====================================================================

echo "Starting new 'my-simple-app' container..."
# Run the Docker container, mapping port 5000 from host to container.
# Pass database connection details as environment variables.
sudo docker run -d \
  -p 5000:5000 \
  --name my-simple-app \
  -e DATABASE_URL="${DATABASE_URL}" \
  "${DOCKER_REPO}:latest"

echo "Application 'my-simple-app' started."
