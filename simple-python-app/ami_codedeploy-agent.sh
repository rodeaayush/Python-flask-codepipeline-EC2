#!/bin/bash

# ==============================================================================
# Script: golden_ami_provisioner.sh
# Description: Installs essential tools (AWS CLI, Docker, jq, CodeDeploy Agent)
#              on an Ubuntu/Debian EC2 instance for creating a Golden AMI.
# Usage:
#   1. Launch a fresh Ubuntu/Debian EC2 instance (e.g., t3.micro) in a public subnet.
#   2. SSH into the instance.
#   3. Create this file (e.g., 'provision.sh') and paste the content.
#   4. Make it executable: chmod +x provision.sh
#   5. Run it: ./provision.sh
#   6. Verify installations (see verification steps below).
#   7. Create AMI from this instance.
# ==============================================================================

# --- Configuration ---
# IMPORTANT: Set your AWS region here. This should match the region where your
# CodeDeploy application and EC2 instances will primarily operate.
AWS_REGION="ap-south-1" # <--- !!! REVIEW AND CHANGE IF NECESSARY !!!

# --- Pre-check & Environment ---
echo "--- Starting Golden AMI Provisioning Script ---"
echo "Running as user: $(whoami)"
echo "AWS Region set to: ${AWS_REGION}"

# Ensure we're running as root or have sudo privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script needs to be run with sudo or as root. Please run: sudo ./provision.sh"
   exit 1
fi

# Ensure all commands are executed within the script's directory for relative paths
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR" || { echo "Failed to change directory to script's location. Aborting."; exit 1; }

# --- Step 1: Update apt packages ---
echo ""
echo "--- Step 1: Updating apt packages and upgrading installed packages ---"
sudo apt update -y || { echo "apt update failed. Aborting."; exit 1; }
sudo apt upgrade -y || { echo "apt upgrade failed. Aborting."; exit 1; }
echo "apt packages updated."

# --- Step 2: Install AWS CLI v2 ---
echo ""
echo "--- Step 2: Installing AWS CLI v2 ---"
# Install prerequisites for AWS CLI installer
sudo apt install -y unzip curl || { echo "Failed to install unzip/curl. Aborting."; exit 1; }
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" || { echo "Failed to download awscliv2.zip. Aborting."; exit 1; }
unzip awscliv2.zip || { echo "Failed to unzip awscliv2.zip. Aborting."; exit 1; }
sudo ./aws/install --update || { echo "AWS CLI installation failed. Aborting."; exit 1; }
rm -rf awscliv2.zip aws/ # Clean up installer files
aws --version || { echo "AWS CLI verification failed. Aborting."; exit 1; }
echo "AWS CLI v2 installed successfully."

# --- Step 3: Install Docker ---
echo ""
echo "--- Step 3: Installing Docker ---"
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common || { echo "Failed to install Docker prerequisites. Aborting."; exit 1; }
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || { echo "Failed to add Docker GPG key. Aborting."; exit 1; }
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || { echo "Failed to add Docker repo. Aborting."; exit 1; }
sudo apt update -y || { echo "apt update after Docker repo failed. Aborting."; exit 1; }
sudo apt install -y docker-ce docker-ce-cli containerd.io || { echo "Failed to install Docker. Aborting."; exit 1; }

# Add current user to the docker group so 'docker' commands can be run without 'sudo'
# Important: This change takes effect after re-login or 'newgrp docker'
sudo usermod -aG docker "$(whoami)" || { echo "Failed to add user to docker group. Aborting."; exit 1; }
# Attempt to apply group change for the current session (might not always work without re-login)
newgrp docker 2>/dev/null || true # Suppress error if not in interactive shell

sudo systemctl enable docker || { echo "Failed to enable Docker service. Aborting."; exit 1; }
sudo systemctl start docker || { echo "Failed to start Docker service. Aborting."; exit 1; }
docker --version || { echo "Docker verification failed. Aborting."; exit 1; } # Verify as current user (after newgrp)
echo "Docker installed and started successfully."

# --- Step 4: Install jq (for JSON parsing) ---
echo ""
echo "--- Step 4: Installing jq ---"
sudo apt install -y jq || { echo "Failed to install jq. Aborting."; exit 1; }
jq --version || { echo "jq verification failed. Aborting."; exit 1; }
echo "jq installed successfully."

