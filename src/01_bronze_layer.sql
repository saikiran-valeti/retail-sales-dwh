-- ==========================================
-- 01_bronze_layer.sql
-- Purpose: Merge SFTP raw files into Bronze Delta Tables
-- ==========================================

USE CATALOG retail_project;
USE SCHEMA bronze;

-- Clear Metastore just in case
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS stores;
DROP TABLE IF EXISTS sales;

-- ------------------------------------------
-- 1. Customers
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    CustomerID STRING,
    CustomerName STRING,
    Email STRING,
    City STRING,
    Address STRING,
    LastUpdated STRING
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/bronze/customers';

COPY INTO customers 
FROM 's3://retail-dwh-project-bucket/sftp/'
FILEFORMAT = CSV
PATTERN = 'customers_src*.csv'
FORMAT_OPTIONS ('header' = 'true')
COPY_OPTIONS ('mergeSchema' = 'true');

-- Delete rows with null CustomerID
DELETE FROM customers WHERE CustomerID IS NULL;

-- ------------------------------------------
-- 2. Products
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS products (
    ProductID STRING, 
    ProductName STRING,
    Category STRING,
    UnitPrice STRING
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/bronze/products';

COPY INTO products 
FROM 's3://retail-dwh-project-bucket/sftp/'
FILEFORMAT = CSV
PATTERN = 'products_src*.csv'
FORMAT_OPTIONS ('header' = 'true');

-- ------------------------------------------
-- 3. Stores
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS stores (
    StoreID STRING,  
    StoreName STRING,
    Region STRING
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/bronze/stores';

COPY INTO stores 
FROM 's3://retail-dwh-project-bucket/sftp/'
FILEFORMAT = CSV
PATTERN = 'stores_src*.csv'
FORMAT_OPTIONS ('header' = 'true');

-- ------------------------------------------
-- 4. Sales
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS sales (
    TransactionID STRING,
    CustomerID STRING,
    ProductID STRING,
    StoreID STRING,
    Quantity STRING,
    TxnDate STRING
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/bronze/sales';

COPY INTO sales 
FROM 's3://retail-dwh-project-bucket/sftp/'
FILEFORMAT = CSV
PATTERN = 'sales_transactions_src*.csv'
FORMAT_OPTIONS ('header' = 'true');

-- Delete rows with null CustomerID
DELETE FROM sales WHERE CustomerID IS NULL;
