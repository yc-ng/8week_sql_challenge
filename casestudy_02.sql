/*
Cleaning customer_orders
- Identify records with null or 'null' values
- updating null or 'null' values to ''
- blanks '' are not null because it indicates the customer asked for no extras or exclusions
*/

SELECT
  *
FROM
  pizza_runner.customer_orders
WHERE
     customer_id IS NULL
  OR pizza_id IS NULL
  OR exclusions IS NULL OR exclusions LIKE 'null'
  OR extras IS NULL OR extras LIKE 'null'
  OR order_time IS NULL;

/* modifying the tables in place is not encouraged - we want to keep the source data
but if it is required - use UPDATE statements
UPDATE pizza_runner.customer_orders
SET
  exclusions = ''
WHERE
  exclusions IS NULL OR exclusions = 'null'
RETURNING *;

UPDATE pizza_runner.customer_orders
SET
  extras = ''
WHERE
  extras IS NULL OR extras = 'null'
RETURNING *;
*/

DROP TABLE IF EXISTS clean_customer_orders;
CREATE TEMP TABLE clean_customer_orders AS (
  SELECT
    order_id,
    customer_id,
    pizza_id,
    CASE 
      WHEN exclusions IS NULL 
        OR exclusions LIKE 'null' THEN ''
      ELSE exclusions 
    END AS exclusions,
    CASE 
      WHEN extras IS NULL
        OR extras LIKE 'null' THEN ''
      ELSE extras 
    END AS extras,
    order_time
  FROM pizza_runner.customer_orders
);

/* Cleaning runner orders
- pickup time, distance, duration is of the wrong type
- records have nulls in these columns when the orders are cancelled
- convert text 'null' to null values
- units (km, minutes) need to be removed from distance and duration
*/

DROP TABLE IF EXISTS clean_runner_orders;
CREATE TEMP TABLE clean_runner_orders AS (
  SELECT
    order_id,
    runner_id,
    CASE
      WHEN pickup_time LIKE 'null' THEN null
      ELSE pickup_time
    END::timestamp AS pickup_time,
    -- extract numbers and decimal points only. set to NULL if there are no numbers or decimal points
    NULLIF(regexp_replace(distance, '[^0-9.]','','g'), '')::numeric AS distance_km,
    NULLIF(regexp_replace(duration, '[^0-9.]','','g'), '')::numeric as duration_mins,
    CASE
      WHEN cancellation IN ('null', 'NaN', '') THEN null
      ELSE cancellation
    END AS cancellation
  FROM pizza_runner.runner_orders
);

-- cleaning text using REPLACE
SELECT
  CASE
    WHEN distance LIKE 'null' THEN null
    ELSE REPLACE(distance, 'km', '') 
  END::numeric AS distance
FROM runner_orders;

SELECT
  CASE
    WHEN duration LIKE 'null' THEN null
    ELSE REPLACE(left(duration, 3), 'm', '')
  END::numeric as duration
FROM
  runner_orders;

-- data type check
SELECT
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'clean_customer_orders'

SELECT
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'clean_runner_orders'



--- questions
  
-- How many pizzas were ordered?

SELECT
  COUNT(pizza_id)
FROM
  clean_customer_orders;

-- How many unique customer orders were made?

SELECT
  COUNT(DISTINCT order_id)
FROM
  clean_customer_orders;

-- How many successful orders were delivered by each runner?

SELECT
  runner_id,
  COUNT(order_id) AS orders_delivered
FROM clean_runner_orders
WHERE pickup_time IS NOT NULL
GROUP BY runner_id

-- How many of each type of pizza was delivered?

SELECT
  pizza_names.pizza_name,
  COUNT(*) AS pizzas_ordered
FROM clean_customer_orders AS co
INNER JOIN clean_runner_orders AS ro
  ON co.order_id = ro.order_id
INNER JOIN pizza_runner.pizza_names
  ON co.pizza_id = pizza_names.pizza_id
WHERE ro.distance_km IS NOT NULL -- filter out pizzas that are not delivered
GROUP BY pizza_name
ORDER BY pizza_name;

-- How many Vegetarian and Meatlovers were ordered by each customer?

SELECT
  co.customer_id,
  pz.pizza_name,
  COUNT(*) AS pizzas_ordered
FROM clean_customer_orders AS co
INNER JOIN pizza_runner.pizza_names AS pz
  ON co.pizza_id = pz.pizza_id
GROUP BY co.customer_id, pz.pizza_name
ORDER BY co.customer_id, pz.pizza_name;

-- What was the maximum number of pizzas delivered in a single order?

WITH delivery_counts AS (
  SELECT
    co.order_id,
    COUNT(*) AS pizzas_delivered
  FROM clean_customer_orders AS co
  INNER JOIN clean_runner_orders AS ro
    ON co.order_id = ro.order_id
  WHERE ro.distance_km IS NOT NULL -- filter out pizzas that are not delivered
  GROUP BY co.order_id
  ORDER BY pizzas_delivered DESC
)

SELECT
  order_id,
  pizzas_delivered
FROM delivery_counts
WHERE pizzas_delivered = 
  (SELECT MAX(pizzas_delivered) FROM delivery_counts);

