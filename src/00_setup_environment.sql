-- 1. Create the main project Catalog
CREATE CATALOG IF NOT EXISTS retail_project;

-- 2. Set the active catalog for the rest of this script
USE CATALOG retail_project;

-- 3. Create the Medallion Schemas (Databases) inside this catalog
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

-- Optional: Verify they were created successfully
SHOW SCHEMAS IN retail_project;