-- 03_gold_layer_facts.sql

USE CATALOG retail_project;
USE SCHEMA gold;

-- 1. Create the Gold FactSales table
CREATE TABLE IF NOT EXISTS gold.FactSales (
    SalesSK BIGINT GENERATED ALWAYS AS IDENTITY,
    TransactionID INT,
    CustomerSK BIGINT,
    ProductSK BIGINT,
    StoreSK BIGINT,
    Quantity INT,
    Amount DECIMAL(10,2),
    TxnDate DATE
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/gold/FactSales';


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
    LEFT JOIN silver.DimProduct p 
        ON TRIM(CAST(s.ProductID AS STRING)) = p.ProductID
    LEFT JOIN silver.DimStore st 
        ON TRIM(CAST(s.StoreID AS STRING)) = st.StoreID
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
MERGE INTO gold.FactSales tgt
USING incoming_sales src
ON tgt.TransactionID = src.TransactionID
WHEN MATCHED THEN
  UPDATE SET
    tgt.CustomerSK = src.CustomerSK,
    tgt.ProductSK = src.ProductSK,
    tgt.StoreSK = src.StoreSK,
    tgt.Quantity = src.Quantity,
    tgt.Amount = src.Amount,
    tgt.TxnDate = src.TxnDate
WHEN NOT MATCHED THEN
  INSERT (TransactionID, CustomerSK, ProductSK, StoreSK, Quantity, Amount, TxnDate)
  VALUES (src.TransactionID, src.CustomerSK, src.ProductSK, src.StoreSK, src.Quantity, src.Amount, src.TxnDate);

--- gold sales check --
  SELECT 'dim_customer' AS table_name, COUNT(*) AS total_rows,
       SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END) AS active_rows
FROM retail_project.silver.dimcustomer
UNION ALL
SELECT 'dim_product', COUNT(*), NULL FROM retail_project.silver.dimproduct
UNION ALL
SELECT 'dim_store',   COUNT(*), NULL FROM retail_project.silver.dimstore
UNION ALL
SELECT 'fact_sales',  COUNT(*), NULL FROM retail_project.gold.factsales;