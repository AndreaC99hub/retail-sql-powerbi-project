USE retail_project;

SELECT COUNT(*) AS total_rows
FROM retail_project.online_retail_bulk;

SELECT *
FROM retail_project.online_retail_bulk
LIMIT 10; 

SELECT DISTINCT Country
FROM retail_project.online_retail_bulk
ORDER BY Country ASC;

SELECT COUNT(*) AS NumberofRows, Country
FROM retail_project.online_retail_bulk
GROUP BY Country
ORDER BY COUNT(*) DESC;

SELECT COUNT(*)
FROM online_retail_bulk
WHERE CustomerID='' OR CustomerID IS NULL;

SELECT*
FROM online_retail_bulk
WHERE InvoiceNo LIKE 'C%'
LIMIT 10;

-- Data type conversion

SELECT CAST(REPLACE (UnitPrice, ',','.') as decimal (12,2)) as UnitPriceDec
FROM online_retail_bulk
LIMIT 10;

SELECT InvoiceDate, STR_TO_DATE(InvoiceDate, '%d/%m/%Y %H:%i') as InvoiceDateConverted
FROM online_retail_bulk
LIMIT 10;

SELECT Quantity, CAST(Quantity as signed) as QuantityConverted
FROM online_retail_bulk
LIMIT 10;

SELECT *, CAST(Quantity as signed) as QuantityConverted, STR_TO_DATE(InvoiceDate, '%d/%m/%Y %H:%i') as InvoiceDateConverted, CAST(REPLACE (UnitPrice, ',','.') as decimal (12,2)) as UnitPriceConverted
FROM online_retail_bulk
LIMIT 10;

CREATE TABLE online_retail_clean AS
SELECT InvoiceNo, StockCode, Description, CAST(Quantity as signed) as QuantityConverted, STR_TO_DATE(InvoiceDate, '%d/%m/%Y %H:%i') as InvoiceDateConverted, CAST(REPLACE (UnitPrice, ',','.') as decimal (12,2)) as UnitPriceConverted, CustomerID, Country
FROM online_retail_bulk;

SELECT *
FROM online_retail_clean
LIMIT 10;

SELECT COUNT(*) AS TotalRowsClean
FROM online_retail_clean;

SELECT COUNT(*) AS NullDatesRows
FROM online_retail_clean
WHERE InvoiceDateConverted IS NULL;

SELECT MIN(InvoiceDateConverted), MAX(InvoiceDateConverted), MIN(QuantityConverted), MAX(QuantityConverted), MIN(UnitPriceConverted), MAX(UnitPriceConverted)
FROM online_retail_clean;

SELECT COUNT(*) AS NegativeQuantityRows
FROM online_retail_clean
WHERE QuantityConverted<0;

SELECT COUNT(*) AS NegativePriceRows
FROM online_retail_clean
WHERE UnitPriceConverted<0;

SELECT COUNT(*) AS Price0Rows
FROM online_retail_clean
WHERE UnitPriceConverted=0;

SELECT *
FROM online_retail_clean
WHERE UnitPriceConverted<0;

SELECT *
FROM online_retail_clean
WHERE QuantityConverted<0
LIMIT 10;

SELECT *
FROM online_retail_clean
WHERE QuantityConverted<0 AND InvoiceNo NOT LIKE 'C%';

SELECT SUM(QuantityConverted*UnitPriceConverted) AS PositiveSalesValue
FROM online_retail_clean
WHERE UnitPriceConverted>0 AND QuantityConverted>0 AND InvoiceNo NOT LIKE 'C%';

SELECT COUNT(*) AS TotalPositiveTransactions
FROM online_retail_clean
WHERE UnitPriceConverted>0 AND QuantityConverted>0 AND InvoiceNo NOT LIKE 'C%';

SELECT COUNT(*), InvoiceNo, StockCode, Description, QuantityConverted, InvoiceDateConverted, UnitPriceConverted, CustomerID, Country
FROM online_retail_clean
GROUP BY InvoiceNo, StockCode, Description, QuantityConverted, InvoiceDateConverted, UnitPriceConverted, CustomerID, Country
HAVING COUNT(*)>1
LIMIT 10;

/*
I remove exact duplicate rows because I treat them as repeated records.
The original data is maintained for comparison.
*/

CREATE TABLE online_retail_dedup
AS SELECT DISTINCT *
FROM online_retail_clean;

SELECT COUNT(*) AS TotalRowsDedup
FROM online_retail_dedup;

SELECT *, QuantityConverted*UnitPriceConverted AS SalesValue
FROM online_retail_dedup
LIMIT 10;

SELECT *, CASE
WHEN UnitPriceConverted<0 THEN 'Accounting adjustment'
WHEN InvoiceNo LIKE 'C%' THEN 'Cancellation/Credit'
WHEN QuantityConverted<0 AND InvoiceNo NOT LIKE 'C%' THEN 'Other adjustment'
WHEN QuantityConverted>0 AND UnitPriceConverted>0 THEN 'Positive sale'
ELSE 'Other/Review'
END AS TransactionType
FROM online_retail_dedup
LIMIT 10;

-- I create the final reporting view with a classification of the transactions

CREATE OR REPLACE VIEW retail_reporting AS 
SELECT *, 
QuantityConverted*UnitPriceConverted AS SalesValue, 
DATE(InvoiceDateConverted) AS InvoiceDateOnly, 
CASE
WHEN UnitPriceConverted<0 THEN 'Accounting adjustment'
WHEN InvoiceNo LIKE 'C%' THEN 'Cancellation/Credit'
WHEN QuantityConverted<0 AND InvoiceNo NOT LIKE 'C%' THEN 'Other adjustment'
WHEN QuantityConverted>0 AND UnitPriceConverted>0 THEN 'Positive sale'
ELSE 'Other/Review'
END AS TransactionType
FROM online_retail_dedup;

SELECT 'raw' AS Stage, COUNT(*) AS RowCount FROM online_retail_bulk
UNION ALL
SELECT 'deduplicated', COUNT(*) FROM online_retail_dedup
UNION ALL
SELECT 'reporting', COUNT(*) FROM retail_reporting
UNION ALL
SELECT 'value', COUNT(*) FROM retail_reporting WHERE TransactionType='Positive sale';

SELECT SUM(SalesValue) AS PositiveSalesValue, 
YEAR(InvoiceDateOnly) AS Year, 
MONTH(InvoiceDateOnly) AS Month
FROM retail_reporting
WHERE TransactionType='Positive sale'
GROUP BY YEAR(InvoiceDateOnly), MONTH(InvoiceDateOnly)
ORDER BY YEAR(InvoiceDateOnly), MONTH(InvoiceDateOnly);

-- December 2011 is incomplete, after the 9th there is no data available.

SELECT SUM(SalesValue) AS TotalValue, COUNT(*), TransactionType
FROM retail_reporting
GROUP BY TransactionType;

SELECT SalesValue, TransactionType
FROM retail_reporting
WHERE TransactionType IN('Other/Review','Other adjustment')
AND (SalesValue<>0 OR SalesValue IS NULL);

SELECT COUNT(DISTINCT InvoiceNo) AS NofPosDistinctTransactions
FROM retail_reporting
WHERE TransactionType='Positive sale';

SELECT COUNT(DISTINCT CustomerID) AS NumberOfClients
FROM retail_reporting
WHERE TransactionType='Positive sale' AND CustomerID IS NOT NULL AND CustomerID !='';