#!/bin/sh

echo "Starting..." >> startup.log
echo "Updating apt-get..." >> startup.log
sudo apt-get update -y &&
sudo apt-get install -y \
apt-transport-https \
ca-certificates \
curl \
gnupg-agent \
software-properties-common &&
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - &&
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" &&
sudo apt-get update -y &&
sudo sudo apt-get install docker-ce docker-ce-cli containerd.io -y &&
sudo usermod -aG docker ubuntu
sudo chmod 666 /var/run/docker.sock

sudo service docker start
echo "Docker service started." >> startup.log
echo "Starting postgres container..." >> startup.log

sudo docker run -p 5432:5432 --name postgres -d zachhamilton/rt-dwh-postgres-products
echo $? >> startup.log
echo "Started postgres container in the background." >> startup.log
echo "Starting postgres readiness checks..." >> startup.log
PG_READY=1
while [ $PG_READY -ne 0 ]; do
    sudo docker exec postgres pg_isready
    PG_READY=$?
    sleep 1
done
echo "Completed postgres readniness checks." >> startup.log
echo "Sleeping for 20 seconds..." >> startup.log
echo "--------------------------------------"
sleep 20

echo "Starting postgres procedures..." >> startup.log
echo "Starting generate_orders()..." >> startup.log
sudo docker exec -d postgres psql -U postgres postgres -c 'CALL products.generate_orders();'
echo $? >> startup.log
echo "Starting change_prices()..." >> startup.log 
sudo docker exec -d postgres psql -U postgres postgres -c 'CALL products.change_prices();'
echo $? >> startup.log
echo "Started postgres procedures in the background." >> startup.log
echo "Done..." >> startup.log