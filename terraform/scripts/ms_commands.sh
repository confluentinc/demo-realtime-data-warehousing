#!/bin/sh

echo "Starting..." >> startup.log
echo "Updating yum..." >> startup.log
sudo yum update -y
echo "Updated yum." >> startup.log
echo "Installing docker..." >> startup.log
sudo yum install docker -y
echo "Docker installed." >> startup.log
echo "Starting docker service..." >> startup.log
sudo service docker start
echo "Docker service started." >> startup.log
echo "Starting postgres container..." >> startup.log
sudo docker run -p 3306:3306 --name mysql -d zachhamilton/rt-dwh-mysql
echo "Started postgres container in the background." >> startup.log
echo "Done..." >> startup.log