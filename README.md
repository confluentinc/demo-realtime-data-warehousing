<div align="center" padding=25px>
    <img src="images/confluent.png" width=50% height=50%>
</div>

# <div align="center">Realtime Data Warehousing with Confluent Cloud</div>

## <div align="center">Workshop & Lab Guide</div>

## Background

To turn data into insight, organizations often run ETL or ELT pipelines from operational databases into a data warehouse.
However, ETL and ELT are built around batch processes, which result in low-fidelity snapshots, inconsistencies, and data
systems with stale information—making any subsequent use of the data instantly outdated. Unlocking real-time insights
requires a streaming architecture that’s continuously ingesting, processing, and provisioning data in real time.
This demo walks you through building streaming data pipelines with Confluent Cloud. You'll learn about:

- Confluent’s fully managed PostgresSQL CDC Source connector to stream customer data in real time to Confluent Cloud
- ksqlDB to process and enrich data in real time, generating a unified view of customers’ shopping habits
- A fully managed sink connector to load the enriched data into Snowflake for subsequent analytics and reporting

Start streaming on-premises, hybrid, and multicloud data in minutes. Confluent streaming data pipelines connect, process,
and govern real-time data flows to and from your data warehouse. Use fresh, enriched data to power real-time operational
and analytical use cases.

