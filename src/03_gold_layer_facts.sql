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
);

-- STEP A: Gather and clean the incoming daily sales using a CTE
WITH incoming_sales_raw AS (
    SELECT 
        CAST(s.TransactionID AS INT) AS TransactionID,
        c.CustomerSK,
        p.ProductSK,
        st.StoreSK,
        CAST(s.Quantity AS INT) AS Quantity,
        CAST((s.Quantity * p.UnitPrice) AS DECIMAL(10,2)) AS Amount,
        to_date(s.TxnDate, 'dd-MM-yyyy') AS TxnDate,
        ROW_NUMBER() OVER (PARTITION BY s.TransactionID ORDER BY c.StartDate DESC) AS rn
    FROM bronze.sales s

    -- Bulletproofed Joins matching on TRIMMED STRINGS for Product:
    LEFT JOIN silver.DimProduct p 
        ON TRIM(CAST(s.ProductID AS STRING)) = p.ProductID

    -- Mapping Store logic:
    LEFT JOIN silver.DimStore st 
        ON TRIM(CAST(s.StoreID AS STRING)) = st.StoreID

    -- SCD Type 2 Date Logic for Customer:
    LEFT JOIN silver.DimCustomer c 
        ON CAST(TRIM(s.CustomerID) AS INT) = c.CustomerID 
        AND to_date(s.TxnDate, 'dd-MM-yyyy') >= c.StartDate 
        AND to_date(s.TxnDate, 'dd-MM-yyyy') <= c.EndDate
),
incoming_sales AS (
    SELECT 
        TransactionID,
        CustomerSK,
        ProductSK,
        StoreSK,
        Quantity,
        Amount,
        TxnDate
    FROM incoming_sales_raw
    WHERE rn = 1
)

-- STEP B: Merge the incoming data into the Gold table
MERGE INTO gold.FactSales tgt
USING incoming_sales src
ON tgt.TransactionID = src.TransactionID

-- If the TransactionID already exists, update the record with any new values
WHEN MATCHED THEN
  UPDATE SET
    tgt.CustomerSK = src.CustomerSK,
    tgt.ProductSK = src.ProductSK,
    tgt.StoreSK = src.StoreSK,
    tgt.Quantity = src.Quantity,
    tgt.Amount = src.Amount,
    tgt.TxnDate = src.TxnDate

-- If it's a brand new TransactionID, insert it as a new row
WHEN NOT MATCHED THEN
  INSERT (TransactionID, CustomerSK, ProductSK, StoreSK, Quantity, Amount, TxnDate)
  VALUES (src.TransactionID, src.CustomerSK, src.ProductSK, src.StoreSK, src.Quantity, src.Amount, src.TxnDate);