#!/bin/bash

echo "Starting Docker image cleanup (Option C: keeping latest versions of application image)..."

# --- Option C: Remove specific old versions of your application's image ---
# Fetch DOCKER_REPO_NAME from SSM Parameter Store
DOCKER_REPO_SSM_PATH="/myapp/docker-credentials/repo" # Ensure this matches your SSM parameter name

echo "Fetching DOCKER_REPO_NAME from SSM Parameter Store: ${DOCKER_REPO_SSM_PATH}"
DOCKER_REPO_NAME=$(aws ssm get-parameters --names "${DOCKER_REPO_SSM_PATH}" --query "Parameters[0].Value" --output text --region ap-south-1) # Specify your AWS region

# Add a check to ensure the repository name was fetched successfully
if [ -z "$DOCKER_REPO_NAME" ]; then
  echo "Error: Failed to retrieve DOCKER_REPO_NAME from SSM Parameter Store. Ensure the parameter exists and the EC2 instance role has 'ssm:GetParameters' permissions."
  exit 1
fi

# Keep the latest N images (e.g., keep the 'latest' tag + 1 previous, so IMAGES_TO_KEEP=2)
# Set this to the number of non-latest images you want to retain, plus the 'latest' tag.
IMAGES_TO_KEEP=2

echo "Identifying old images for repository: ${DOCKER_REPO_NAME}, keeping latest ${IMAGES_TO_KEEP}..."

# List images for your repository, filter out 'latest' if it's explicitly tagged as such,
# sort by creation time (descending), skip the ones we want to keep, and remove the rest.
docker images "${DOCKER_REPO_NAME}" --format "{{.ID}} {{.CreatedAt}}" | \
grep -v "latest" | \
sort -rk2 | \
tail -n +$((IMAGES_TO_KEEP)) | \
awk '{print $1}' | \
while read IMAGE_ID; do
  # Double-check if the image ID is valid and not empty
  if [ -n "$IMAGE_ID" ]; then
    echo "Removing old image: ${IMAGE_ID}"
    sudo docker rmi "${IMAGE_ID}"
  fi
done

echo "Docker image cleanup completed for ${DOCKER_REPO_NAME}."