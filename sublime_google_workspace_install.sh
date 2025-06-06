#!/bin/bash
# Sublime Platform Google Workspace Deployment Script
# Author: Logan Gatts
# Date: 06/06/2025

#output coloring
RED="31"
GREEN="32"
BOLDRED="\e[1;${RED}m"
BOLDGREEN="\e[1;${GREEN}m"
ENDCOLOR="\e[0m"

#get the tf file
echo "Getting Terraform Files..." | tee -a $LOG_FILE
git clone https://github.com/logangatts/sublime.git | tee -a $LOG_FILE

#change into that cloned dir
cd sublime

#create log folder and log file
mkdir logs
LOG_FILE="logs/sublime_$(date +%F_%T).log"

echo "Initializing Terraform..." | tee -a $LOG_FILE
if ! terraform init 2>&1 | tee -a $LOG_FILE; then
  echo -e "${BOLDRED}Error during terraform init. Exiting...${ENDCOLOR}" | tee -a $LOG_FILE
  exit 1
fi

#autoapprove tf
echo "Applying Terraform..." | tee -a $LOG_FILE
if ! terraform apply -auto-approve 2>&1 | tee -a $LOG_FILE; then
  echo -e "${BOLDRED}Error during terraform apply. Exiting...${ENDCOLOR}" | tee -a $LOG_FILE
  exit 1
fi

#tf
#echo "Applying Terraform..." | tee -a $LOG_FILE
#if ! terraform apply 2>&1 | tee -a $LOG_FILE; then
#  echo -e "${BOLDRED}Error during terraform apply. Exiting...${ENDCOLOR}" | tee -a $LOG_FILE
#  exit 1
#fi

#output to console success
echo -e "${BOLDGREEN}Terraform process completed successfully.${ENDCOLOR}" | tee -a $LOG_FILE

#output to console the json to the console and save a copy
echo "Below is the Service Account JSON to be used for Sublime setup. Also saved as sublime_sa.json"
terraform output sa_key &> sublime_sa.json  
