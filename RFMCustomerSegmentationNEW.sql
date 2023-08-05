-- RFM Analysis and Customer Segmentation on Company Sales Data

USE ravensdataprojects;


-- Checking for Unique values
SELECT distinct year_id FROM salesdata;
SELECT distinct productline FROM salesdata;
SELECT distinct country FROM salesdata;
SELECT distinct dealsize FROM salesdata;
SELECT distinct Region FROM salesdata;
SELECT distinct month_id FROM salesdata; 

-- Sales Revenue by Product 
SELECT productline, (SUM(sales), 2) as total_revenue
FROM salesdata
GROUP BY productline
ORDER BY total_revenue DESC;

-- Sales by Year
SELECT year_id, ROUND(SUM(sales), 2) as total_revenue
FROM salesdata
GROUP BY year_id
ORDER BY total_revenue DESC;

-- Sales by Month (Deeper analysis to see why there was a decrease in sales in the year 2005) 
SELECT month_num, ROUND(SUM(sales), 2) as total_revenue
FROM salesdata
WHERE YEAR_id = '2005'
GROUP BY month_num
ORDER BY total_revenue DESC;

-- Sales by Month 2004
SELECT month_num, ROUND(SUM(sales), 2) as total_revenue
FROM salesdata
WHERE YEAR_id = '2004'
GROUP BY month_num 
ORDER BY total_revenue DESC;

-- Sales by Month 2003
SELECT month_num, ROUND(SUM(sales), 2) as total_revenue
FROM salesdata
WHERE YEAR_id = '2003'
GROUP BY month_num 
ORDER BY total_revenue DESC;

-- Sales by Deal Size
SELECT dealsize, ROUND(SUM(sales), 2) as total_revenue
FROM salesdata
GROUP BY dealsize
ORDER BY total_revenue DESC;

-- Best Month for Sales by Year
SELECT month_id, year_id, ROUND(SUM(sales), 2) as total_revenue
FROM salesdata
GROUP BY month_id, year_id
ORDER BY total_revenue DESC;

-- Best Selling Product in November of 2003 and 2004. 
SELECT productline, month_id, year_id, ROUND(SUM(sales), 2) as total_revenue
FROM salesdata
GROUP BY productline, month_id, year_id
ORDER BY total_revenue DESC;

-- RFM ANALAYSIS 
-- Best Customers Using RFM Analysis
SELECT CUSTOMERNAME,
ROUND(SUM(sales), 2) as MonetaryValue,
ROUND(AVG(sales), 2) as AvgValue,
COUNT(ORDERNUMBER) as Frequency,
MAX(date_id) as last_order_date
FROM salesdata
GROUP BY customername
ORDER BY MonetaryValue DESC;

-- Get Recency. Use DATEDIFF to return the count of the datepart between the startdate and enddate. 
SELECT 
    CUSTOMERNAME,
    ROUND(SUM(sales), 2) AS MonetaryValue,
    ROUND(AVG(sales), 2) AS AvgValue,
    COUNT(ORDERNUMBER) AS Frequency,
    MAX(date_id) AS last_order_date,
    TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-', date_id), '%d-%m-%Y'), STR_TO_DATE('01-07-2005', '%d-%m-%Y')) AS Recency
FROM (
    SELECT 
        CUSTOMERNAME,
        sales,
        ORDERNUMBER,
        date_id,
        MAX(date_id) AS last_order_date
    FROM salesdata
    GROUP BY CUSTOMERNAME, sales, ORDERNUMBER, date_id
) AS subquery
GROUP BY CUSTOMERNAME, Recency
ORDER BY MonetaryValue DESC;

-- Use Common Table Expression (CTE) to convert query to prep for NTILE()
WITH rfm_subquery AS (
    SELECT 
        CUSTOMERNAME,
        sales,
        ORDERNUMBER,
        date_id,
        MAX(date_id) AS last_order_date
    FROM salesdata
    GROUP BY CUSTOMERNAME, sales, ORDERNUMBER, date_id
)

