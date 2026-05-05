CREATE TABLE IF NOT EXISTS silver.DimProduct (
    ProductSK BIGINT GENERATED ALWAYS AS IDENTITY,
    ProductID INT,
    ProductName STRING,
    Category STRING,
    UnitPrice DECIMAL(10,2),
    EffectiveDate DATE
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/silver/DimProduct';

-- Load data (Overwrite is safe because we assume prices are static for this project)
INSERT OVERWRITE silver.DimProduct (ProductID, ProductName, Category, UnitPrice, EffectiveDate)
SELECT 
    CAST(ProductID AS INT),
    TRIM(ProductName),
    TRIM(Category),
    CAST(UnitPrice AS DECIMAL(10,2)),
    CURRENT_DATE() AS EffectiveDate
FROM bronze.products;

-- ------------------------------------------
-- 2. Silver DimStore (Static Dimension)
-- ------------------------------------------
CREATE TABLE IF NOT EXISTS silver.DimStore (
    StoreSK BIGINT GENERATED ALWAYS AS IDENTITY,
    StoreID INT,
    StoreName STRING,
    Region STRING
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/silver/DimStore';

INSERT OVERWRITE silver.DimStore (StoreID, StoreName, Region)
SELECT 
    CAST(StoreID AS INT),
    TRIM(StoreName),
    TRIM(Region)
FROM bronze.stores;

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

-- SCD2 STEP A: Expire existing records if their City or Address changed
UPDATE silver.DimCustomer tgt
SET tgt.IsActive = 0, tgt.EndDate = CURRENT_DATE()
WHERE tgt.IsActive = 1 
  AND EXISTS (
      SELECT 1 FROM bronze.customers src 
      WHERE src.CustomerID = tgt.CustomerID 
        AND (TRIM(src.City) != tgt.City OR TRIM(src.Address) != tgt.Address)
  );

-- SCD2 STEP B: Insert brand new customers AND the new active rows for updated customers
INSERT INTO silver.DimCustomer (CustomerID, CustomerName, Email, City, Address, StartDate, EndDate, IsActive)
SELECT 
    src.CustomerID,
    INITCAP(TRIM(src.CustomerName)), -- Proper Case
    LOWER(TRIM(src.Email)),          -- Lowercase
    TRIM(src.City),
    TRIM(src.Address),
    CURRENT_DATE(),
    CAST('9999-12-31' AS DATE),      -- Default end date for active records
    1                                -- 1 = Current/Active
FROM bronze.customers src
-- Ensure we only insert if there isn't ALREADY an identical active record
LEFT JOIN silver.DimCustomer tgt 
  ON src.CustomerID = tgt.CustomerID AND tgt.IsActive = 1
WHERE tgt.CustomerID IS NULL;