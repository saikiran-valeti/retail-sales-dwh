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