#!/bin/bash
apt update -y
apt install -y apache2
service apache2 start
echo "Hi Gokul" > /var/www/html/index.html
