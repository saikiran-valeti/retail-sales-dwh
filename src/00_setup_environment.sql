-- Create the main project Catalog
CREATE CATALOG IF NOT EXISTS retail_project;

USE CATALOG retail_project;

-- Create the Databases inside this catalog
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

-- Verify they were created successfully
SHOW SCHEMAS IN retail_project;