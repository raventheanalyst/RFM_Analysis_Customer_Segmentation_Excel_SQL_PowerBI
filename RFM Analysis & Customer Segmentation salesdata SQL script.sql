-- RFM Analysis & Customer Segementation

USE ravensdataprojects;
SELECT * FROM salesdata;


DESCRIBE salesdata;

-- Inspect data for analysis

SELECT COUNT(*) -- how many records is there?
FROM salesdata;

SELECT COUNT(distinct(CUSTOMERNAME)) as unique_customernames, COUNT(distinct(ORDERNUMBER)) as unique_ordernumbers -- check distinct values
FROM salesdata; 

SELECT COUNT(*) -- check for any null values 
FROM salesdata
WHERE ORDERNUMBER IS NULL OR QUANTITYORDERED IS NULL OR ORDERLINENUMBER IS NULL OR SALES IS NULL;

-- Exploring the data

SELECT CUSTOMERNAME, SUM(QUANTITYORDERED) as total_orders, ROUND(SUM(PRICEEACH), 2) as total_sales -- spending by Company
FROM salesdata
GROUP BY CUSTOMERNAME
ORDER BY total_sales DESC; 

SELECT City, SUM(QUANTITYORDERED) as total_orders, ROUND(SUM(PRICEEACH), 2) as total_sales	-- Spending by City
FROM salesdata
GROUP BY city
ORDER BY total_sales DESC; 

SELECT State, SUM(QUANTITYORDERED) as total_orders, ROUND(SUM(PRICEEACH), 2) as total_sales	-- Spending by State
FROM salesdata
GROUP BY state
ORDER BY total_sales DESC; 

SELECT City, SUM(QUANTITYORDERED) as total_orders, ROUND(SUM(PRICEEACH), 2) as total_sales	-- Spending by City
FROM salesdata
GROUP BY city
ORDER BY total_sales DESC; 

SELECT Country, SUM(QUANTITYORDERED) as total_orders, ROUND(SUM(PRICEEACH), 2) as total_sales	-- Spending by Country
FROM salesdata
GROUP BY Country
ORDER BY total_sales DESC; 

SELECT Region, SUM(QUANTITYORDERED) as total_orders, ROUND(SUM(PRICEEACH), 2) as total_sales	-- Spending by Region
FROM salesdata
GROUP BY Region
ORDER BY total_sales DESC; 

SELECT distinct year_id, customername, sum(QUANTITYORDERED) as total_orders, ROUND(SUM(PRICEEACH), 2) as total_sales -- Spending by year and customername
FROM salesdata
GROUP BY year_ID, customername
ORDER BY total_sales DESC; 

-- Recency, Frequency, and Monetary -- 

SELECT * FROM salesdata; 

-- (Create new "date_id" column for a more usable date column)

ALTER TABLE salesdata
ADD COLUMN date_id VARCHAR(7); -- date format MM-YYYY 

DESCRIBE salesdata; 

UPDATE salesdata
SET date_id = CONCAT(LPAD(month_id, 2, '0'), '-', year_id); -- hmmm... 

