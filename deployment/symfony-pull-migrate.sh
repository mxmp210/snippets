#!/bin/bash
##
# A quick shell script for repeated but small deployments
# Keep it in project root - set git on server and pull whenever new builds are required!
##

# Optional : Switch to your user is logged in as sudoer or root
# su - [user]

echo "Pulling code from branch 'main'"
# git pull origin main
chown -R $USER:$USER /var/www/project_root/
# setup ssh host for git
# Follow : https://docs.github.com/en/authentication/connecting-to-github-with-ssh
git pull ssh main

# For web root - follow your system config
echo "Setting up permissions..."
chown $USER:www-data /var/www/project_root/

echo "Installing Packages..."
composer install

echo "Migrating DB..."
php bin/console doctrine:migrations:migrate

echo "Clearing cache..."
php bin/console cache:clear

# Optional Build Assets
# echo "Installing Node packages..."
# npm install

# echo "Building Assets..."
# npm run build

# echo "Cleaning up..."
# rm -rf /var/www/project_root/node_modules

echo "Deployment Sucessful!"
