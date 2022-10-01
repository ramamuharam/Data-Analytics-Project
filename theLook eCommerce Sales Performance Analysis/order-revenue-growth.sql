/*
Find monthly growth of number of completed orders and revenue in percentage 
breakdown by product categories, ordered by time descendingly (Jan 2019 until Sep 2022). 
After analyzing the monthly growth, is there any interesting insight that we can get?
*/
WITH cte_order_revenue AS (
  SELECT
    DATE(DATE_TRUNC(oi.created_at, month)) AS month,
    p.category,
    COUNT(DISTINCT oi.order_id) AS completed_order,
    ROUND(SUM(oi.sale_price)) AS revenue
  FROM
    `bigquery-public-data.thelook_ecommerce.order_items` oi
    JOIN `bigquery-public-data.thelook_ecommerce.products` p ON oi.product_id = p.id
  WHERE
    DATE(oi.created_at) BETWEEN '2019-01-01' AND '2022-08-31'
    AND oi.status = 'Complete'
  GROUP BY
    category,
    month
  ORDER BY
    category,
    month
)
SELECT
  month,
  category,
  ROUND((completed_order - LAG(completed_order, 1) OVER(PARTITION BY category ORDER BY month)) * 100.0 / LAG(completed_order, 1) OVER(PARTITION BY category ORDER BY month), 2) AS completed_order_growth_percentage,
  ROUND((revenue - LAG(revenue, 1) OVER(PARTITION BY category ORDER BY month)) * 100.0 / LAG(revenue, 1) OVER(PARTITION BY category ORDER BY month), 2) AS revenue_growth_percentage
FROM 
  cte_order_revenue
ORDER BY
  category,
  month;
