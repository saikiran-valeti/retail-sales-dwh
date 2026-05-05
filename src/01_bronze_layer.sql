-- ==========================================
-- 01_bronze_layer.sql
-- Purpose: Schema creation & Raw Data Mapping
-- ==========================================

-- 1. Create the Medallion schemas
CREATE DATABASE IF NOT EXISTS bronze;
CREATE DATABASE IF NOT EXISTS silver;
CREATE DATABASE IF NOT EXISTS gold;

-- 2. Map S3 CSVs to Databricks Tables
-- We use DROP then CREATE because CSV format does not support the REPLACE command.

-- Products
DROP TABLE IF EXISTS bronze.products;
CREATE TABLE bronze.products 
USING CSV OPTIONS (header "true", inferSchema "true")
LOCATION 's3://retail-dwh-project-bucket/bronze/products_src_20042026100105.csv';

-- Stores
DROP TABLE IF EXISTS bronze.stores;
CREATE TABLE bronze.stores 
USING CSV OPTIONS (header "true", inferSchema "true")
LOCATION 's3://retail-dwh-project-bucket/bronze/stores_src_20042026100107.csv';

-- Customers
DROP TABLE IF EXISTS bronze.customers;
CREATE TABLE bronze.customers 
USING CSV OPTIONS (header "true", inferSchema "true")
LOCATION 's3://retail-dwh-project-bucket/bronze/customers_src_20042026100105.csv';

-- Sales
DROP TABLE IF EXISTS bronze.sales;
CREATE TABLE bronze.sales 
USING CSV OPTIONS (header "true", inferSchema "true")
LOCATION 's3://retail-dwh-project-bucket/bronze/sales_transactions_src_20042026100107.csv';