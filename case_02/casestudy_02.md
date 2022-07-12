# Case Study 2: Data Pre-Processing

Data issues in the existing schema include:

* `customer_orders` table
  * `null` values entered as text
  * using both `NaN` and `null` values
* `runner_orders` table
  * `null` values entered as text
  * using both `NaN` and `null` values
  * units manually entered in `distance` and `duration` columns

----
## Processing `customer_orders`

Data pre-processing steps include:

* Converting `null` and `NaN` values into blanks `''` in `exclusions` and `extras`
  * Blanks indicate that the customer requested no extras/exclusions for the pizza, whereas `null` values would be ambiguous on this.
* Saving the transformations in a temporary table
  * We want to avoid permanently changing the raw data via `UPDATE` commands if possible.

```sql
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
```

First 5 rows of `clean_customer_orders`:
|order_id|customer_id|pizza_id|exclusions|extras|order_time              |
|--------|-----------|--------|----------|------|------------------------|
|1       |101        |1       |          |      |2020-01-01T18:05:02.000Z|
|2       |101        |1       |          |      |2020-01-01T19:00:52.000Z|
|3       |102        |1       |          |      |2020-01-02T12:51:23.000Z|
|3       |102        |2       |          |      |2020-01-02T12:51:23.000Z|
|4       |103        |1       |4         |      |2020-01-04T13:23:46.000Z|


----

## Processing `runner_orders`

Data pre-processing steps include:

* Converting 'null' text values into `null` values for `pickup_time`, `distance` and `duration`
* Extracting only numbers and decimal spaces for the `distance` and `duration` columns
  * Use regular expressions and `NULLIF` to convert non-numeric entries to `null` values
  * We assume that all `distance` values are in km, and all `duration` values are in minutes.
* Converting blanks, 'null' and NaN into `null` values for `cancellation`
* Saving the transformations in a temporary table

```sql 
DROP TABLE IF EXISTS clean_runner_orders;
CREATE TEMP TABLE clean_runner_orders AS (
  SELECT
    order_id,
    runner_id,
    CASE
      WHEN pickup_time LIKE 'null' THEN null
      ELSE pickup_time
    END::timestamp AS pickup_time,
    -- for distance and duration, extract numbers and decimal points only. 
    -- set to NULL if there are no numbers or decimal points
    NULLIF(regexp_replace(distance, '[^0-9.]','','g'), '')::numeric AS distance_km,
    NULLIF(regexp_replace(duration, '[^0-9.]','','g'), '')::numeric as duration_mins,
    CASE
      WHEN cancellation IN ('null', 'NaN', '') THEN null
      ELSE cancellation
    END AS cancellation
  FROM pizza_runner.runner_orders
);
```
First 5 rows of `clean_runner_orders`:
|order_id|runner_id|pickup_time|distance_km|duration_mins|cancellation            |
|--------|---------|-----------|-----------|-------------|------------------------|
|1       |1        |2020-01-01T18:15:34.000Z|20         |32           |*null*                    |
|2       |1        |2020-01-01T19:10:54.000Z|20         |27           |*null*                    |
|3       |1        |2020-01-02T00:12:37.000Z|13.4       |20           |*null*                    |
|4       |2        |2020-01-04T13:53:03.000Z|23.4       |40           |*null*                    |
|5       |3        |2020-01-08T21:10:57.000Z|10         |15           |*null*                    |

The column data types are as follows:
|column_name|data_type|
|-----------|---------|
|order_id   |integer  |
|runner_id  |integer  |
|pickup_time|timestamp without time zone|
|distance_km|numeric  |
|duration_mins|numeric  |
|cancellation|character varying|

----

# A. Pizza Metrics - questions

## How many pizzas were ordered?

The `customer_orders` level of granularity is the pizza (one or many per order), so the number of pizzas ordered is the number of rows in this table.

```sql
SELECT
  COUNT(pizza_id) AS pizzas_ordered
FROM
  clean_customer_orders;
```
|pizzas_ordered|
|--------------|
|14            |

## How many unique customer orders were made?

We need to use `DISTINCT` when counting `order_id` in `customer_orders` because there may be duplicate `order_id`s for orders containing multiple pizzas.

```sql
SELECT
  COUNT(DISTINCT order_id) AS orders_made
FROM
  clean_customer_orders;
```
|orders_made|
|-----------|
|10         |

## How many successful orders were delivered by each runner?

Assuming that successful orders have a `pickup_time` recorded, we filter out unsuccessful orders that would have `NULL` values for `pickup_time`.

