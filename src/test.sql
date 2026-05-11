USE CATALOG retail_project;
USE SCHEMA bronze;

select * from customers;
select * from stores;
select * from products;
select * from sales;

SELECT 'dim_customer' AS table_name, COUNT(*) AS total_rows,
       SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END) AS active_rows
FROM retail_project.silver.dimcustomer
UNION ALL
SELECT 'dim_product', COUNT(*), NULL FROM retail_project.silver.dimproduct
UNION ALL
SELECT 'dim_store',   COUNT(*), NULL FROM retail_project.silver.dimstore
UNION ALL
SELECT 'fact_sales',  COUNT(*), NULL FROM retail_project.gold.factsales;

USE CATALOG retail_project;
drop table silver.dimcustomer;
drop table silver.dimproduct;
drop table silver.dimstore;
drop table gold.factsales;

USE CATALOG retail_project;
USE SCHEMA silver;

USE CATALOG retail_project;
select * from gold.factsales;
