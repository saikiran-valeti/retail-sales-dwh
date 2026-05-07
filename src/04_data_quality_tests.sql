-- 04_data_quality_tests.sql
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


-- Historical Mapping Check ---
SELECT COUNT(*) AS Historical_Mapping_Errors
FROM gold.FactSales f
JOIN silver.dimcustomer c 
  ON f.CustomerSK = c.CustomerSK
WHERE f.TxnDate < c.StartDate 
   OR f.TxnDate > c.EndDate;

-- Calculation Check ---
SELECT f.TransactionID, f.Amount, (f.Quantity * p.UnitPrice) AS ExpectedAmount
FROM gold.FactSales f
JOIN silver.DimProduct p ON f.ProductSK = p.ProductSK
WHERE f.Amount != (f.Quantity * p.UnitPrice);


-- SCD Type 2 Check ---
USE CATALOG retail_project;

SELECT 
    CustomerSK,
    CustomerID, 
    CustomerName, 
    City, 
    Address, 
    StartDate, 
    EndDate, 
    IsActive
FROM silver.DimCustomer
WHERE CustomerID IN (
    SELECT CustomerID 
    FROM silver.DimCustomer 
    GROUP BY CustomerID 
    HAVING COUNT(*) > 1
)
ORDER BY CustomerID, StartDate;