```sql
SELECT
  runner_id,
  COUNT(order_id) AS orders_delivered
FROM clean_runner_orders
WHERE pickup_time IS NOT NULL
GROUP BY runner_id
```
|runner_id|orders_delivered|
|---------|----------------|
|1        |4               |
|2        |3               |
|3        |1               |


## How many of each type of pizza was delivered?

We join the `customer_orders` to `runner_orders` to filter out pizzas that were not delivered, and then join to `pizza_names` to retrieve the names of the pizza based on the `pizza_id`.

```sql
SELECT
  pizza_names.pizza_name,
  COUNT(*) AS pizzas_ordered
FROM clean_customer_orders AS co
INNER JOIN clean_runner_orders AS ro
  ON co.order_id = ro.order_id
INNER JOIN pizza_runner.pizza_names
  ON co.pizza_id = pizza_names.pizza_id
WHERE ro.pickup_time IS NOT NULL -- filter out pizzas that are not delivered
GROUP BY pizza_name
ORDER BY pizza_name;
```
|pizza_name|pizzas_ordered|
|----------|--------------|
|Meatlovers|9             |
|Vegetarian|3             |

## How many Vegetarian and Meatlovers were ordered by each customer?

Unlike previous questions, this includes pizzas that were ordered but not delivered due to the order being cancelled.

```sql
SELECT
  co.customer_id,
  pz.pizza_name,
  COUNT(*) AS pizzas_ordered
FROM clean_customer_orders AS co
INNER JOIN pizza_runner.pizza_names AS pz
  ON co.pizza_id = pz.pizza_id
GROUP BY co.customer_id, pz.pizza_name
ORDER BY co.customer_id, pz.pizza_name;
```
|customer_id|pizza_name|pizzas_ordered|
|-----------|----------|--------------|
|101        |Meatlovers|2             |
|101        |Vegetarian|1             |
|102        |Meatlovers|2             |
|102        |Vegetarian|1             |
|103        |Meatlovers|3             |
|103        |Vegetarian|1             |
|104        |Meatlovers|3             |
|105        |Vegetarian|1             |


## What was the maximum number of pizzas delivered in a single order?

We count the pizzas for each successful order within a CTE, then use a subquery in the `WHERE` clause to return the order(s) with the most pizzas delivered.

```sql
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
```
|order_id|pizzas_delivered|
|--------|----------------|
|4       |3               |

## For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

We create a new `with_changes` column that returns _No_ when there are no extras and no exclusions, and _Yes_ when there is at least 1 extra or exclusion.

```sql
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
```
|customer_id|with_changes|pizzas_delivered|
|-----------|------------|----------------|
|101        |No          |2               |
|102        |No          |3               |
|103        |Yes         |3               |
|104        |Yes         |2               |
|104        |No          |1               |
|105        |Yes         |1               |

## How many pizzas were delivered that had both exclusions and extras?

The approach is similar to the previous question, but instead `with_both_changes` checks whether a pizza had both extras and exclusions (i.e. both are not blank)

```sql
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
```
|with_both_changes|pizzas_delivered|
|-----------------|----------------|
|Yes              |1               |
|No               |11              |

## What was the total volume of pizzas ordered for each hour of the day?

The table (0-23 hours) excludes hours with no orders. At first glance, it appears pizzas are being ordered for lunch, dinner and late-night suppers.

```sql
SELECT
  DATE_PART('hour', order_time) AS hour_of_order,
  COUNT(pizza_id) AS pizzas_ordered
FROM clean_customer_orders
GROUP BY DATE_PART('hour', order_time)
ORDER BY hour_of_order;
```
|hour_of_order|pizzas_ordered|
|-------------|--------------|
|11           |1             |
|13           |3             |
|18           |3             |
|19           |1             |
|21           |3             |
|23           |3             |

## What was the volume of orders for each day of the week?

Orders were received from Wednesday (3) to Saturday (6). _Note: `dow` labels Sundays as 0._

```sql
SELECT
  DATE_PART('dow', order_time) AS day_of_week,
  COUNT(pizza_id) AS pizzas_ordered
FROM clean_customer_orders
GROUP BY DATE_PART('dow', order_time)
ORDER BY day_of_week;
```
|day_of_week|pizzas_ordered|
|-----------|--------------|
|3          |5             |
|4          |3             |
|5          |1             |
|6          |5             |

# B. Runner and Customer Experience

## How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