-- For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

WITH pizza_changes AS (
  SELECT
    co.*,
    CASE
      WHEN co.extras = '' 
       AND co.exclusions = '' THEN 'No'
      ELSE 'Yes' 
    END AS with_changes
  FROM clean_customer_orders AS co
  INNER JOIN clean_runner_orders AS ro
    ON co.order_id = ro.order_id
  WHERE ro.pickup_time IS NOT NULL
)

SELECT
  customer_id,
  with_changes,
  COUNT(*) AS pizzas_delivered
FROM pizza_changes
GROUP BY customer_id, with_changes
ORDER BY customer_id, with_changes DESC;

-- How many pizzas were delivered that had both exclusions and extras?

WITH pizza_changes_2 AS (
  SELECT
    co.*,
    CASE
      WHEN co.extras <> '' 
       AND co.exclusions <> '' THEN 'Yes'
      ELSE 'No' 
    END AS with_both_changes
  FROM clean_customer_orders AS co
  INNER JOIN clean_runner_orders AS ro
    ON co.order_id = ro.order_id
  WHERE ro.distance_km IS NOT NULL
)

SELECT
  with_both_changes,
  COUNT(*) AS pizzas_delivered
FROM pizza_changes_2
GROUP BY with_both_changes
ORDER BY with_both_changes DESC;

-- What was the total volume of pizzas ordered for each hour of the day?

SELECT
  DATE_PART('hour', order_time) AS hour_of_order,
  COUNT(pizza_id) AS pizzas_ordered
FROM clean_customer_orders
GROUP BY DATE_PART('hour', order_time)
ORDER BY hour_of_order;

-- What was the volume of orders for each day of the week?

SELECT
  DATE_PART('dow', order_time) AS day_of_week,
  COUNT(pizza_id) AS pizzas_ordered
FROM clean_customer_orders
GROUP BY DATE_PART('dow', order_time)
ORDER BY day_of_week;

-- B. Runner and Customer Experience

-- How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

WITH runner_signups AS (
  SELECT
    runner_id,
    registration_date,
    registration_date - ((registration_date - '2021-01-01') % 7)  AS start_of_week
  FROM pizza_runner.runners
)

SELECT
  start_of_week,
  COUNT(runner_id) AS signups
FROM runner_signups
GROUP BY start_of_week

-- What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

WITH runner_pickups AS (
  SELECT
    ro.runner_id,
    ro.order_id,
    co.order_time,
    ro.pickup_time,
    (pickup_time - order_time) AS time_to_pickup
  FROM clean_runner_orders AS ro
  INNER JOIN clean_customer_orders AS co
    ON ro.order_id = co.order_id
)

SELECT 
  runner_id,
  date_part('minutes', AVG(time_to_pickup)) AS avg_arrival_minutes
FROM runner_pickups
GROUP BY runner_id
ORDER BY runner_id;

-- Is there any relationship between the number of pizzas and how long the order takes to prepare?

WITH order_quant AS (
  SELECT
    order_id,
    order_time,
    COUNT(pizza_id) AS pizzas_ordered
  FROM clean_customer_orders
  GROUP BY order_id, order_time
), 
quant_times AS (
  SELECT
    ro.order_id,
    co.order_time,
    ro.pickup_time,
    co.pizzas_ordered,
    (pickup_time - order_time) AS time_to_pickup
  FROM clean_runner_orders AS ro
  INNER JOIN order_quant AS co
    ON ro.order_id = co.order_id
  WHERE pickup_time IS NOT NULL
)

SELECT
  pizzas_ordered,
  AVG(time_to_pickup) AS avg_time
FROM quant_times
GROUP BY pizzas_ordered
ORDER BY pizzas_ordered;

-- What was the average distance travelled for each runner?

SELECT
  runner_id,
  ROUND(
    AVG(distance_km), 2
    ) AS distance_km
FROM clean_runner_orders
GROUP BY runner_id
ORDER BY runner_id;

-- What was the difference between the longest and shortest delivery times for all orders?

SELECT
  MAX(duration_mins) - MIN(duration_mins) AS difference_mins
FROM clean_runner_orders;

-- What was the average speed for each runner for each delivery and do you notice any trend for these values?

WITH order_quant AS (
  SELECT
    order_id,
    order_time,
    COUNT(pizza_id) AS pizzas_ordered
  FROM clean_customer_orders
  GROUP BY order_id, order_time
)

  SELECT
    ro.order_id,
    ro.runner_id,
    co.pizzas_ordered,
    ro.distance_km,
    ro.duration_mins,
    ROUND(60 * ro.distance_km / ro.duration_mins, 2) AS speed 
  FROM clean_runner_orders AS ro
  INNER JOIN order_quant AS co
    ON ro.order_id = co.order_id
  WHERE pickup_time IS NOT NULL
  ORDER BY speed DESC

-- What is the successful delivery percentage for each runner?

SELECT
  runner_id,
  COUNT(pickup_time) as delivered,
  COUNT(order_id) AS total,
  ROUND(100 * COUNT(pickup_time) / COUNT(order_id)) AS delivery_pct
FROM clean_runner_orders
GROUP BY runner_id
ORDER BY runner_id;