, r AS (
    SELECT 
        CUSTOMERNAME,
        SUM(sales) AS MonetaryValue,
        ROUND(AVG(sales), 2) AS AvgValue,
        COUNT(ORDERNUMBER) AS Frequency,
        MAX(date_id) AS last_order_date,
        TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-', MAX(date_id)), '%d-%m-%Y'), STR_TO_DATE('01-07-2005', '%d-%m-%Y')) AS Recency,
        NTILE(4) OVER (ORDER BY TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-', MAX(date_id)), '%d-%m-%Y'), STR_TO_DATE('01-07-2005', '%d-%m-%Y')) DESC) AS rfm_recency,
        NTILE(4) OVER (ORDER BY COUNT(ORDERNUMBER) DESC) AS rfm_frequency,
        NTILE(4) OVER (ORDER BY SUM(sales) DESC) AS rfm_monetary
    FROM rfm_subquery
    GROUP BY CUSTOMERNAME
)

SELECT 
    CUSTOMERNAME,
    MonetaryValue,
    AvgValue,
    Frequency,
    last_order_date,
    Recency,
    rfm_recency,
    rfm_frequency,
    rfm_monetary
FROM r
ORDER BY MonetaryValue DESC;

-- Use another CTE to create 2 more rows for RFM Total and RFM Total String
WITH rfm_subquery AS (
    SELECT 
        CUSTOMERNAME,
        sales,
        ORDERNUMBER,
        date_id,
        MAX(date_id) AS last_order_date
    FROM salesdata
    GROUP BY CUSTOMERNAME, sales, ORDERNUMBER, date_id
),
r AS (
    SELECT 
        CUSTOMERNAME,
        SUM(sales) AS MonetaryValue,
        ROUND(AVG(sales), 2) AS AvgValue,
        COUNT(ORDERNUMBER) AS Frequency,
        MAX(date_id) AS last_order_date,
        TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-', MAX(date_id)), '%d-%m-%Y'), STR_TO_DATE('01-07-2005', '%d-%m-%Y')) AS Recency,
        NTILE(4) OVER (ORDER BY TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-', MAX(date_id)), '%d-%m-%Y'), STR_TO_DATE('01-07-2005', '%d-%m-%Y')) DESC) AS rfm_recency,
        NTILE(4) OVER (ORDER BY COUNT(ORDERNUMBER) DESC) AS rfm_frequency
    FROM rfm_subquery
    GROUP BY CUSTOMERNAME
),
c AS (
    SELECT 
        r.*,
        NTILE(4) OVER (ORDER BY MonetaryValue DESC) AS rfm_monetary
    FROM r
)
SELECT 
    CUSTOMERNAME,
    MonetaryValue,
    AvgValue,
    Frequency,
    last_order_date,
    Recency,
    rfm_recency,
    rfm_frequency,
    rfm_monetary,
    rfm_recency + rfm_frequency + rfm_monetary AS rfm_total,
    CONCAT(rfm_recency, rfm_frequency, rfm_monetary) AS rfm_total_string
FROM c
ORDER BY MonetaryValue DESC;


-- Customer Segmentation
WITH rfm_subquery AS (
    SELECT 
        CUSTOMERNAME,
        sales,
        ORDERNUMBER,
        date_id,
        MAX(date_id) AS last_order_date
    FROM salesdata
    GROUP BY CUSTOMERNAME, sales, ORDERNUMBER, date_id
),
r AS (
    SELECT 
        CUSTOMERNAME,
        SUM(sales) AS MonetaryValue,
        ROUND(AVG(sales), 2) AS AvgValue,
        COUNT(ORDERNUMBER) AS Frequency,
        MAX(date_id) AS last_order_date,
        TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-', MAX(date_id)), '%d-%m-%Y'), STR_TO_DATE('01-07-2005', '%d-%m-%Y')) AS Recency,
        NTILE(4) OVER (ORDER BY TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-', MAX(date_id)), '%d-%m-%Y'), STR_TO_DATE('01-07-2005', '%d-%m-%Y')) DESC) AS rfm_recency,
        NTILE(4) OVER (ORDER BY COUNT(ORDERNUMBER) DESC) AS rfm_frequency
    FROM rfm_subquery
    GROUP BY CUSTOMERNAME
),
c AS (
    SELECT 
        r.*,
        NTILE(4) OVER (ORDER BY MonetaryValue DESC) AS rfm_monetary
    FROM r
)
SELECT 
    CUSTOMERNAME,
    MonetaryValue,
    AvgValue,
    Frequency,
    last_order_date,
    Recency,
    rfm_recency,
    rfm_frequency,
    rfm_monetary,
    rfm_recency + rfm_frequency + rfm_monetary AS rfm_total,
    CONCAT_WS('', rfm_recency, rfm_frequency, rfm_monetary) AS rfm_total_string,
    CASE
        WHEN CONCAT_WS('', rfm_recency, rfm_frequency, rfm_monetary) IN ('311', '411', '331', '312') THEN 'new customers'
        WHEN CONCAT_WS('', rfm_recency, rfm_frequency, rfm_monetary) IN ('111', '112', '121', '122', '123', '132', '211', '212', '114', '141', '131', '113') THEN 'lost customers' 
        WHEN CONCAT_WS('', rfm_recency, rfm_frequency, rfm_monetary) IN ('133', '134', '143', '244', '334', '343', '344', '144', '313', '221', '232', '243') THEN 'regular customers'
        WHEN CONCAT_WS('', rfm_recency, rfm_frequency, rfm_monetary) IN ('433', '434', '443', '444', '223', '222', '213', '322', '231', '421') THEN 'loyal customers' 
        WHEN CONCAT_WS('', rfm_recency, rfm_frequency, rfm_monetary) IN ('323', '333', '321', '422', '332', '432', '233', '423', '234') THEN 'champion customers'
    END AS rfm_segment
FROM c
ORDER BY MonetaryValue DESC;

-- Products Sold Together 
-- 1. Base query to get order number column and the count of all rows, which gives the total number of orders

SELECT ORDERNUMBER, COUNT(*) as total_number_of_orders
FROM salesdata
GROUP BY ORDERNUMBER; 

-- 2. Filter for specific order numbers, and retrive product line, quantity, and sales column. 
SELECT * FROM salesdata
WHERE ORDERNUMBER = 10107; 

-- 3. Find which two products are usually sold together
SELECT ORDERNUMBER
FROM
	(SELECT ORDERNUMBER, COUNT(*) as c
    FROM salesdata
    WHERE status = 'Shipped'
    GROUP BY ORDERNUMBER
    )
    as m
    WHERE c = 2;
    
-- 4. #3 but add Product codes
SELECT PRODUCTCODE 
FROM salesdata
WHERE ORDERNUMBER IN (
SELECT ORDERNUMBER
FROM ( 
	SELECT ORDERNUMBER, COUNT(*) as c
    FROM salesdata
    WHERE status = 'Shipped'
    GROUP BY ORDERNUMBER
    )
    as m
    WHERE c = 2
    ); 
    
-- 5. utilize both order number and product code columns and use GROUP_CONCAT function.
SELECT ORDERNUMBER,
		GROUP_CONCAT(PRODUCTCODE,',') AS Products
FROM salesdata AS p 
WHERE ORDERNUMBER IN (
SELECT ORDERNUMBER 
FROM (
SELECT 
	ORDERNUMBER, COUNT(*) as c
    FROM salesdata
    WHERE status = 'Shipped'
    GROUP BY ORDERNUMBER 
    )
    as m
    WHERE c = 2
    )
    GROUP BY ORDERNUMBER; 

-- 6. Sales per Product Line per Year
SELECT ProductLine, Year_Id, ROUND(SUM(sales),2)  as sales_per_year
FROM salesdata
WHERE ProductLine = 'Classic Cars'
GROUP BY YEAR_ID;

SELECT ProductLine, Year_Id, ROUND(SUM(sales),2)  as sales_per_year
FROM salesdata
WHERE ProductLine = 'Motorcycles'
GROUP BY YEAR_ID;

SELECT ProductLine, Year_Id, ROUND(SUM(sales),2)  as sales_per_year
FROM salesdata
WHERE ProductLine = 'Planes'
GROUP BY YEAR_ID;

SELECT ProductLine, Year_Id, ROUND(SUM(sales),2)  as sales_per_year
FROM salesdata
WHERE ProductLine = 'Ships'
GROUP BY YEAR_ID;

SELECT ProductLine, Year_Id, ROUND(SUM(sales),2)  as sales_per_year
FROM salesdata
WHERE ProductLine = 'Trains'
GROUP BY YEAR_ID;

SELECT ProductLine, Year_Id, ROUND(SUM(sales),2)  as sales_per_year
FROM salesdata
WHERE ProductLine = 'Trucks and Buses'
GROUP BY YEAR_ID;

SELECT ProductLine, Year_Id, ROUND(SUM(sales),2)  as sales_per_year
FROM salesdata
WHERE ProductLine = 'Vintage Cars'
GROUP BY YEAR_ID;











