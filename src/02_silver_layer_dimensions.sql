-- ==========================================
-- 02_silver_layer_dimensions.sql
-- Purpose: Clean, conform, and build Dimension tables (DUPLICATE PROOF)
-- ==========================================

USE CATALOG retail_project;
USE SCHEMA silver;

-- ------------------------------------------
-- 1. Silver DimProduct (Static Dimension)
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS silver.DimProduct (
    ProductSK BIGINT GENERATED ALWAYS AS IDENTITY,
    ProductID STRING,
    ProductName STRING,
    Category STRING,
    UnitPrice DECIMAL(10,2),
    EffectiveDate DATE
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/silver/DimProduct';

-- INSERT OVERWRITE replaces data daily. 
-- QUALIFY ensures only 1 unique ProductID is selected from Bronze.
INSERT OVERWRITE silver.DimProduct (ProductID, ProductName, Category, UnitPrice, EffectiveDate)
SELECT 
    TRIM(CAST(ProductID AS STRING)), 
    TRIM(ProductName),
    TRIM(Category),
    CAST(UnitPrice AS DECIMAL(10,2)),
    CURRENT_DATE() AS EffectiveDate
FROM bronze.products
QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(CAST(ProductID AS STRING)) ORDER BY ProductID) = 1;


-- ------------------------------------------
-- 2. Silver DimStore (Static Dimension)
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS silver.DimStore (
    StoreSK BIGINT GENERATED ALWAYS AS IDENTITY,
    StoreID STRING,  
    StoreName STRING,
    Region STRING
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/silver/DimStore';

-- QUALIFY ensures only 1 unique StoreID is selected from Bronze.
INSERT OVERWRITE silver.DimStore (StoreID, StoreName, Region)
SELECT 
    TRIM(CAST(StoreID AS STRING)), 
    TRIM(StoreName),
    TRIM(Region)
FROM bronze.stores
QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(CAST(StoreID AS STRING)) ORDER BY StoreID) = 1;


-- ------------------------------------------
-- 3. Silver DimCustomer (SCD Type 2)
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS silver.DimCustomer (
    CustomerSK BIGINT GENERATED ALWAYS AS IDENTITY,
    CustomerID INT,
    CustomerName STRING,
    Email STRING,
    City STRING,
    Address STRING,
    StartDate DATE,
    EndDate DATE,
    IsActive INT
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/silver/DimCustomer';

-- STEP 0: Create a Temporary View to hold perfectly clean, deduplicated Bronze customers.
-- We do this because the UPDATE and INSERT steps both need to use this data, 
-- and we only want to calculate the deduplication once!
CREATE OR REPLACE TEMP VIEW clean_bronze_customers AS
SELECT * 
FROM bronze.customers
QUALIFY ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY CustomerID) = 1;

-- SCD2 STEP A: Expire existing records if their City or Address changed
UPDATE silver.DimCustomer tgt
SET tgt.IsActive = 0, tgt.EndDate = CURRENT_DATE()
WHERE tgt.IsActive = 1 
  AND EXISTS (
      SELECT 1 FROM clean_bronze_customers src 
      WHERE CAST(src.CustomerID AS INT) = tgt.CustomerID 
        AND (TRIM(src.City) != tgt.City OR TRIM(src.Address) != tgt.Address)
  );

-- SCD2 STEP B: Insert brand new customers AND the new active rows for updated customers
INSERT INTO silver.DimCustomer (CustomerID, CustomerName, Email, City, Address, StartDate, EndDate, IsActive)
SELECT 
    CAST(src.CustomerID AS INT),
    INITCAP(TRIM(src.CustomerName)),
    LOWER(TRIM(src.Email)),
    TRIM(src.City),
    TRIM(src.Address),
    CAST('1900-01-01' AS DATE),  
    CAST('9999-12-31' AS DATE),
    1
FROM clean_bronze_customers src
LEFT JOIN silver.DimCustomer tgt 
  ON CAST(src.CustomerID AS INT) = tgt.CustomerID AND tgt.IsActive = 1
WHERE tgt.CustomerID IS NULL;