-- (hmm.. not quite what we wanted, let's try this again) 
ALTER TABLE salesdata
ADD COLUMN month_num SMALLINT; 

UPDATE salesdata
SET month_num = CASE 
	WHEN month_id = 'January' THEN '01'
    WHEN month_id = 'February' THEN '02'
    WHEN month_id = 'March' THEN '03'
    WHEN month_id = 'April' THEN '04' 
    WHEN month_id = 'May' THEN '05'
    WHEN month_id = 'June' THEN '06'
    WHEN month_id = 'July' THEN '07'
    WHEN month_id = 'August' THEN '08'
    WHEN month_id = 'September' THEN '09'
    WHEN month_id = 'October' THEN '10' 
    WHEN month_id = 'November' THEN '11'
    WHEN month_id = 'December' THEN '12' 
    END;
    
    SELECT month_num
    FROM salesdata; 

UPDATE salesdata
SET date_id = NULL; 

UPDATE salesdata
SET date_id = CONCAT(LPAD(month_num, 2, '0'), '-', year_id);

SELECT date_id
FROM salesdata;

-- (Perfect! Just what we wanted, now back to the RFM Analysis) 

									-- Calculate days between the last customer's purchase date to the current date (07.22.2005)
SELECT CUSTOMERNAME, City,
       TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-', date_id), '%d-%m-%Y'), STR_TO_DATE('01-07-2005', '%d-%m-%Y')) AS last_date_order_months,
       SUM(quantityordered) AS total_orders,
       ROUND(SUM(priceeach), 2) AS spending
FROM salesdata
GROUP BY CUSTOMERNAME, City, date_id
ORDER BY last_date_order_months;

									-- Find percentile of last_date_order_months, total_orders, and spending columns using CTE for previous query
   WITH RFM as (
   SELECT CUSTOMERNAME, City,
       TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-', date_id), '%d-%m-%Y'), STR_TO_DATE('01-07-2005', '%d-%m-%Y')) AS last_date_order_months,
       SUM(quantityordered) AS total_orders,
       ROUND(SUM(priceeach), 2) AS spending
FROM salesdata
GROUP BY CUSTOMERNAME, City, date_id
ORDER BY last_date_order_months
)
SELECT *,
	ntile(3) over (order by last_date_order_months) as rfm_recency,
    ntile(3) over (order by total_orders) as rfm_frequency,
    ntile(3) over (order by spending) as rfm_monetary
FROM rfm;
									-- calculate total RFM score and code for segmentation purposes
   WITH RFM as (
   SELECT CUSTOMERNAME, City,
       TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-', date_id), '%d-%m-%Y'), STR_TO_DATE('01-07-2005', '%d-%m-%Y')) AS last_date_order_months,
       SUM(quantityordered) AS total_orders,
       ROUND(SUM(priceeach), 2) AS spending
FROM salesdata
GROUP BY CUSTOMERNAME, City, date_id
ORDER BY last_date_order_months
),
rfm_calc as (
SELECT *, 
ntile(3) over (order by last_date_order_months) as rfm_recency,
ntile(3) over (order by total_orders) as rfm_frequency,
ntile(3) over (order by spending) as rfm_monetary
from rfm 
order by rfm_monetary desc 
)
select *, rfm_recency +  rfm_frequency + rfm_monetary as rfm_score,
concat( rfm_recency, rfm_frequency, rfm_monetary) as rfm
from rfm_calc;                

-- RFM and Customer Segmentation -- 

SELECT *, CASE
	WHEN RFM in (311, 312, 311) then 'new customers'
	WHEN RFM in (111, 121, 131, 122, 133, 113, 112, 132) then 'lost customers'
	WHEN RFM in (212, 313, 123, 221, 211, 232) then 'regular customers'
	WHEN RFM in (223, 222, 322, 231, 321, 331) then 'loyal customers'
	WHEN RFM in (333, 332, 323, 233) then 'chamption customers'
    end rfm_segment
    from 
    (
  WITH RFM as (
   SELECT CUSTOMERNAME, City,
       TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-', date_id), '%d-%m-%Y'), STR_TO_DATE('01-07-2005', '%d-%m-%Y')) AS last_date_order_months,
       SUM(quantityordered) AS total_orders,
       ROUND(SUM(priceeach), 2) AS spending
FROM salesdata
GROUP BY CUSTOMERNAME, City, date_id
ORDER BY last_date_order_months
),  
rfm_calc as (
SELECT *, 
ntile(3) over (order by last_date_order_months) as rfm_recency,
ntile(3) over (order by total_orders) as rfm_frequency,
ntile(3) over (order by spending) as rfm_monetary
from rfm 
order by rfm_monetary desc 
)
select *, rfm_recency +  rfm_frequency + rfm_monetary as rfm_score,
concat( rfm_recency, rfm_frequency, rfm_monetary) as rfm
from rfm_calc
) rfm_tb; 