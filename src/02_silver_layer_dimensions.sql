-- ==========================================
-- 02_silver_layer_dimensions.sql
-- ==========================================

-- ------------------------------------------
-- 1. Silver DimProduct (Static Dimension)
-- ------------------------------------------
DROP TABLE IF EXISTS silver.DimProduct;

CREATE TABLE silver.DimProduct (
    ProductSK BIGINT GENERATED ALWAYS AS IDENTITY,
    ProductID STRING,  
    ProductName STRING,
    Category STRING,
    UnitPrice DECIMAL(10,2),
    EffectiveDate DATE
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/silver/DimProduct_v2'; -- FIX: New S3 path

INSERT OVERWRITE silver.DimProduct (ProductID, ProductName, Category, UnitPrice, EffectiveDate)
SELECT 
    TRIM(CAST(ProductID AS STRING)), 
    TRIM(ProductName),
    TRIM(Category),
    CAST(UnitPrice AS DECIMAL(10,2)),
    CURRENT_DATE() AS EffectiveDate
FROM bronze.products;

-- ------------------------------------------
-- 2. Silver DimStore (Static Dimension)
-- ------------------------------------------
DROP TABLE IF EXISTS silver.DimStore;

CREATE TABLE silver.DimStore (
    StoreSK BIGINT GENERATED ALWAYS AS IDENTITY,
    StoreID STRING,  
    StoreName STRING,
    Region STRING
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/silver/DimStore_v2'; -- FIX: New S3 path

INSERT OVERWRITE silver.DimStore (StoreID, StoreName, Region)
SELECT 
    TRIM(CAST(StoreID AS STRING)), 
    TRIM(StoreName),
    TRIM(Region)
FROM bronze.stores;

-- ------------------------------------------
-- 3. Silver DimCustomer (SCD Type 2)
-- ------------------------------------------
DROP TABLE IF EXISTS silver.DimCustomer;

CREATE TABLE silver.DimCustomer (
    CustomerSK BIGINT GENERATED ALWAYS AS IDENTITY,
    CustomerID INT,
    CustomerName STRING,
    Email STRING,
    City STRING,
    Address STRING,
    StartDate DATE,
    EndDate DATE,
    IsActive INT
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/silver/DimCustomer_v2'; -- FIX: New S3 path

-- SCD2 STEP A
UPDATE silver.DimCustomer tgt
SET tgt.IsActive = 0, tgt.EndDate = CURRENT_DATE()
WHERE tgt.IsActive = 1 
  AND EXISTS (
      SELECT 1 FROM bronze.customers src 
      WHERE src.CustomerID = tgt.CustomerID 
        AND (TRIM(src.City) != tgt.City OR TRIM(src.Address) != tgt.Address)
  );

-- SCD2 STEP B
INSERT INTO silver.DimCustomer (CustomerID, CustomerName, Email, City, Address, StartDate, EndDate, IsActive)
SELECT 
    src.CustomerID,
    INITCAP(TRIM(src.CustomerName)),
    LOWER(TRIM(src.Email)),
    TRIM(src.City),
    TRIM(src.Address),
    CAST('1900-01-01' AS DATE),  
    CAST('9999-12-31' AS DATE),
    1
FROM bronze.customers src
LEFT JOIN silver.DimCustomer tgt 
  ON src.CustomerID = tgt.CustomerID AND tgt.IsActive = 1
WHERE tgt.CustomerID IS NULL;