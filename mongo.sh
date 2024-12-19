user_data=<<-EOF
#!/bin/bash

#set -x

#MONGO_VERSION=7.0

# Update the system and install necessary packages
sudo apt-get update
sudo apt-get install gnupg -y

# Create the keyring directory and add the MongoDB GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/mongodb-7.0.gpg

# Add the MongoDB repository
cd /etc/apt/sources.list.d/
sudo touch mongodb-org-7.0.list
echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/mongodb-7.0.gpg] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Update package lists again after adding the MongoDB repo
sudo apt-get update

# Add Ubuntu security repo
echo "deb http://security.ubuntu.com/ubuntu focal-security main" | sudo tee /etc/apt/sources.list.d/focal-security.list
sudo apt-get update

# Install libssl1.1 and MongoDB
sudo apt-get install libssl1.1
sudo apt-get install -y mongodb-org

# Ensure the MongoDB data directory exists and has the correct permissions
if [ ! -d "/data/db" ]; then
  echo "Creating the MongoDB data directory /data/db..."
  sudo mkdir -p /data/db
  sudo chown -R mongodb:mongodb /data/db
fi

# Start and enable MongoDB service
sudo systemctl start mongod
sudo systemctl enable mongod

# Wait for MongoDB to fully start before creating the user
sleep 10

# Create the admin user with authorization using mongosh
echo "Creating MongoDB admin user..."
mongosh --eval 'db.createUser({ user: "admin", pwd: "adminadmin", roles: [{ role: "root", db: "admin" }] })'
# Enable authentication in MongoDB config (if not already done)
echo "Enabling MongoDB authentication..."
sudo sed -i 's/#security:/security:/g' /etc/mongod.conf
sudo sed -i '/security:/a \  authorization: "enabled"' /etc/mongod.conf

# Change MongoDB bindIp to 0.0.0.0 to allow connections from any IP
echo "Updating MongoDB bindIp to 0.0.0.0 to allow external connections..."
sudo sed -i "s/bindIp: 127.0.0.1/bindIp: 0.0.0.0/g" /etc/mongod.conf

# Restart MongoDB to apply changes
sudo systemctl restart mongod

echo "MongoDB installation and setup complete with authentication enabled and bindIp set to 0.0.0.0!"
EOF