Using `2021-01-01` (a Friday) as the first day of the week, we use a _modulo_ operation to find the number of days that has passed since the start of a 1 week period, then subtract by this number to get first 1st day of that 1 week period.

```sql
WITH runner_signups AS (
  SELECT
    runner_id,
    registration_date,
    -- modulo by 7 gives numbers of days passed since the start of week
    -- subtract by this number to get the first day of the week
    registration_date - ((registration_date - '2021-01-01') % 7)  AS start_of_week
  FROM pizza_runner.runners
)

SELECT
  start_of_week,
  COUNT(runner_id) AS signups
FROM runner_signups
GROUP BY start_of_week
ORDER BY start_of_week;
```
|start_of_week           |signups|
|------------------------|-------|
|2021-01-01T00:00:00.000Z|2      |
|2021-01-08T00:00:00.000Z|1      |
|2021-01-15T00:00:00.000Z|1      |

## What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

The time for the runner to arrive at Pizza Runner HQ is derived from `pickup_time - order_time` i.e. the time elapsed between `order_time` when the order was placed and `pickup_time` when the runner arrived at HQ.

`time_to_pickup` is of type `interval`. `date_part()` is used to extract the minutes from the average `time_to_pickup` for each runner.

```sql
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
```
|runner_id               |avg_arrival_minutes|
|------------------------|-------------------|
|1                       |15                 |
|2                       |23                 |
|3                       |10                 |

## Is there any relationship between the number of pizzas and how long the order takes to prepare?

Based on `pickup_time`, it seems that orders with more pizzas take more time to prepare.

```sql
-- number of pizzas per customer order
WITH order_quant AS (
  SELECT
    order_id,
    order_time,
    COUNT(pizza_id) AS pizzas_ordered
  FROM clean_customer_orders
  GROUP BY order_id, order_time
), 
-- join customer order to runner orders to match pickup times
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
  date_part('minutes', AVG(time_to_pickup)) AS avg_time_minutes
FROM quant_times
GROUP BY pizzas_ordered
ORDER BY pizzas_ordered;
```
|pizzas_ordered|avg_time_minutes|
|--------------|----------------|
|1             |12              |
|2             |18              |
|3             |29              |

## What was the average distance travelled for each runner?

```sql
SELECT
  runner_id,
  ROUND(
    AVG(distance_km), 2
    ) AS distance_km
FROM clean_runner_orders
GROUP BY runner_id
ORDER BY runner_id;
```
|runner_id|avg_distance_km|
|---------|---------------|
|1        |15.85          |
|2        |23.93          |
|3        |10.00          |


## What was the difference between the longest and shortest delivery times for all orders?

```sql
SELECT
  MAX(duration_mins) - MIN(duration_mins) AS difference_mins
FROM clean_runner_orders;
```
|difference_mins|
|---------------|
|30             |

## What was the average speed for each runner for each delivery and do you notice any trend for these values?

```sql
-- Count number of pizzas in each order
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
  ROUND(60 * ro.distance_km / ro.duration_mins, 2) AS avg_speed 
FROM clean_runner_orders AS ro
INNER JOIN order_quant AS co
  ON ro.order_id = co.order_id
WHERE pickup_time IS NOT NULL
ORDER BY avg_speed DESC
```
|order_id|runner_id|pizzas_ordered|distance_km|duration_mins|avg_speed|
|--------|---------|--------------|-----------|-------------|---------|
|8       |2        |1             |23.4       |15           |93.60    |
|7       |2        |1             |25         |25           |60.00    |
|10      |1        |2             |10         |10           |60.00    |
|2       |1        |1             |20         |27           |44.44    |
|3       |1        |2             |13.4       |20           |40.20    |
|5       |3        |1             |10         |15           |40.00    |
|1       |1        |1             |20         |32           |37.50    |
|4       |2        |3             |23.4       |40           |35.10    |

Orders shown in decreasing order of average speed.

While the fastest order only carried 1 pizza and the slowest order carried 3 pizzas, there is no clear trend that more pizzas slow down the delivery speed of an order.

## What is the successful delivery percentage for each runner?

```sql
SELECT
  runner_id,
  COUNT(pickup_time) as delivered,
  COUNT(order_id) AS total,
  ROUND(100 * COUNT(pickup_time) / COUNT(order_id)) AS delivery_pct
FROM clean_runner_orders
GROUP BY runner_id
ORDER BY runner_id;
```
|runner_id|delivered|total|delivery_pct|
|---------|---------|-----|------------|
|1        |4        |4    |100         |
|2        |3        |4    |75          |
|3        |1        |2    |50          |




