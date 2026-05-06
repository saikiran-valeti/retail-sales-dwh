-- ==========================================
-- 03_gold_layer_facts.sql
-- Purpose: Build the FactSales table for reporting (Daily Append)
-- ==========================================

USE CATALOG retail_project;
USE SCHEMA gold;

-- 1. Create the table ONLY if it doesn't exist yet
CREATE TABLE IF NOT EXISTS gold.FactSales (
    SalesSK BIGINT GENERATED ALWAYS AS IDENTITY,
    TransactionID INT,
    CustomerSK BIGINT,
    ProductSK BIGINT,
    StoreSK BIGINT,
    Quantity INT,
    Amount DECIMAL(10,2),
    TxnDate DATE
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/gold/FactSales_v2';

-- 2. Append today's new sales to the bottom of the table
INSERT INTO gold.FactSales (TransactionID, CustomerSK, ProductSK, StoreSK, Quantity, Amount, TxnDate)
SELECT 
    CAST(s.TransactionID AS INT),
    c.CustomerSK,
    p.ProductSK,
    st.StoreSK,
    CAST(s.Quantity AS INT),
    CAST((s.Quantity * p.UnitPrice) AS DECIMAL(10,2)) AS Amount,
    to_date(s.TxnDate, 'dd-MM-yyyy') AS TxnDate
FROM bronze.sales s

-- Bulletproofed Joins matching on TRIMMED STRINGS for Product:
LEFT JOIN silver.DimProduct p 
    ON TRIM(CAST(s.ProductID AS STRING)) = p.ProductID

-- Mathematically mapping Store 10 to 100, 20 to 101, etc.
LEFT JOIN silver.DimStore st 
    ON TRIM(CAST(s.StoreID AS STRING)) = st.StoreID

-- SCD Type 2 Date Logic for Customer:
LEFT JOIN silver.DimCustomer c 
    ON CAST(TRIM(s.CustomerID) AS INT) = c.CustomerID 
    AND to_date(s.TxnDate, 'dd-MM-yyyy') >= c.StartDate 
    AND to_date(s.TxnDate, 'dd-MM-yyyy') <= c.EndDate;