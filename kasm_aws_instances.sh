#!/bin/bash

# Prompt user for inputs
read -p "Enter AWS region: " region
read -p "Enter the number of agent servers (default 1): " agent_server_count
read -p "Enter the size of agent servers (default t3.medium): " agent_server_size
read -p "Enter the size of other servers (DB, Guac, Web) (default t3.medium): " other_server_size
read -p "Enter the disk size of agent servers in GB (default 50): " agent_server_disk_size
read -p "Enter the disk size of other servers (DB, Guac, Web) in GB (default 50): " other_server_disk_size
read -p "Enter custom AMI ID if region-specific AMI is not available (leave blank if not needed): " custom_ami

# Prompt user for passwords with default values
read -p "Enter user password [default: password]: " user_password
user_password=${user_password:-password}

read -p "Enter admin password [default: password]: " admin_password
admin_password=${admin_password:-password}

read -p "Enter database password [default: password]: " database_password
database_password=${database_password:-password}

read -p "Enter redis password [default: password]: " redis_password
redis_password=${redis_password:-password}

read -p "Enter manager token [default: password]: " manager_token
manager_token=${manager_token:-password}

read -p "Enter registration token [default: password]: " registration_token
registration_token=${registration_token:-password}

# Set default values if not provided
agent_server_count=${agent_server_count:-1}
agent_server_size=${agent_server_size:-"t3.medium"}
other_server_size=${other_server_size:-"t3.medium"}
agent_server_disk_size=${agent_server_disk_size:-50}
other_server_disk_size=${other_server_disk_size:-50}

# Initialize variables for Nginx setup
domain=""
email=""

# Prompt for Nginx setup
read -p "Do you want to set up Nginx? (0 to skip, 1 to setup) [default: 0]: " setup_nginx
setup_nginx=${setup_nginx:-0}

if [ "$setup_nginx" -eq 1 ]; then
  read -p "Enter the domain name (e.g., example.com): " domain
  read -p "Enter your email for Certbot: " email
fi

# Save Nginx inputs to .envnginx
cat <<EOF > .envnginx
setup_nginx=$setup_nginx
domain=$domain
email=$email
EOF

# Save inputs to .envinputs
cat <<EOF > .envinputs
region=$region
agent_server_count=$agent_server_count
agent_server_size=$agent_server_size
other_server_size=$other_server_size
agent_server_disk_size=$agent_server_disk_size
other_server_disk_size=$other_server_disk_size
custom_ami=$custom_ami
user_password=$user_password
admin_password=$admin_password
database_password=$database_password
redis_password=$redis_password
manager_token=$manager_token
registration_token=$registration_token
EOF

# Initialize Terraform
terraform init

if [ -z "$custom_ami" ]; then
  terraform apply -var="region=$region" -var="agent_server_count=$agent_server_count" -var="agent_server_size=$agent_server_size" -var="other_server_size=$other_server_size" -var="agent_server_disk_size=$agent_server_disk_size" -var="other_server_disk_size=$other_server_disk_size" -auto-approve
else
  terraform apply -var="region=$region" -var="agent_server_count=$agent_server_count" -var="agent_server_size=$agent_server_size" -var="other_server_size=$other_server_size" -var="agent_server_disk_size=$agent_server_disk_size" -var="other_server_disk_size=$other_server_disk_size" -var="custom_ami=$custom_ami" -auto-approve
fi

# Capture IP addresses from Terraform output
agent_server_ips=$(terraform output -json agent_server_ips | jq -r '.[]' | tr '\n' ',')
agent_server_ips=${agent_server_ips%,} # Remove the trailing comma

db_server_ip=$(terraform output -json db_server_ip | jq -r '.')
guac_server_ip=$(terraform output -json guac_server_ip | jq -r '.')
web_server_ip=$(terraform output -json web_server_ip | jq -r '.')

# Store IP addresses in .envservers
cat <<EOF > .envservers
agent_server_ips=$agent_server_ips
db_server_ip=$db_server_ip
guac_server_ip=$guac_server_ip
web_server_ip=$web_server_ip
EOF

# Get the generated key file name
key_name=$(terraform output -raw key_name)
key_file="${key_name}.pem"
echo "key_file=$key_file" >> .envservers
