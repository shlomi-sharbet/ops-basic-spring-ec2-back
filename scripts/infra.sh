#!/bin/bash
# Wrapper to manage Terraform/tflocal infrastructure

ACTION=$1

# Activate Python Virtual Environment if it exists to ensure tflocal and localstack are in PATH
if [ -f "$HOME/venv/bin/activate" ]; then
  source "$HOME/venv/bin/activate"
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TF_DIR="$SCRIPT_DIR/../terraform"

case "$ACTION" in
  start)
    echo "🚀 Starting LocalStack..."
    localstack start -d
    
    echo "🏁 Initializing Terraform..."
    cd "$TF_DIR" || exit 1
    tflocal init
    tflocal apply -auto-approve
    
    echo "🔒 Copying SSH key and setting permissions..."
    rm -f ~/ec2_key_pair.pem
    cp ec2_key_pair.pem ~
    chmod 400 ~/ec2_key_pair.pem
    
    echo "✨ Infrastructure is ready!"
    ;;
  stop)
    echo "🧹 Tearing down infrastructure..."
    cd "$TF_DIR" || exit 1
    tflocal destroy -auto-approve
    ;;
  ssh)
    echo "🔌 Connecting to mock EC2..."
    ssh -i ~/ec2_key_pair.pem testuser@localhost
    ;;
  ssh-root)
    echo "🔌 Connecting as root..."
    ssh -i ~/ec2_key_pair.pem root@localhost
    ;;
  tunnel)
    echo "🚇 Establishing SSH Tunnel on port 5555..."
    ssh -i ~/ec2_key_pair.pem -L 5555:localhost:5555 root@localhost
    ;;
  *)
    echo "Usage: $0 {start|stop|ssh|ssh-root|tunnel}"
    exit 1
    ;;
esac
