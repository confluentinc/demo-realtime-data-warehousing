#!/bin/bash

# Source the .env file
source .env
sleep_time=2

# Use confluent environment
confluent login --save
export CCLOUD_ENV_ID=$(confluent environment list -o json \
    | jq -r '.[] | select(.name | contains('\"${CCLOUD_ENV_NAME:-Demo_Real_Time_Data_Warehousing}\"')) | .id')

confluent env use $CCLOUD_ENV_ID

# Use kafka cluster
export CCLOUD_CLUSTER_ID=$(confluent kafka cluster list -o json \
    | jq -r '.[] | select(.name | contains('\"${CCLOUD_CLUSTER_NAME:-demo_kafka_cluster}\"')) | .id')

confluent kafka cluster use $CCLOUD_CLUSTER_ID

# Get cluster bootstrap endpoint
export CCLOUD_BOOTSTRAP_ENDPOINT=$(confluent kafka cluster describe -o json | jq -r .endpoint)
STRIPPED_CCLOUD_BOOTSTRAP_ENDPOINT=$(echo $CCLOUD_BOOTSTRAP_ENDPOINT | sed 's/SASL_SSL:\/\///')

# use sed to replace kafka-cluster-endpoint with the replacement string
sed -i .bak "s/kafka-cluster-endpoint/$STRIPPED_CCLOUD_BOOTSTRAP_ENDPOINT/g" .env
sleep $sleep_time

# Create an API key pair to use for connectors
echo "Creating Kafka cluster API key"
CREDENTIALS=$(confluent api-key create --resource $CCLOUD_CLUSTER_ID --description "demo-database-modernization" -o json)
kafka_api_key=$(echo $CREDENTIALS | jq -r '.api_key')
kafka_api_secret=$(echo $CREDENTIALS | jq -r '.api_secret')
sleep $sleep_time

# # print the values
echo "API key: $kafka_api_key"
echo "API secret: $kafka_api_secret"

# use sed to replace all instances of $kafka_api_key with the replacement string
sed -i .bak "s^api-key^\"$kafka_api_key\"^g" .env 
sed -i .bak "s^api-secret^\"$kafka_api_secret\"^g" .env 

sleep $sleep_time

# Read values from resources.json and update the .env file.
# These resources are created by Terraform
json=$(cat resources.json)

postgres_customers=$(echo "$json" | jq -r '.postgres_instance_customers_public_endpoint.value')
postgres_products=$(echo "$json" | jq -r '.postgres_instance_products_public_endpoint.value')

raw_snowflake_svc_private_key=$(echo "$json" | jq -r '.snowflake_svc_private_key.value')
snowflake_svc_private_key=$(echo "$raw_snowflake_svc_private_key" | sed '/-----BEGIN RSA PRIVATE KEY-----/d; /-----END RSA PRIVATE KEY-----/d' | tr -d '\n')


# echo $postgres_customers
# echo $postgres_products
# echo $snowflake_svc_private_key


# Updating the .env file with sed command
sed -i .bak "s^postgres-customers^$postgres_customers^g" .env 
sed -i .bak "s^postgres-products^$postgres_products^g" .env 
sed -i .bak "s^snowflake-private-key^\"$snowflake_svc_private_key\"^g" .env 


sleep $sleep_time

#source the .env file 
echo "Sourcing the .env file"
source .env

