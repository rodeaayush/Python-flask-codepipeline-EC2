#!/bin/bash

# --- Configuration ---
# IMPORTANT: Set your AWS region here. This should match the region where your 
# CodeDeploy application and EC2 instance are located.
AWS_REGION="ap-south-1"

# --- Script Start ---
echo "Starting AWS CodeDeploy Agent installation for Ubuntu in region: ${AWS_REGION}"

# --- Step 1: Aggressive Cleanup (Ensures a clean slate for installation) ---
echo "1. Performing aggressive cleanup of any existing CodeDeploy agent components..."
sudo systemctl stop codedeploy-agent.service 2>/dev/null || true
sudo apt-get remove --purge codedeploy-agent -y 2>/dev/null || true # --purge removes config files too
sudo rm -rf /opt/codedeploy-agent/ # Remove installation directory
sudo rm -f /etc/systemd/system/codedeploy-agent.service # Remove systemd unit file
sudo rm -f /etc/init.d/codedeploy-agent # Remove init.d script for older systems
sudo rm -rf /var/log/aws/codedeploy-agent/ # Remove agent logs
sudo userdel codedeploy-agent 2>/dev/null || true # Remove agent user if it exists
sudo groupdel codedeploy-agent 2>/dev/null || true # Remove agent group if it exists

# --- Step 2: Update package lists and install prerequisites ---
echo "2. Updating package lists and installing prerequisites (ruby-full, wget)..."
sudo apt-get update -y
# ruby-full includes ruby-dev and necessary components. wget is for downloading.
sudo apt-get install -y ruby-full wget

# --- Step 3: Download the CodeDeploy agent installer ---
echo "3. Navigating to /tmp and downloading the latest CodeDeploy agent installer..."
cd /tmp || { echo "Failed to change directory to /tmp. Aborting."; exit 1; }
rm -f ./install # Remove any old installer script from /tmp
wget "https://aws-codedeploy-${AWS_REGION}.s3.${AWS_REGION}.amazonaws.com/latest/install" -O install || { echo "Failed to download installer. Aborting."; exit 1; }
chmod +x ./install

# --- Step 4 (Corrected): Run the CodeDeploy agent installer ---
echo "4. Running the CodeDeploy agent installer. Please watch for any errors from the installer itself."
# The 'auto' flag detects the OS. The installer downloaded from the regional S3 bucket
# is typically already configured for that region, so -r flag is not needed here.
sudo ./install auto || { echo "CodeDeploy agent installation failed. Aborting."; exit 1; }

# --- Step 5: Verify CodeDeploy Agent Status and Logs ---
echo "5. Verifying CodeDeploy agent service status..."
sudo systemctl status codedeploy-agent.service

echo "6. Displaying the last 50 lines of CodeDeploy agent logs for verification."
# The log path for Ubuntu is typically /opt/codedeploy-agent/log/codedeploy-agent.log
# If the agent is newly installed, this file might be empty or very small.
# Use journalctl as a more reliable source for systemd services.
sudo journalctl -u codedeploy-agent.service --since "5 minutes ago" --no-pager | tail -n 50

echo "CodeDeploy Agent installation script finished."
