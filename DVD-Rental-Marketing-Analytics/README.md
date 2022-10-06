# DVD Rental Marketing Analytics

## Project Overview

Imagine you're a data analyst working in a DVD rental company. You've been asked to support the Customer Analytics team at DVD Rental Co who have been tasked with generating the necessary data points required to populate specific parts of this first-ever customer email campaign.

The customer email campaign looks like the picture below

![Customer Email Campaign](personalized-recommendations.png)

## Problem Statement

From the campaign that have been shared by the customer analytics team, the problem can be breakdown into 3 parts:

1. Top 2 Categories
    * Identify top 2 categories for each customer based off their past rental history.
2. Individual Customer Insights
    * For 1st category, identify total films watched, average comparison and percentile. 
    * For 2nd category, identify total films watched and proportion of films watched in percentage.
3. Category Film Recommendations
    * Identify 3 most popular films for each customer's top 2 categories that customer has not watched.


We're going to provide the analysis result for each customer, so that the customer analytics team can easily choose the customer they want to make the campaign to.

## Dataset

The dataset used for this project is [Sakila](https://dev.mysql.com/doc/sakila/en/), which is the part of MySQL Sample Database, and because of that I'll be doing this project using MySQL RDBMS. But we're not going to use all of the table inside the Sakila database. The tables that we going to use in the Sakila database:

- `rental`
- `inventory`
- `film`
- `film_category`
- `category`

## Top 2 Categories

Before we continue the analysis, it's better to store some query that we're going to use repeatedly into temporary table.

The first table that I want to store to the temporary table is the join result of `rental-inventory-film-film_category-category`

```sql
DROP TABLE IF EXISTS category_joint_dataset;
CREATE TEMPORARY TABLE category_joint_dataset AS
SELECT
    rental_id,
    rental_date,
    return_date,
    customer_id,
    inventory_id,
    film_id,
    title,
    release_year,
    rental_duration,
    rental_rate,
    length,
    replacement_cost,
    rating,
    category_id,
    name
FROM rental r
JOIN inventory i USING (inventory_id)
JOIN film f USING (film_id)
JOIN film_category fc USING (film_id)
JOIN category c USING (category_id);
```

The next is temporary table to count how many film rented for each customer and genre and rank it based on how much the film is rented.

```sql
-- Create total film rented for each customer and genre
DROP TABLE IF EXISTS category_rental_count;
CREATE TEMPORARY TABLE category_rental_count AS 
SELECT
    customer_id,
    name,
    COUNT(*) AS rental_count,
    ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY COUNT(*) DESC) AS category_rank
FROM category_joint_dataset
GROUP BY 
    customer_id, 
    name;
```

Now we can begin to analysis start from finding the top 2 categories for each customer! 

```sql
SELECT 
    customer_id, 
    name, 
    rental_count
FROM category_rental_count
WHERE category_rank <= 2
LIMIT 6;
```

Result:

|customer_id|name|rental_count|
|---|---|---|
|1|Classic|6|
|1|Comedy|5|
|2|Sports|5|
|2|Classic|4|
|3|Action|4|
|4|Animation|3|

## Individual Customer Insights

We've already count the total film watched for each category. The rest we need to find is 

- For 1st category: the average film watched per customer to compare with the top category and the percentile.
- For 2nd category: proportion of films watched in percentage

### First category

To find the average film watched per customer, we can create a query that calculate the average rental for each customer using `GROUP BY`, but it's easier to do that with window function so no join needed. The same goes for finding percentile which we can achieve using `PERCENT_RANK()` window function. Below is the implementation query.

```sql
WITH first_category_insights AS (
    SELECT 
	customer_id, 
	name, 
	rental_count,
        category_rank,
	-- average category rental
	AVG(rental_count) OVER(PARTITION BY customer_id) AS avg_rental_count,
	-- percentile
	CEILING(100 * PERCENT_RANK() OVER(PARTITION BY name ORDER BY rental_count DESC)) AS percentile
    FROM category_rental_count
    ORDER BY 
        customer_id, 
        rental_count DESC
)
SELECT 
    customer_id,
    name,
    rental_count,
    avg_rental_count,
    ROUND(rental_count / avg_rental_count, 1) AS average_comparison,
    percentile
FROM first_category_insights 
WHERE category_rank = 1
LIMIT 3;
```

Results:

|customer_id|name|rental_count|avg_rental_count|average_comparison|percentile|
|---|---|---|---|---|---|
|1|Classic|6|2.2857|2.6|1
|2|Sports|5|2.0769|2.4|3
|3|Action|5|2.0|2|5

Example for customer 1:
```
You're watched 6 Classic films, that's 2.6 more than the DVD Rental Co average and puts you in the top 1% of the Classic Gurus!
```

### Second category

The additional we needed is the comparison between how many times the customer watch this category of films and the total films watched. Similar to calculating the average watch earlier, it's better to calculate the total films watch using window function then use it to divide the current category films watched.

```sql
WITH second_category_insights AS (
    SELECT 
	customer_id, 
	name, 
	rental_count,
        category_rank,
	-- total category rental
	SUM(rental_count) OVER(PARTITION BY customer_id) AS total_rental_count
    FROM category_rental_count
    ORDER BY 
	customer_id, 
	rental_count DESC
)
SELECT
    customer_id,
    name,
    rental_count,
    total_rental_count,
    ROUND(100 * rental_count / total_rental_count, 2) AS entire_view_percentage
FROM second_category_insights 
WHERE category_rank = 2
LIMIT 3;
```
Results:
|customer_id|name|rental_count|total_rental_count|entire_view_percentage|
|---|---|---|---|---|
|1|Comedy|5|32|15.63|
|2|Classic|4|27|14.81|
|3|Animation|3|26|11.54|

Example for customer 1:
```
You're watched 5 Comedy films, making up 15.63% of your entire viewing history!
```

## Category Film Recommendations

### Film Count 

First, we need to count how many each film are watched on DVD Rental Co. 

```sql
SELECT DISTINCT
    film_id,
    title,
    name,
    COUNT(*) OVER(PARTITION BY film_id) AS total_rental_count
FROM category_joint_dataset
```

### Films that customer have watched

For the next step in our recommendation analysis, we will need to generate a table with all of our customer’s previously watched films so we don’t recommend them something which they’ve already seen before.

```sql
SELECT DISTINCT 
    customer_id, 
    film_id
FROM category_joint_dataset
```

### Final Category Recommendations

In this part, we will perform an `ANTI JOIN` using a `WHERE NOT EXISTS` SQL implementation for the top 2 categories so that we can get the necessary information for generating my final category recommendations table. We also need to make the film rank based on how many film have been watched that we've already query earlier.

```sql
WITH film_counts AS (
    SELECT DISTINCT
	film_id,
	title,
	name,
	COUNT(*) OVER(PARTITION BY film_id) AS total_rental_count
    FROM category_joint_dataset
), category_film_exclusions AS (
    SELECT DISTINCT 
        customer_id, 
        film_id
    FROM rental r
    JOIN inventory i USING (inventory_id)
    JOIN film f USING (film_id)
    JOIN film_category fc USING (film_id)
    JOIN category c USING (category_id)
), film_recommendations AS (
    SELECT
	customer_id,
	category_rental_count.name,
	category_rank,
	film_id,
	title,
	total_rental_count,
	DENSE_RANK() OVER(
	    PARTITION BY 
		customer_id,
		category_rental_count.name
	    ORDER BY
		total_rental_count DESC,
		title
	) AS recommendation_rank
	FROM category_rental_count
	JOIN film_counts ON category_rental_count.name = film_counts.name
	WHERE NOT EXISTS (
	    SELECT customer_id
	    FROM category_film_exclusions
	    WHERE 
		category_film_exclusions.customer_id = category_rental_count.customer_id
		AND category_film_exclusions.film_id = film_counts.film_id
	) AND category_rank <= 2
)
SELECT *
FROM film_recommendations
WHERE recommendation_rank <= 3
LIMIT 6;
```

Results:
|customer_id|name|category_rank|film_id|title|total_rental_count|recommendation_rank|
|---|---|---|---|---|---|---|
|1|Classics|1|891|TIMBERLAND SKY|31|1|
|1|Classics|1|358|GILMORE BOILED|28|2|
|1|Classics|1|951|VOYAGE LEGALLY|28|3|
|1|Comedy|2|1000|ZORRO ARK|31|1|
|1|Comedy|2|127|CAT CODEHEADS|30|2|
|1|Comedy|2|638|OPERATION OPERATION|27|3|

Findings for customer 1:
```
1ST CATEGORY: Classics
Your expertly chosen recommendations:
TIMBERLAND SKY
TIMBERLAND SKY
VOYAGE LEGALLY

2ND CATEGORY: Comedy
Your expertly chosen recommendations:
ZORRO ARK
CAT CONEHEADS
OPERATION OPERATION
```

## Conclusion

That's the analysis and data we provide to the customer analytics team. We can easily personalized the recommendation for each customer just by filter by `customer_id` and join to the `customer` tbale for the complete customer information. 
