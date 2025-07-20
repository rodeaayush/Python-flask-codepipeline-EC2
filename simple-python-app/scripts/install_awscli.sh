#!/bin/bash
set -euxo pipefail # Exit on error, exit on unset variables, print commands, exit on pipe fail

echo "Checking for AWS CLI installation..."
if ! command -v aws &> /dev/null
then
    echo "AWS CLI not found. Attempting installation..."

    # Determine OS and try system package manager first (apt/yum)
    if [ -f /etc/os-release ]; then
        . /etc/os-release # Source the file to get ID (e.g., ubuntu, amzn)

        if [ "$ID" = "ubuntu" ] || [ "$ID" = "debian" ]; then
            sudo apt-get update
            if sudo apt-get install -y awscli; then # Attempt apt install
                echo "AWS CLI installed successfully via apt."
            else
                echo "apt-get install awscli failed. Trying pip install as fallback..."
                # Fallback to pip install for Ubuntu/Debian if apt fails for awscli
                sudo apt-get install -y python3-pip || { echo "ERROR: python3-pip installation failed via apt."; exit 1; }
                # ADDED --break-system-packages here
                sudo pip3 install awscli --break-system-packages || { echo "ERROR: pip3 install awscli failed."; exit 1; }
                echo "AWS CLI installed successfully via pip."
            fi
        elif [ "$ID" = "amzn" ]; then # Amazon Linux
            sudo yum update -y
            if sudo yum install -y awscli; then # Attempt yum install
                echo "AWS CLI installed successfully via yum."
            else
                echo "yum install awscli failed. Trying pip install as fallback..."
                sudo yum install -y python3-pip || { echo "ERROR: python3-pip installation failed via yum."; exit 1; }
                # ADDED --break-system-packages here
                sudo pip3 install awscli --break-system-packages || { echo "ERROR: pip3 install awscli failed."; exit 1; }
                echo "AWS CLI installed successfully via pip."
            fi
        else # Generic fallback for unknown OS (will directly try pip)
            echo "Unsupported OS for direct apt/yum install. Attempting pip install directly."
            sudo apt-get update || true # Try to update apt even if not Ubuntu/Debian, allow failure
            sudo apt-get install -y python3-pip || sudo yum install -y python3-pip || { echo "ERROR: python3-pip installation failed; cannot proceed with awscli pip install."; exit 1; }
            # ADDED --break-system-packages here
            sudo pip3 install awscli --break-system-packages || { echo "ERROR: pip3 install awscli failed."; exit 1; }
            echo "AWS CLI installed successfully via pip."
        fi
    else # Fallback if /etc/os-release is not found
        echo "Could not determine OS. Attempting pip install as a fallback."
        sudo apt-get update || true
        sudo apt-get install -y python3-pip || sudo yum install -y python3-pip || { echo "ERROR: python3-pip installation failed; cannot proceed with awscli pip install."; exit 1; }
        # ADDED --break-system-packages here
        sudo pip3 install awscli --break-system-packages || { echo "ERROR: pip3 install awscli failed."; exit 1; }
        echo "AWS CLI installed successfully via pip."
    fi

    # Final check after all installation attempts
    if ! command -v aws &> /dev/null
    then
        echo "ERROR: AWS CLI is not installed after all attempts. Deployment cannot proceed."
        exit 1 # Fail the script if AWS CLI is still not found
    fi
    echo "AWS CLI verified as installed and ready."
else
    echo "AWS CLI already installed. Skipping installation."
fi