To learn more about Confluent’s solution, visit the [Data Warehouse streaming pipelines page](https://www.confluent.io/use-case/data-warehouse/).

---

## Architecture Diagram

This demo utilizes two fully-managed source connectors (PostgreSQL CDC) and one fully-managed sink connector (Snowflake).

<div align="center"> 
  <img src="images/Realtime-data-warehousing.png" width =100% heigth=100%>
</div>

---

## Prerequisites

Get a Confluent Cloud account if you don't have one. New accounts start with $400 in credits and do not require a credit card. [Get Started with Confluent Cloud for Free](https://www.confluent.io/confluent-cloud/tryfree/).

You'll need a couple tools that make setup go a lot faster. Install these first.

- `git`
- Docker
- Terraform
  - Special instructions for Apple M1 users are [here](./terraform/running-terraform-on-M1.md)

This repo uses Docker and Terraform to deploy your source databases to a cloud provider. What you need for this tutorial varies with each provider.

- AWS
  - A user account (use a testing environment) with permissions to create resources
  - An API Key and Secret to access the account from Confluent Cloud
- GCP
  - A test project in which you can create resources
  - A user account with a JSON Key file and permission to create resources
- Azure
  - A Service Principal account
  - A SSH key-pair

To sink streaming data to your warehouse, we support Snowflake and Databricks. This repo assumes you can have set up either account and are familiar with the basics of using them.

- Snowflake

  - Create a free account on Snowflake [website](https://www.snowflake.com/en/).
  - Your account must reside in the same region as your Confluent Cloud environment. This demo is configured for aws-us-west-2.

- Databricks _(AWS only)_

  - Your account must reside in the same region as your Confluent Cloud environment
  - You'll need an S3 bucket the Delta Lake Sink Connector can use to stage data (detailed in the link below)
  - Review [Databricks' documentation to ensure proper setup](https://docs.confluent.io/cloud/current/connectors/cc-databricks-delta-lake-sink/databricks-aws-setup.html)

- Confluent Cloud

1. Sign up for a Confluent Cloud account [here](https://www.confluent.io/get-started/).
1. After verifying your email address, access Confluent Cloud sign-in by navigating [here](https://confluent.cloud).
1. When provided with the _username_ and _password_ prompts, fill in your credentials.

   > **Note:** If you're logging in for the first time you will see a wizard that will walk you through the some tutorials. Minimize this as you will walk through these steps in this guide.

---

## Setup

This demo uses Terraform and bash scripting to create and teardown infrastructure and resources.

1. Clone and enter this repo.

   ```bash
   git clone https://github.com/confluentinc/demo-realtime-data-warehousing
   cd demo-realtime-data-warehousing
   ```

1. Create a file to manage all the values you'll need through the setup.

   ```bash
   cat << EOF > env.sh
   CONFLUENT_CLOUD_EMAIL=<replace>
   CONFLUENT_CLOUD_PASSWORD=<replace>

   CCLOUD_API_KEY=api-key
   CCLOUD_API_SECRET=api-secret
   CCLOUD_BOOTSTRAP_ENDPOINT=kafka-cluster-endpoint

   # AWS Creds for TF
   export AWS_ACCESS_KEY_ID="<replace>"
   export AWS_SECRET_ACCESS_KEY="<replace>"
   export AWS_DEFAULT_REGION="us-west-2"

   # GCP Creds for TF
   export TF_VAR_GCP_PROJECT=""
   export TF_VAR_GCP_CREDENTIALS=""

   POSTGRES_CUSTOMERS_ENDPOINT=postgres-customers
   POSTGRES_PRODUCTS_ENDPOINT=postgres-products

   export TF_VAR_confluent_cloud_api_key="<replace>"
   export TF_VAR_confluent_cloud_api_secret="<replace>"

   export SNOWFLAKE_USER="tf-snow"
   export SNOWFLAKE_PRIVATE_KEY_PATH="~/.ssh/snowflake_tf_snow_key.p8"
   export SNOWFLAKE_ACCOUNT="YOUR_ACCOUNT_LOCATOR"
   SF_PVT_KEY=snowflake-private-key
   EOF
   ```

   > **Note:** _Run `source .env` at any time to update these values in your terminal session. Do NOT commit this file to a GitHub repo._

### Confluent Cloud

1. Create Confluent Cloud API keys by following [this](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/guides/sample-project#summary) guide.

   > **Note:** This is different than Kafka cluster API keys.

1. Update your `.env` file and add the newly created credentials for the following variables
   TF_VAR_confluent_cloud_api_key
   TF_VAR_confluent_cloud_api_secret

### Snowflake

1. Navigate to the Snowflake directory.
   ```bash
   cd demo-realtime-data-warehousing/snowflake
   ```
1. Create an RSA key for Authentication. This creates the private and public keys we use to authenticate the service account we will use for Terraform.
   ```bash
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out snowflake_tf_snow_key.p8 -nocrypt
   openssl rsa -in snowflake_tf_snow_key.p8 -pubout -out snowflake_tf_snow_key.pub
   ```
1. Log in to the Snowflake console and create the user account by running the following command as the `ACCOUNTADMIN` role.

   But first:

   - Copy the text contents of the `snowflake_tf_snow_key.pub` file, starting after the PUBLIC KEY header, and stopping just before the PUBLIC KEY footer.
   - Paste over the RSA_PUBLIC_KEY_HERE label (shown below).

1. Execute both of the following SQL statements to create the User and grant it access to the `SYSADMIN` and `SECURITYADMIN` roles needed for account management.

   ```sql
   CREATE USER "tf-snow" RSA_PUBLIC_KEY='RSA_PUBLIC_KEY_HERE' DEFAULT_ROLE=PUBLIC MUST_CHANGE_PASSWORD=FALSE;
   GRANT ROLE SYSADMIN TO USER "tf-snow";
   GRANT ROLE SECURITYADMIN TO USER "tf-snow";
   ```

   > **Note:** We grant the user `SYSADMIN` and `SECURITYADMIN` privileges to keep the lab simple. An important security best practice, however, is to limit all user accounts to least-privilege access. In a production environment, this key should also be secured with a secrets management solution like Hashicorp Vault, Azure Key Vault, or AWS Secrets Manager.

1. Run the following to find the `YOUR_ACCOUNT_LOCATOR` and your Snowflake Region ID values needed.

   ```sql
   SELECT current_account() as YOUR_ACCOUNT_LOCATOR, current_region() as YOUR_SNOWFLAKE_REGION_ID;
   ```

   > **Note:** If your Snowflake account isn't in AWS-US-West-2 refer to [doc](https://docs.snowflake.com/en/user-guide/admin-account-identifier#snowflake-region-ids) to identify your account locator.

1. Update your `.env` file and add the newly created credentials for the following variables
   export SNOWFLAKE_USER="tf-snow"
   export SNOWFLAKE_PRIVATE_KEY_PATH="../../snowflake/snowflake_tf_snow_key.p8"
   export SNOWFLAKE_ACCOUNT="YOUR_ACCOUNT_LOCATOR"

1. The `tf-snow` user account will be used by Terraform to create the following resources in Snowflake. All these resources will be deleted at the end of the demo when we run `terraform apply -destroy`. However, `tf-snow` won't get deleted.
   - A new user account named `TF_DEMO_USER` and a new public and private key pair.
   - A warehouse named `TF_DEMO`.
   - A database named `TF_DEMO`.
   - All permissions needed for the demo.

For troubleshooting or more information review the [doc](https://quickstarts.snowflake.com/guide/terraforming_snowflake/index.html?index=..%2F..index#2).

### CSP related infrastructure

The next steps vary slightly for each cloud provider. Expand the appropriate section below for directions. Remember to specify the same region as your sink target!

<details>
    <summary><b>AWS</b></summary>

1. Navigate to the repo's AWS directory.
   ```bash
   cd terraform/aws
   ```
1. Log into your AWS account through command line.

1. Initialize Terraform within the directory.
   ```bash
   terraform init
   ```
1. Create the Terraform plan.
   ```bash
   terraform plan -out=myplan
   ```
1. Apply the plan to create the infrastructure.

   ```bash
   terraform apply myplan
   ```

   > **Note:** _Read the `main.tf` configuration file [to see what will be created](./terraform/aws/main.tf)._

   </details>
   <br>

<details>
    <summary><b>GCP</b></summary>

1. Navigate to the GCP directory for Terraform.
   ```bash
   cd terraform/gcp
   ```
1. Initialize Terraform within the directory.
   ```bash
   terraform init
   ```
1. Create the Terraform plan.
   ```bash
   terraform plan --out=myplan
   ```
1. Apply the plan and create the infrastructure.

   ```bash
   terraform apply myplan
   ```

   > **Note:** To see what resources are created by this command, see the [`main.tf` file here](./terraform/gcp/main.tf).

</details>
<br>

<details>
    <summary><b>Azure</b></summary>

1. Navigate to the Azure directory for Terraform.
   ```bash
   cd terraform/azure
   ```
1. Log into Azure account through CLI.

   > **Note** Follow [this](https://developer.hashicorp.com/terraform/tutorials/azure-get-started/azure-build) guide to create the Service Principal to get the ID/Token to use via Terraform.

1. Create a SSH key pair and save it to `~/.ssh/rtdwkey`.

1. Initialize Terraform within the directory.
   ```bash
   terraform init
   ```
1. Create the Terraform plan.
   ```bash
   terraform plan --out=myplan
   ```
1. Apply the plan and create the infrastructure.

   ```bash
   terraform apply myplan
   ```

   > **Note:** To see what resources are created by this command, see the [`main.tf` file here](./terraform/azure/main.tf).

</details>
<br>

1. Write the output of `terraform` to a JSON file. The `env.sh` script will parse the JSON file to update the `.env` file.

   ```bash
   terraform output -json > ../../resources.json
   ```

   > **Note:** _Verify that the `resources.json` is created at root level of demo-realtime-data-warehousing directory._

1. Run the `env.sh` script.
   ```bash
   ./env.sh
   ```
1. This script achieves the following:
   - Creates an API key pair that will be used in connectors' configuration files for authentication purposes.
   - Updates the `.env` file to replace the remaining variables with the newly generated values.

---

# Demo

## Configure Source Connectors

Confluent offers 120+ pre-built [connectors](https://www.confluent.io/product/confluent-connectors/), enabling you to modernize your entire data architecture even faster. These connectors also provide you peace-of-mind with enterprise-grade security, reliability, compatibility, and support.

### Automated Connector Configuration File Creation

You can use Confluent Cloud CLI to submit all the source connectors automatically.

1. Run a script that uses your `.env` file to generate real connector configuration json files from the example files located in the `confluent` folder.

   ```bash
   cd demo-realtime-data-warehousing/connect
   ./create_connector_files.sh
   ```

### Configure Debezium Postgres CDC Source Connectors

You can create the connectors either through CLI or Confluent Cloud web UI.

<details>
    <summary><b>CLI</b></summary>

1. Log into your Confluent account in the CLI.

   ```bash
   confluent login --save
   ```

1. Use your environment and your cluster.

   ```bash
   confluent environment list
   confluent environment use <your_env_id>
   confluent kafka cluster list
   confluent kafka cluster use <your_cluster_id>
   ```

1. Run the following commands to create 2 Postgres CDC Source connectors.

   ```bash
   cd demo-realtime-data-warehousing/connect
   confluent connect cluster create --config-file actual_postgres_customers_source.json
   confluent connect cluster create --config-file actual_postgres_products_source.json
   ```

</details>
<br>

<details>
    <summary><b>Confluent Cloud Web UI</b></summary>

1. Log into Confluent Cloud by navigating to https://confluent.cloud
1. Step into **Demo_Real_Time_Data_Warehousing** environment.
1. If you are promoted with **Unlock advanced governance controls** screen, click on **No thanks, I will upgrade later**.
   > **Note:** In this demo, the Essential package for Stream Governance is sufficient. However you can take a moment and review the differences between the Esstentials and Advanced packages.
1. Step into **demo_kafka_cluster**.
1. On the navigation menu, select **Connectors** and then **+ Add connector**.
1. In the search bar search for **Postgres** and select the **Postgres CDC Source connector** which is a fully-managed connector.
1. Create a new Postgres CDC Source connector and complete the required fields using `actual_postgres_customers_source.json` file.
1. Repeat the same process and the second **Postgres CDC Source connector** using `actual_postgres_products_source.json` file.

</details>
<br>

Once both are fully provisioned, check for and troubleshoot any failures that occur. Properly configured, each connector begins reading data automatically.

> **Note:** _Only the `products.orders` table emits an ongoing stream of records. The others have their records produced to their topics from an initial snapshot only. After that, they do nothing more. The connector throughput will accordingly drop to zero over time._

---

### ksqlDB

If all is well, it's time to transform and join your data using ksqlDB. Ensure your topics are receiving records first.

1. Navigate to Confluent Cloud web UI and then go to ksqlDB cluster.

1. Change `auto.offset.reset = earliest`.

1. Use the editor to execute the following queries.

1. Use the following statements to consume `customers` records.

   ```sql
   CREATE STREAM customers_stream WITH (KAFKA_TOPIC='postgres.customers.customers', KEY_FORMAT='JSON', VALUE_FORMAT='JSON_SR');
   ```

1. Verify `customers_stream` stream is populated correctly and then hit **Stop**.

   ```sql
   SELECT * FROM customers_stream EMIT CHANGES;
   ```

1. You can pass `customers_stream` into a ksqlDB table that updates the latest value provided for each field.

   ```sql
    CREATE TABLE customers WITH (KAFKA_TOPIC='customers', KEY_FORMAT='JSON', VALUE_FORMAT='JSON_SR') AS
    SELECT
        id,
        LATEST_BY_OFFSET(first_name) first_name,
        LATEST_BY_OFFSET(last_name) last_name,
        LATEST_BY_OFFSET(email) email,
        LATEST_BY_OFFSET(phone) phone
    FROM customers_stream
    GROUP BY id
    EMIT CHANGES;
   ```

1. Verify the `customers` table is populated correctly.
   ```sql
   SELECT * FROM customers;
   ```
1. Repeat the process above for the `demographics` table.

   ```sql
    CREATE STREAM demographics_stream WITH (KAFKA_TOPIC='postgres.customers.demographics', KEY_FORMAT='JSON', VALUE_FORMAT='JSON_SR');
   ```

1. Verify `demographics_stream` stream is populated correctly and then hit **Stop**.

   ```sql
    SELECT * FROM demographics_stream EMIT CHANGES;
   ```

1. Create a ksqlDB table to present the the latest values by demographics.

   ```sql
    CREATE TABLE demographics WITH (KAFKA_TOPIC='demographics', KEY_FORMAT='JSON',VALUE_FORMAT='JSON_SR') AS
       SELECT
        id,
        LATEST_BY_OFFSET(street_address) street_address,
        LATEST_BY_OFFSET(state) state,
        LATEST_BY_OFFSET(zip_code) zip_code,
        LATEST_BY_OFFSET(country) country,
        LATEST_BY_OFFSET(country_code) country_code
        FROM demographics_stream
        GROUP BY id
    EMIT CHANGES;
   ```

1. Verify the `demographics` table is populated correctly.

   ```sql
   SELECT * FROM demographics;
   ```

1. You can now join `customers` and `demographics` by customer ID to create am up-to-the-second view of each record.

   ```sql
    CREATE TABLE customers_enriched WITH (KAFKA_TOPIC='customers_enriched',KEY_FORMAT='JSON', VALUE_FORMAT='JSON_SR') AS
        SELECT
            c.id id, c.first_name, c.last_name, c.email, c.phone,
            d.street_address, d.state, d.zip_code, d.country, d.country_code
        FROM customers c
        JOIN demographics d ON d.id = c.id
    EMIT CHANGES;
   ```

1. Verify `customers_enriched` stream is populated correctly and then hit **Stop**.

   ```sql
   SELECT * FROM customers_enriched EMIT CHANGES;
   ```

1. Next you will capture your `products` records and convert the record key to a simpler value.

   ```sql
    CREATE STREAM products_composite (
        struct_key STRUCT<product_id VARCHAR> KEY,
        product_id VARCHAR,
        `size` VARCHAR,
        product VARCHAR,
        department VARCHAR,
        price VARCHAR
   ) WITH (KAFKA_TOPIC='postgres.products.products', KEY_FORMAT='JSON', VALUE_FORMAT='JSON_SR', PARTITIONS=1, REPLICAS=3);
   ```

   ```sql
    CREATE STREAM products_rekeyed WITH (
        KAFKA_TOPIC='products_rekeyed',
        KEY_FORMAT='JSON',
        VALUE_FORMAT='JSON_SR'
    ) AS
        SELECT
            product_id,
            `size`,
            product,
            department,
            price
        FROM products_composite
    PARTITION BY product_id
   EMIT CHANGES;
   ```

1. Verify `products_rekeyed` stream is populated correctly and then hit **Stop**.
   ```sql
   SELECT * FROM products_rekeyed EMIT CHANGES;
   ```
1. Create a ksqlDB table to show the most up-to-date values for each `products` record.

   ```sql
    CREATE TABLE products WITH (
    KAFKA_TOPIC='products',
    KEY_FORMAT='JSON',
    VALUE_FORMAT='JSON_SR'
    ) AS
        SELECT
            product_id,
            LATEST_BY_OFFSET(`size`) `size`,
            LATEST_BY_OFFSET(product) product,
            LATEST_BY_OFFSET(department) department,
            LATEST_BY_OFFSET(price) price
        FROM products_rekeyed
        GROUP BY product_id
    EMIT CHANGES;
   ```

1. Verify the `products` table is populated correctly.

   ```sql
   SELECT * FROM products;
   ```

1. Follow the same process using the `orders` data.

   ```sql
    CREATE STREAM orders_composite (
        order_key STRUCT<`order_id` VARCHAR> KEY,
        order_id VARCHAR,
        product_id VARCHAR,
        customer_id VARCHAR
   ) WITH (
        KAFKA_TOPIC='postgres.products.orders',
        KEY_FORMAT='JSON',
        VALUE_FORMAT='JSON_SR'
   );
   ```

   ```sql
    CREATE STREAM orders_rekeyed WITH (
        KAFKA_TOPIC='orders_rekeyed',
        KEY_FORMAT='JSON',
        VALUE_FORMAT='JSON_SR'
    ) AS
        SELECT
            order_id,
            product_id,
            customer_id
        FROM orders_composite
    PARTITION BY order_id
   EMIT CHANGES;
   ```

1. Verify `orders_rekeyed` stream is populated correctly and then hit **Stop**.
   ```sql
   SELECT * FROM orders_rekeyed EMIT CHANGES;
   ```
1. You're now ready to create a ksqlDB stream that joins these tables together to create enriched order data in real time.
   ```sql
    CREATE STREAM orders_enriched WITH (
    KAFKA_TOPIC='orders_enriched',
    KEY_FORMAT='JSON',
    VALUE_FORMAT='JSON_SR'
    ) AS
        SELECT
            o.order_id AS `order_id`,
            p.product_id AS `product_id`,
            p.`size` AS `size`,
            p.product AS `product`,
            p.department AS `department`,
            p.price AS `price`,
            c.id AS `customer_id`,
            c.first_name AS `first_name`,
            c.last_name AS `last_name`,
            c.email AS `email`,
            c.phone AS `phone`,
            c.street_address AS `street_address`,
            c.state AS `state`,
            c.zip_code AS `zip_code`,
            c.country AS `country`,
            c.country_code AS `country_code`
        FROM orders_rekeyed o
            JOIN products p ON o.product_id = p.product_id
            JOIN customers_enriched c ON o.customer_id = c.id
    PARTITION BY o.order_id
    EMIT CHANGES;
   ```
1. Verify `orders_enriched` stream is populated correctly and then hit **Stop**.

   ```sql
   SELECT * FROM orders_enriched EMIT CHANGES;
   ```

   > **Note:** We need a stream to 'hydrate' our data warehouse once the sink connector is set up.

Verify that you have a working ksqlDB topology. You can inspect it by selecting the **Flow** tab in the ksqlDB cluster. Check to see that records are populating the `orders_enriched` kstream.

---

### Data Warehouse Connectors

You're now ready to sink data to your chosen warehouse. Expand the appropriate section and follow the directions to set up your connector.

<details>
    <summary><b>Databricks</b></summary>
    
1. Review the [source documentation](https://docs.confluent.io/cloud/current/connectors/cc-databricks-delta-lake-sink/cc-databricks-delta-lake-sink.html) if you prefer.

1. Locate your JDBC/ODBC details. Select your cluster. Expand the **Advanced** section and select the **JDBC/ODBC** tab. Paste the values for **Server Hostname** and **HTTP Path** to your `env.sh` file under `DATABRICKS_SERVER_HOSTNAME` and `DATABRICKS_HTTP_PATH`.

   > **Note:** If you don't yet have an S3 bucket, AWS Key/secret, or Databricks Access token as described in the Prerequisites, create and/or gather them now.

1. Create your Databricks Delta Lake Sink Connector. Select **Data integration > Connectors** from the left-hand menu and search for the connector. Select its tile and configure it using the following settings.

   | **Property**                      | **Value**                 |
   | --------------------------------- | ------------------------- |
   | Topics                            | `orders_enriched`         |
   | Kafka Cluster Authentication mode | KAFKA_API_KEY             |
   | Kafka API Key                     | _copy from `env.sh` file_ |
   | Kafka API Secret                  | _copy from `env.sh` file_ |
   | Delta Lake Host Name              | _copy from `env.sh` file_ |
   | Delta Lake HTTP Path              | _copy from `env.sh` file_ |
   | Delta Lake Token                  | _from Databricks setup_   |
   | Staging S3 Access Key ID          | _from Databricks setup_   |
   | Staging S3 Secret Access Key      | _from Databricks setup_   |
   | S3 Staging Bucket Name            | _from Databricks setup_   |
   | Tasks                             | 1                         |

1. Launch the connector. Once provisioned correctly, it will write data to a Delta Lake Table automatically. Create the following table in Databricks.

   ```sql
       CREATE TABLE orders_enriched (order_id STRING,
           product_id STRING, size STRING, product STRING, department STRING, price STRING,
           id STRING, first_name STRING, last_name STRING, email STRING, phone STRING,
           street_address STRING, state STRING, zip_code STRING, country STRING, country_code STRING,
           partition INT)
       USING DELTA;
   ```

1. Et voila! Now query yours records
   ```sql
    SELECT * FROM default.orders_enriched;
   ```

Experiment to your heart's desire with the data in Databricks. For example, you could write some queries that combine the data from two tables each source database, such as caclulating total revenue by state.

</details>
<br>

<details>
    <summary><b>Snowflake</b></summary>

You can create the connectors either through CLI or Confluent Cloud web UI.

<details>
    <summary><b>CLI</b></summary>

1. Log into your Confluent account in the CLI.

   ```bash
   confluent login --save
   ```

1. Use your environment and your cluster.

   ```bash
   confluent environment list
   confluent environment use <your_env_id>
   confluent kafka cluster list
   confluent kafka cluster use <your_cluster_id>
   ```

1. Run the following command to create Snowflake Sink connector

   ```bash
   cd demo-realtime-data-warehousing/connect
   confluent connect cluster create --config-file actual_snowflake_sink.json
   ```

</details>
<br>

<details>
    <summary><b>Confluent Cloud Web UI</b></summary>

1. Log into Confluent Cloud by navigating to https://confluent.cloud
1. Step into **Demo_Real_Time_Data_Warehousing** environment.
1. Step into **demo_kafka_cluster**.
1. On the navigation menu, select **Connectors** and then **+ Add connector**.
1. In the search bar search for **Snowflake** and select the **Snowflake Sink** which is a fully-managed connector.
1. Create a new connector and complete the required fields using `actual_snowflake_sink.json` file.

</details>
<br>

Once the connector is fully provisioned, check for and troubleshoot any failures that occur. Properly configured, each connector begins reading data automatically.

1. Log into your Snowflake account.
1. Create a new worksheet or use an existing one.
1. Run the following commands

   ```sql
   USE ROLE TF_DEMO_SVC_ROLE;
   USE WAREHOUSE TF_DEMO;
   ALTER WAREHOUSE TF_DEMO RESUME;
   USE DATABASE TF_DEMO;

   SELECT * FROM "TF_DEMO"."PUBLIC".ORDERS_ENRICHED LIMIT 100;
   ```

1. You can flatten data in Snowflake if you wish. Use [Snowflake's documentation](https://docs.snowflake.com/en/user-guide/json-basics-tutorial-query.html). You can also query JSON data directly in Snowflake by naming the column and specifying columns of interest. For example:

   ```sql
   SELECT RECORD_CONTENT:email FROM "TF_DEMO"."PUBLIC".ORDERS_ENRICHED LIMIT 100;
   ```

   > **Note**: To things simple in this demo `TF_DEMO_SVC_ROLE` is given `SECURITYADMIN` level permissions. However, you should always follow best practices in production environment.

</details>

<br>

---

## CONGRATULATIONS

Congratulations on building your streaming data pipelines for realtime data warehousing scenario in Confluent Cloud! Your complete pipeline should resemble the following one.
![Alt Text](images/Stream-Lineage.gif)

---

# Teardown

You want to delete any resources that were created during the demo so you don't incur additional charges.

## Infrastructure

1. Run the following command to delete all connectors

   ```bash
   cd demo-realtime-data-warehousing
   ./teardown_connectors.sh
   ```

1. Run the following command to delete all resources created by Terraform
   ```bash
   terraform apply -destory
   ```

### Databricks and Snowflake

If you created instances of either Databricks and Snowflake solely to run this lab, you can remove them.

1. Log into Snowflake account and use a worksheet to delete `tf-snow` by running
   ```sql
   DROP USER "tf-snow";
   ```

---

## Useful Links

Databricks

- [Confluent Cloud Databricks Delta Lake Sink](https://docs.confluent.io/cloud/current/connectors/cc-databricks-delta-lake-sink/cc-databricks-delta-lake-sink.html)
- [Databricks Setup on AWS](https://docs.confluent.io/cloud/current/connectors/cc-databricks-delta-lake-sink/databricks-aws-setup.html)
