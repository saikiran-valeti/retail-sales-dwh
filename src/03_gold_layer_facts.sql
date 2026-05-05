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

-- 2. Transform and Load the Facts
INSERT INTO gold.FactSales (TransactionID, CustomerSK, ProductSK, StoreSK, Quantity, Amount, TxnDate)
SELECT 
    s.TransactionID,
    c.CustomerSK,
    p.ProductSK,
    st.StoreSK,
    s.Quantity,
    CAST((s.Quantity * p.UnitPrice) AS DECIMAL(10,2)) AS Amount,
    CAST(s.TxnDate AS DATE) AS TxnDate
FROM bronze.sales s
-- Join Product (Static)
LEFT JOIN silver.DimProduct p 
    ON s.ProductID = p.ProductID
-- Join Store (Static)
LEFT JOIN silver.DimStore st 
    ON s.StoreID = st.StoreID
-- Join Customer (SCD Type 2 Time-Travel Join)
LEFT JOIN silver.DimCustomer c 
    ON s.CustomerID = c.CustomerID 
    AND CAST(s.TxnDate AS DATE) >= c.StartDate 
    AND CAST(s.TxnDate AS DATE) <= c.EndDate;