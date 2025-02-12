#!/bin/bash

# Script to generate deploy keys for Visidian repositories
if [ -z "$1" ] || [ -z "$2" ]
then
  echo "Make sure to pass in both parameters REPO_OWNER_NAME and REPO_NAME. Example:"
  echo "./generate_deploy_key.sh yourname hello_world"
else
  REPO_OWNER_NAME=$1
  REPO_NAME=$2
  KEY_PATH=~/.ssh/id_rsa.visidian_${REPO_NAME}
  echo "Generating ssh key at ${KEY_PATH}"
  ssh-keygen -t ed25519 -N "" -f ${KEY_PATH}
  echo "Your ssh deploy key is:"
  PUB_KEY_PATH=$KEY_PATH".pub"
  cat $PUB_KEY_PATH
  echo ""
  # Will create config if it does not exist
  echo "Updating ~/.ssh/config"
  DATE_TIME=$(date +"%Y-%m-%d at %r")
  echo "
# Visidian Key Generated on $DATE_TIME
Host github.com-visidian_${REPO_NAME}
    HostName github.com
    User git
    IdentityFile $KEY_PATH" >> ~/.ssh/config
  echo ""
  echo "Here is your hostname's alias to interact with the repository using SSH:"
  echo "git clone git@github.com-visidian_${REPO_NAME}:$REPO_OWNER_NAME/$REPO_NAME.git"
  
  # Set proper permissions
  chmod 600 ${KEY_PATH}
  chmod 644 ${PUB_KEY_PATH}
  
  # Create Visidian configuration snippet
  echo ""
  echo "Add this to your .vimrc:"
  echo "let g:visidian_git_repo_url = 'git@github.com-visidian_${REPO_NAME}:${REPO_OWNER_NAME}/${REPO_NAME}.git'"
  echo "let g:visidian_deploy_key = '${KEY_PATH}'"
fi
