-- ==========================================
-- 04_data_quality_tests.sql
-- Purpose: Data Quality Checks
-- ==========================================

USE CATALOG retail_project;

-- Row Count --
SELECT 
    (SELECT COUNT(*) FROM bronze.sales) AS Bronze_Raw_Sales_Count,
    (SELECT COUNT(*) FROM gold.FactSales) AS Gold_Fact_Sales_Count,
    CASE 
        WHEN (SELECT COUNT(*) FROM bronze.sales) = (SELECT COUNT(*) FROM gold.FactSales) THEN 'PASS' 
        ELSE 'FAIL - Row Count Mismatch' 
    END AS Completeness_Status;

--- Null Check ---
SELECT *
FROM gold.FactSales
WHERE CustomerSK IS NULL 
   OR ProductSK IS NULL 
   OR StoreSK IS NULL;

SELECT * FROM gold.FactSales;

SELECT 
    CustomerID, 
    COUNT(*) AS Active_Record_Count
FROM silver.DimCustomer
WHERE IsActive = 1
GROUP BY CustomerID
HAVING COUNT(*) > 1;

SELECT COUNT(*) AS Calculation_Errors
FROM gold.FactSales f
JOIN silver.DimProduct p 
  ON f.ProductSK = p.ProductSK
WHERE f.Amount != CAST((f.Quantity * p.UnitPrice) AS DECIMAL(10,2));

SELECT COUNT(*) AS Historical_Mapping_Errors
FROM gold.FactSales f
JOIN silver.DimCustomer c 
  ON f.CustomerSK = c.CustomerSK
WHERE f.TxnDate < c.StartDate 
   OR f.TxnDate > c.EndDate;

USE CATALOG retail_project;

-- ------------------------------------------
-- TEST 1: Uniqueness in Silver Dimensions
-- ------------------------------------------
-- A dimension table should never have duplicate active IDs.
-- EXPECTED RESULT: 0 rows
SELECT CustomerID, COUNT(*) 
FROM silver.DimCustomer 
WHERE IsActive = 1 
GROUP BY CustomerID 
HAVING COUNT(*) > 1;

-- ------------------------------------------
-- TEST 2: Null Checks in Gold Fact Table
-- ------------------------------------------
-- Sales amounts and foreign keys should never be null.
-- EXPECTED RESULT: 0 rows
SELECT * 
FROM gold.FactSales 
WHERE CustomerSK IS NULL 
   OR ProductSK IS NULL 
   OR Amount IS NULL;

-- ------------------------------------------
-- TEST 3: Mathematical Accuracy
-- ------------------------------------------
-- Does the total Amount equal Quantity * UnitPrice?
-- EXPECTED RESULT: 0 rows
SELECT f.TransactionID, f.Amount, (f.Quantity * p.UnitPrice) AS ExpectedAmount
FROM gold.FactSales f
JOIN silver.DimProduct p ON f.ProductSK = p.ProductSK
WHERE f.Amount != (f.Quantity * p.UnitPrice);

select * from silver.dimproduct;