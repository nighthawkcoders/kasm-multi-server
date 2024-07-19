#!/bin/bash

setup_nginx=0

# Load environment variables from .envnginx
if [ -f .envnginx ]; then
    setup_nginx=$(grep setup_nginx .envnginx | cut -d '=' -f2)
    domain=$(grep domain .envnginx | cut -d '=' -f2)
    email=$(grep email .envnginx | cut -d '=' -f2)
else
    setup_nginx=0
fi

# Load environment variables from .envservers or prompt user if not found
if [ -f .envservers ]; then
    web_server_ip=$(grep web_server_ip .envservers | cut -d '=' -f2)
    key_file=$(grep key_file .envservers | cut -d '=' -f2)
else
    web_server_ip=""
    key_file=""
fi

if [ "$setup_nginx" -eq 0 ]; then
    echo "Skipping Nginx configuration..."
fi

if [ "$setup_nginx" -eq 1 ]; then
    # If blank enter in
    if [ -z "$web_server_ip" ]; then
        read -p "Enter the web server IP: " web_server_ip
    fi

    if [ -z "$key_file" ]; then
        read -p "Enter the SSH key file: " key_file
    fi
    if [ -z "$domain" ]; then
        read -p "Enter the domain you want to set up: " domain
    fi
    if [ -z "$email" ]; then
        read -p "Enter the email address you want to set up: " email
    fi
    echo "Do route53 on the web server ip for the domain you set..."
    echo "Web server ip: $web_server_ip"
    echo "Domain: $domain"
    read -p "Are you done? (press ENTER) " done
fi

if [ "$setup_nginx" -eq 1 ]; then
    ssh -i "$key_file" ubuntu@"$web_server_ip" <<EOF
echo "Nginx Installation"
sudo apt-get update
sudo apt-get install -y nginx

echo "Certbot Installation"
sudo snap install core
sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

echo "Nginx setup"
sudo bash -c 'cat <<EOT > "/etc/nginx/sites-available/kasm.conf"
server {
    server_name $domain;
    listen 80;

    location / {
         # The following configurations must be configured when proxying to Kasm Workspaces

         # WebSocket Support
         proxy_set_header        Upgrade \$http_upgrade;
         proxy_set_header        Connection "upgrade";

         # Host and X headers
         proxy_set_header        Host \$host;
         proxy_set_header        X-Real-IP \$remote_addr;
         proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
         proxy_set_header        X-Forwarded-Proto \$scheme;

         # Connectivity Options
         proxy_http_version      1.1;
         proxy_read_timeout      1800s;
         proxy_send_timeout      1800s;
         proxy_connect_timeout   1800s;
         proxy_buffering         off;

         # Allow large requests to support file uploads to sessions
         client_max_body_size 10M;

         # Proxy to Kasm Workspaces running locally on 8443 using ssl
         proxy_pass https://127.0.0.1:8443 ;
     }
}
EOT'

echo "Nginx start"
sudo ln -s /etc/nginx/sites-available/kasm.conf /etc/nginx/sites-enabled/
sudo systemctl start nginx

echo "Certbot activate"
sudo certbot --nginx --noninteractive --agree-tos -m $email -d $domain
EOF
fi


