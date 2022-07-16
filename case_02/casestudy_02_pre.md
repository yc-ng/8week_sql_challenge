# Case Study 2: [Pizza Runner](https://8weeksqlchallenge.com/case-study-2/)

## ER Diagram 

![ER diagram for case study 2](er_diagram_02.PNG)

*Diagram adapted from [case study webpage](https://8weeksqlchallenge.com/case-study-2/)*

Note: Pizza toppings are denoted by `topping_id` and multiple toppings for a pizza (recipe, extras, exclusions) are separated by commas. For example:

|order_id|customer_id|pizza_id|*exclusions*|*extras*|order_time|
|--------|-----------|--------|------------|--------|----------|
|10|104|1|*2, 6*|*1, 4*|2020-01-11 18:34:49.000|

## Data Issues 
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

Preview of `clean_customer_orders`:

|order_id|customer_id|pizza_id|exclusions|extras|order_time|
|--------|-----------|--------|----------|------|----------|
|1|101|1| | |2020-01-01 18:05:02.000|
|2|101|1| | |2020-01-01 19:00:52.000|
|3|102|1| | |2020-01-02 23:51:23.000|
|3|102|2| | |2020-01-02 23:51:23.000|
|4|103|1|4| |2020-01-04 13:23:46.000|

The column data types are:

|column_name|data_type|
|-----------|---------|
|order_id|integer|
|customer_id|integer|
|pizza_id|integer|
|exclusions|character varying|
|extras|character varying|
|order_time|timestamp without time zone|

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
Preview of `clean_runner_orders`:
|order_id|runner_id|pickup_time|distance_km|duration_mins|cancellation|
|--------|---------|-----------|-----------|-------------|------------|
|1|1|2020-01-01 18:15:34.000|20|32||
|2|1|2020-01-01 19:10:54.000|20|27||
|3|1|2020-01-03 00:12:37.000|13.4|20||
|4|2|2020-01-04 13:53:03.000|23.4|40||
|5|3|2020-01-08 21:10:57.000|10|15||

The column data types are as follows:
|column_name|data_type|
|-----------|---------|
|order_id   |integer  |
|runner_id  |integer  |
|pickup_time|timestamp without time zone|
|distance_km|numeric  |
|duration_mins|numeric  |
|cancellation|character varying|
