#!/bin/bash

# Ubuntu 20.04 - Fresh Installed Server - Setup N8n w/ Caddy server
# Author: Ed Chalon https://github.com/edward-chalon/handy-scripts/n8n
#                   https://www.linkedin.com/in/edward-chalon/
# Sets up Ubuntu, PM2, Caddy, and sets up an SSL. Tries to automate as much of the setup as possible.
#   The key to a happy end user base, is a happy end user base because setup was easy :)
#   Have ideas for other useful scripts? Open a feature request, and ill take a look!

#Tested with DigitalOcean VPS. I cant imagine why this wouldnt work with AWS/ GCP/ Azure with Ubuntu 20.04

echo "WARNING - Make sure that prior to filling out what this script needs to work, that you have pointed an A record in your domain registrar to the IP of this server  "

#1. Setup some vars for what we need...

serverURL="serverURL"
dbName="n8n" #This is a fresh install, and we are installing n8n - so, it defaults to n8n - You can change it to what you want it to be though, here.
dbUsername="postgres" #Keeping the standard postgres un
dbPassword="dbPassword"
n8nUsername="n8nUsername"
n8nPassword="n8nPassword"
scriptUser=$USER

# and lets fill those vars!
echo "First, lets get some details..."

read -p "Whats the URL of the server we are going to setup SSL for? (example: n8n.edwardchalon.com OR edwardchalon.com:   " serverURL
read -p "What do you want the password for the postgreSQL DB? (default username of postgres will be used)   " dbPassword
read -p "What do you want to use for the n8n Admin Username to login?   " n8nUsername
read -p "What do you want to use for the n8n Admin Password to login?   " n8nPassword

#Check if any of the variables are empty
if [ -z "${serverURL}" ] || [ -z "${dbName}" ] || [ -z "${dbUsername}" ] || [ -z "${dbPassword}" ] || [ -z "${n8nUsername}" ] || [ -z "${n8nPassword}" ]; then
    echo "All of your details need to be filled out to continue. Try again :) "
    exit 1
fi
secureServerURL="https://${serverURL}"

#2. Prepare Ubuntu
echo "Alrighty, moving on - we are going to do some housekeeping first."
echo "Update Ubuntu"
sudo apt update

echo "Update Ubuntu"
sudo apt upgrade -y

#3. Get the needed things for the DB...
echo "Fetch, and install PostgreSQL items..."
sudo apt install -y postgresql postgresql-client jq

#4. At this point, PostgreSQL should be running..lets check to see
STATUS="$(systemctl is-active postgresql.service)"
if [ "${STATUS}" = "active" ]; then
    echo " PostgreSQL is setup, continuing! "
else 
    echo " PostgreSQL not running.... so exiting - need to investigate, as the rest of the script will have trouble executing as a result "  
    exit 1  
fi

#Update postgres un password...
echo -e "${dbPassword}\n${dbPassword}" | sudo -S passwd postgres

su -c "cd ~ ; psql -c \"ALTER USER postgres WITH PASSWORD '${dbPassword}'\" ; createdb ${dbName} " -m "postgres" 

#5. Now, we need NodeJS
#echo "Moving to home, setting up n8n directory"
cd ~
echo "Installing NodeJS..."
curl -sL https://deb.nodesource.com/setup_16.x -o nodesource_setup.sh
sudo bash nodesource_setup.sh
sudo apt install -y nodejs
echo "Installed NodeJS, Version: "
node -v

#6. Lets get PM2 setup
echo "Cool beans, now that you have NodeJS. Lets install PM2..."
npm install pm2@latest -g
# If Ubuntu reboots, reboot Pm2 with N8N as well
pm2 startup

echo "Installing n8n..."
#7. Setup N8N with PM2
npm install n8n -g
#Startup N8N
pm2 start n8n
N8N_BASIC_AUTH_ACTIVE=true N8N_BASIC_AUTH_USER=${n8nUsername} N8N_BASIC_AUTH_PASSWORD=${n8nPassword} DB_TYPE=postgresdb DB_POSTGRESDB_DATABASE=${postgresDB} DB_POSTGRESDB_HOST=localhost DB_POSTGRESDB_PORT=5432 DB_POSTGRESDB_USER=${dbUsername} DB_POSTGRESDB_PASSWORD=${dbPassword} pm2 restart n8n --update-env

#Save PM2 Processes...
pm2 save

#8. Lets get CaddyServer Setup
echo "Alright, now that we have PM2 lets get CaddyServer..."
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo tee /etc/apt/trusted.gpg.d/caddy-stable.asc
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy
echo "Setting up Caddy now that we have the server installed..."

# Setup the reverse proxy...
# write a default Caddyfile
cat <<EOM | sudo tee Caddyfile
${secureServerURL} {
    reverse_proxy * localhost:5678 
}
EOM
#and now start it up
# start Caddy service
sudo systemctl start caddy
sudo systemctl enable caddy

echo "Wait 10 seconds..."
sleep 10

sudo systemctl restart caddy

echo "Last wait of 10 seconds..."
sleep 10

echo "  "
echo "  "
echo " All Done! Since you're here, load up your server url at ${serverURL} - and you should be off to the races. Thanks for using this script! " 