# --- Step 5: Install AWS CodeDeploy Agent and Dependencies (Robust Install) ---
echo ""
echo "--- Step 5: Installing AWS CodeDeploy Agent and Dependencies ---"
# Install Ruby and build essentials required for some Ruby gems (like 'json')
# We install 'build-essential' for compilers and 'nodejs' for a modern JS runtime.
sudo apt install -y ruby-full build-essential zlib1g-dev libffi-dev libssl-dev libreadline-dev libyaml-dev nodejs npm || { echo "Failed to install CodeDeploy agent prerequisites. Aborting."; exit 1; }
sudo gem install bundler --no-document || { echo "Failed to install bundler gem. Aborting."; exit 1; } # --no-document for faster install

# --- Aggressive Cleanup Before CodeDeploy Agent Re-installation ---
echo "Performing aggressive cleanup of any existing CodeDeploy agent components..."
sudo systemctl stop codedeploy-agent.service 2>/dev/null || true
sudo systemctl disable codedeploy-agent.service 2>/dev/null || true
sudo apt-get remove --purge codedeploy-agent -y 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true
sudo rm -rf /opt/codedeploy-agent/ # Main installation directory
sudo rm -f /etc/systemd/system/codedeploy-agent.service # systemd unit file
sudo rm -f /etc/init.d/codedeploy-agent # Old init.d script
sudo rm -rf /var/log/aws/codedeploy-agent/ # Agent logs
sudo userdel codedeployagent 2>/dev/null || true # Remove default agent user
sudo groupdel codedeployagent 2>/dev/null || true # Remove default agent group
sudo rm -f /usr/local/bin/codedeploy-agent # Symlink sometimes left behind
sudo rm -f /etc/codedeploy-agent/conf.d/credentials # Remove any leftover credentials
sudo rm -f /etc/codedeploy-agent/conf.d/onpremises.yml # Remove any on-premises config
echo "Cleanup complete."

# Download and run the CodeDeploy agent installer
echo "Downloading CodeDeploy agent installer..."
# Navigate to /tmp for installer download as it's a common temporary location
cd /tmp || { echo "Failed to change directory to /tmp. Aborting."; exit 1; }
rm -f ./install # Remove any old installer script from /tmp
wget "https://aws-codedeploy-${AWS_REGION}.s3.${AWS_REGION}.amazonaws.com/latest/install" -O install || { echo "Failed to download CodeDeploy installer. Aborting."; exit 1; }
chmod +x ./install || { echo "Failed to make CodeDeploy installer executable. Aborting."; exit 1; }

echo "Running CodeDeploy agent installer..."
# Run the installer, capturing logs to a file for detailed troubleshooting if it fails
sudo ./install auto > /tmp/codedeploy_install_detail.log 2>&1
if [ $? -ne 0 ]; then
    echo "CodeDeploy agent installation FAILED. See /tmp/codedeploy_install_detail.log for details."
    cat /tmp/codedeploy_install_detail.log
    exit 1 # Fail the script if agent installation fails
else
    echo "CodeDeploy agent installer completed successfully."
fi

# Manually ensure CodeDeploy service is enabled and started after installer runs
echo "Ensuring CodeDeploy agent service is enabled and started..."
sudo systemctl daemon-reload || { echo "systemctl daemon-reload failed. Aborting."; exit 1; }
sudo systemctl enable codedeploy-agent.service || { echo "Failed to enable CodeDeploy agent service. Aborting."; exit 1; }
sudo systemctl start codedeploy-agent.service || { echo "Failed to start CodeDeploy agent service. Aborting."; exit 1; }

# Verify CodeDeploy Agent Status
sudo service codedeploy-agent status || { echo "CodeDeploy agent status check failed. Aborting."; exit 1; }
echo "AWS CodeDeploy agent installed and running successfully."

# --- Step 6: Final Cleanup of installer files ---
echo ""
echo "--- Step 6: Cleaning up temporary installation files ---"
# Return to original script directory before final cleanup
cd "$SCRIPT_DIR" || { echo "Failed to return to original script directory. Skipping cleanup."; }
rm -f /tmp/install # Remove installer from /tmp
rm -f /tmp/codedeploy_install_detail.log # Remove detailed log file
echo "Temporary installation files cleaned up."

echo ""
echo "--- Golden AMI Provisioning Script Completed Successfully! ---"
echo "Please verify all installations manually and then proceed to create your AMI."
echo "Remember to re-login to pick up Docker group membership for $(whoami) if needed."
