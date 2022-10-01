-- How much are we selling? How many orders going on? And What is the average sales on each order on monthly basis
SELECT
  FORMAT_TIMESTAMP('%Y-%m', o.created_at) AS order_month,
  ROUND(SUM(oi.sale_price), 2) AS revenue,
  ROUND(AVG(sale_price), 2) AS average_sales,
  COUNT(DISTINCT o.order_id) AS order_count
FROM
  `bigquery-public-data.thelook_ecommerce.orders` o
  JOIN `bigquery-public-data.thelook_ecommerce.order_items` oi ON o.order_id = oi.order_id
WHERE
  DATE(o.created_at) BETWEEN '2019-01-01' AND '2022-09-30'
  AND o.status NOT IN ('Cancelled', 'Returned')
GROUP BY
  order_month
ORDER BY
  order_month;


-- Cart Abandonment Rate
WITH cart_to_purchase AS (
  SELECT
    SUM(IF(event_type = 'cart', 1, 0)) AS cart,
    SUM(IF(event_type = 'purchase', 1, 0)) AS purchase
  FROM
    `bigquery-public-data.thelook_ecommerce.events`
)
SELECT 
  ROUND((1 - (purchase / cart)) * 100, 2) AS cart_abandonment_rate
FROM
  cart_to_purchase;


-- What is the top 5 most profitable product on theLook ecommerce store and how much is the profit? Are some product categories selling more than the other?
WITH product_profit AS (
  SELECT
    DATE(DATE_TRUNC(oi.created_at, month)) AS month,
    oi.product_id,
    p.name,
    p.category,
    ROUND(SUM(oi.sale_price), 2) AS sum_sales,
    ROUND(SUM(p.cost),2) AS sum_cost,
    ROUND(SUM(oi.sale_price)-SUM(p.cost),2) AS profit
  FROM
    `bigquery-public-data.thelook_ecommerce.order_items` oi
    LEFT JOIN `bigquery-public-data.thelook_ecommerce.products` p ON oi.product_id = p.id
  WHERE
    DATE(oi.created_at) BETWEEN '2019-01-01' AND '2022-09-30'
    AND oi.status NOT IN ('Cancelled', 'Returned')
  GROUP BY
    month,
    product_id,
    name,
    category
)
SELECT
  month,
  product_id,
  name,
  category,
  sum_sales,
  sum_cost,
  profit,
  RANK() OVER(PARTITION BY month ORDER BY profit DESC) AS profit_rank_per_month
FROM 
  product_profit
QUALIFY
  profit_rank_per_month <= 5
ORDER BY 
  month,
  profit DESC;



-- Who are our customers? Where are they come from? Find out the revenue that customer bring break down by demographics
-- by age range
SELECT
  CASE
    WHEN age >= 12 AND age < 18 THEN "12-18"
    WHEN age >= 18 AND age < 25 THEN "18-24"
    WHEN age >= 25 AND age < 32 THEN "25-31"
    WHEN age >= 32 AND age < 39 THEN "32-38"
    WHEN age >= 39 AND age < 46 THEN "39-45"
    WHEN age >= 46 AND age < 53 THEN "46-52"
    WHEN age >= 53 AND age < 60 THEN "53-59"
    ELSE "60+"
  END AS age_range,
  SUM(oi.sale_price) AS revenue
FROM
  `bigquery-public-data.thelook_ecommerce.users` u
  JOIN `bigquery-public-data.thelook_ecommerce.order_items` oi ON oi.user_id = u.id
GROUP BY
  age_range
ORDER BY
  age_range;
-- by country
SELECT
  country,
  SUM(oi.sale_price) AS revenue
FROM
  `bigquery-public-data.thelook_ecommerce.users` u
  JOIN `bigquery-public-data.thelook_ecommerce.order_items` oi ON oi.user_id = u.id
GROUP BY
  country
ORDER BY
  revenue DESC;
-- by traffic source
SELECT
  traffic_source,
  SUM(oi.sale_price) AS revenue
FROM
  `bigquery-public-data.thelook_ecommerce.users` u
  JOIN `bigquery-public-data.thelook_ecommerce.order_items` oi ON oi.user_id = u.id
GROUP BY
  traffic_source
ORDER BY
  revenue DESC;


