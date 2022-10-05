USE sakila;

-- Create a complete join table between rental, inventory, film, film_category, category
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


-/*
Identify top 2 categories for each customer based off their past rental history.
*/
SELECT 
	customer_id, 
    name, 
    rental_count
FROM category_rental_count
WHERE category_rank <= 2;


/*
For 1st category (2), identify total films watched, average comparison and percentile. 
For 2nd category (5), identify total films watched and proportion of films watched in percentage.
*/

-- 1st category
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
WHERE category_rank = 1;

-- 2nd category
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
WHERE category_rank = 2;


/*
Identify 3 most popular films for each customer's top 2 categories that customer has not watched.
*/
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
WHERE recommendation_rank <= 3;
