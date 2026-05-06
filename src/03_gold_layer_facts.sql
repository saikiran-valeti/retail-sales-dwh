-- 1. Drop the old table to start fresh
DROP TABLE IF EXISTS gold.FactSales;

-- 2. Create the Gold Fact Table (Using _v2 to avoid Delta schema mismatch errors)
CREATE TABLE gold.FactSales (
    SalesSK BIGINT GENERATED ALWAYS AS IDENTITY,
    TransactionID INT,
    CustomerSK BIGINT,
    ProductSK BIGINT,
    StoreSK BIGINT,
    Quantity INT,
    Amount DECIMAL(10,2),
    TxnDate DATE
) USING DELTA LOCATION 's3://retail-dwh-project-bucket/gold/FactSales_v2';

-- 3. Transform and Load the Facts
INSERT INTO gold.FactSales (TransactionID, CustomerSK, ProductSK, StoreSK, Quantity, Amount, TxnDate)
SELECT 
    CAST(s.TransactionID AS INT),
    c.CustomerSK,
    p.ProductSK,
    st.StoreSK,
    CAST(s.Quantity AS INT),
    CAST((s.Quantity * p.UnitPrice) AS DECIMAL(10,2)) AS Amount,
    CAST(s.TxnDate AS DATE) AS TxnDate
FROM bronze.sales s
-- Bulletproofed Joins matching on TRIMMED STRINGS for Product and Store:
LEFT JOIN silver.DimProduct p 
    ON TRIM(CAST(s.ProductID AS STRING)) = p.ProductID
LEFT JOIN silver.DimStore st 
    ON TRIM(CAST(s.StoreID AS STRING)) = st.StoreID
-- Bulletproofed Join matching on INT for Customer + SCD Type 2 Date Logic:
LEFT JOIN silver.DimCustomer c 
    ON CAST(TRIM(s.CustomerID) AS INT) = c.CustomerID 
    AND CAST(s.TxnDate AS DATE) >= c.StartDate 
    AND CAST(s.TxnDate AS DATE) <= c.EndDate;