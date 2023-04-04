#!/bin/bash

# Source the .env file
source .env

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

# Get the ID for all connectors
postregs_customers_id=$(confluent connect cluster list -o json | jq -r '.[] | select(.name | contains ("PostgresCdcSource_Customers")) | .id')
postgres_products_id=$(confluent connect cluster list -o json | jq -r '.[] | select(.name | contains ("PostgresCdcSource_Products")) | .id')
snowflake_id=$(confluent connect cluster list -o json | jq -r '.[] | select(.name | contains ("SnowflakeSinkConnector_0")) | .id')

# Delete all connectors
echo "Deleting connectors..."
confluent connect cluster delete --force "$postregs_customers_id"
confluent connect cluster delete --force "$postgres_products_id"
confluent connect cluster delete --force "$snowflake_id"
