auto.offset.reset = earliest
CREATE STREAM customers_stream WITH (KAFKA_TOPIC='postgres.customers.customers', KEY_FORMAT='JSON', VALUE_FORMAT='JSON_SR');

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

CREATE STREAM demographics_stream WITH (KAFKA_TOPIC='postgres.customers.demographics', KEY_FORMAT='JSON', VALUE_FORMAT='JSON_SR');

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

CREATE TABLE customers_enriched WITH (KAFKA_TOPIC='customers_enriched',KEY_FORMAT='JSON', VALUE_FORMAT='JSON_SR') AS
    SELECT
        c.id id, c.first_name, c.last_name, c.email, c.phone,
        d.street_address, d.state, d.zip_code, d.country, d.country_code
    FROM customers c
    JOIN demographics d ON d.id = c.id
EMIT CHANGES;

CREATE STREAM products_composite (
    struct_key STRUCT<product_id VARCHAR> KEY,
    product_id VARCHAR,
    `size` VARCHAR,
    product VARCHAR,
    department VARCHAR,
    price VARCHAR
) WITH (KAFKA_TOPIC='postgres.products.products', KEY_FORMAT='JSON', VALUE_FORMAT='JSON_SR', PARTITIONS=1, REPLICAS=3);

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

