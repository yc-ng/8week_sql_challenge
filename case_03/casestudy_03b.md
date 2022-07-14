# Case Study 3 - [Foodie-Fi](https://8weeksqlchallenge.com/case-study-3/)

## ER Diagram 

![ER diagram for case study 3](er_diagram_03.PNG)

*Diagram adapted from [case study webpage](https://8weeksqlchallenge.com/case-study-3/)*

## Part B - Data Analysis


### 1. How many customers has Foodie-Fi ever had?

- As `customer_id` is not unique in the `subscriptions` table, `COUNT` and `DISTINCT` is used to tally the number of unique customers for Foodie-Fi.

``` sql
SELECT 
    COUNT(DISTINCT customer_id) AS num_customers
FROM subscriptions;
```
|num_customers|
|-------------|
|1000|

---
### 2. What is the monthly distribution of trial plan `start_date` values for our dataset? 
*use the start of the month as the group by value*

- `date_trunc()` converts start_date values to the start of the month
- The trial plan has a `plan_id` of `0`, which is used to filter the results

``` sql
SELECT 
    date_trunc('month', start_date)::date AS by_month,
    COUNT(customer_id) AS trial_plans_count
FROM subscriptions
WHERE plan_id = 0 -- trial plan
GROUP BY by_month
ORDER BY by_month;
```

|by_month|trial_plans_count|
|--------|-----------------|
|2020-01-01|88|
|2020-02-01|68|
|2020-03-01|94|
|2020-04-01|81|
|2020-05-01|88|
|2020-06-01|79|
|2020-07-01|89|
|2020-08-01|88|
|2020-09-01|87|
|2020-10-01|79|
|2020-11-01|75|
|2020-12-01|84|

---
### 3. What plan `start_date` values occur after the year 2020 for our dataset? Show the breakdown by count of events for each `plan_name`.

- Join to `plans` to retrieve `plan_name`
- Filter for records with `start_date` after 2020-12-31

```sql
SELECT 
    p.plan_name,
    COUNT(customer_id) AS events_count
FROM subscriptions AS s
INNER JOIN "plans" AS p
    ON s.plan_id = p.plan_id
WHERE start_date > '2020-12-31'
GROUP BY p.plan_name
ORDER BY events_count DESC;
```
|plan_name|events_count|
|---------|------------|
|churn|71|
|pro annual|63|
|pro monthly|60|
|basic monthly|8|

---
### 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

- A subquery is used to obtain the total number of customers, to calculate the percentage of customers who have churned
- Either the quotient or divisor needs to be converted to `numeric` type for division to return a float value. In this case, we convert the first `COUNT` value to numeric.

```sql
SELECT 
    COUNT(s.customer_id) AS churn_count,
    ROUND(100 * COUNT(s.customer_id)::NUMERIC / 
            -- total number of customers in the data
            (SELECT COUNT(DISTINCT customer_id) 
             FROM subscriptions), 
          1) AS churn_pct
FROM subscriptions AS s
INNER JOIN "plans" AS p
    ON s.plan_id = p.plan_id
WHERE p.plan_name = 'churn';
```
|churn_count|churn_pct|
|-----------|---------|
|307|30.7|

---
### 5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?

- Join the `subscriptions` table to itself on `customer_id`, and on `plan_id` with the trial plan `0` in the first table, and churn `4` in the second table
- Filter the `start_date` such that the churn occurs 7 days after the start of the free trial (i.e. after the trial ended)
- Use a subquery to obtain the total number of customers
- Count the number and percentage of customers who churned straight after 

```sql
SELECT 
    COUNT(s1.customer_id) AS immediate_churn_count,
    ROUND(100 * COUNT(s1.customer_id)::NUMERIC / 
            (SELECT COUNT(DISTINCT customer_id) 
             FROM subscriptions)) AS immediate_churn_pct
FROM subscriptions AS s1
INNER JOIN subscriptions AS s2
    ON s1.customer_id = s2.customer_id
    AND s1.plan_id = 0 -- free trial
    AND s2.plan_id = 4 -- churn
WHERE s2.start_date = s1.start_date + 7;
```
|immediate_churn_count|immediate_churn_pct|
|---------------------|-------------------|
|92|9|

---
### 6. What is the number and percentage of customer plans after their initial free trial?

- Join `subscriptions` to itself again, but exclude churn from the second table
- Filter for plans that started 7 days after the start of the free trial (i.e. after the trial ended)
- Calculate number and percentage of customers, grouped by the type of plan

```sql
SELECT 
    p.plan_name,
    COUNT(s1.customer_id) AS plan_count,
    ROUND(100 * COUNT(s1.customer_id)::NUMERIC / 
            (SELECT COUNT(DISTINCT customer_id) 
             FROM subscriptions)) AS plan_pct
FROM subscriptions AS s1
INNER JOIN subscriptions AS s2
    ON s1.customer_id = s2.customer_id
    AND s1.plan_id = 0 -- free trial
    AND s2.plan_id <> 4 -- did not churn
INNER JOIN "plans" AS p
    ON s2.plan_id = p.plan_id
WHERE s2.start_date = s1.start_date + 7
GROUP BY p.plan_name
ORDER BY plan_nums DESC;
```
|plan_name|plan_count|plan_pct|
|---------|----------|--------|
|basic monthly|546|55|
|pro monthly|325|33|
|pro annual|37|4|

---
### 7. What is the customer count and percentage breakdown of all 5 `plan_name` values at 2020-12-31?

- Group by `customer_id`, get the plan with the latest `start_date` for each customer as of 2020-12-31
- Join subscriptions to this table on `customer_id` and `start_date`
- Join to plans to retrieve `plan_name`
- Group by `plan_name` and obtain the count and percentage of customers

```sql
-- obtain the date of the latest plan for each customer as of 2020-12-31
WITH latest_start_date AS (
    SELECT
        customer_id,
        MAX(start_date) AS start_date
    FROM subscriptions
    WHERE start_date <= '2020-12-31'
    GROUP BY customer_id
)
-- retrieve and group by plan names to obtain count and percentage of customers
SELECT
    p.plan_name,
    COUNT(s.customer_id) AS plan_count,
    ROUND(100 * COUNT(s.customer_id)::NUMERIC / 
            (SELECT COUNT(DISTINCT customer_id) 
             FROM subscriptions)) AS plan_pct
FROM subscriptions AS s
INNER JOIN latest_start_date AS lsd
    ON s.customer_id = lsd.customer_id
    AND s.start_date = lsd.start_date
INNER JOIN "plans" AS p
    ON s.plan_id = p.plan_id
GROUP BY p.plan_name
ORDER BY plan_count DESC;
```
|plan_name|plan_count|plan_pct|
|---------|----------|--------|
|pro monthly|326|33|
|churn|236|24|
|basic monthly|224|22|
|pro annual|195|20|
|trial|19|2|

---
### 8. How many customers have upgraded to an annual plan in 2020?

- Includes both customers who upgraded to an annual plan after the free trial, and customers who first subscribed to a monthly plan before upgrading to an annual plan.
- Filter for start_date in 2020 and annual Pro plan (`plan_id` is `3`)

```sql
SELECT 
    COUNT(DISTINCT customer_id) 
FROM subscriptions
WHERE start_date BETWEEN '2020-01-01' AND '2020-12-31'
AND plan_id = 3;
```
|annual_plan_count|
|-----------------|
|195|

---
### 9. How many days on average does it take for a customer to upgrade to an annual plan from the day they join Foodie-Fi?

- We define that a customer joins Foodie-Fi when they purchase a subscription plan **after** the 7-day free trial
- So the period it takes to upgrade to an annual plan is between 7 days after the start of the free trial, and the start of the annual plan.
- Join the subscriptions table to itself on `customer_id`, and on `plan_id` with the trial plan `0` in the first table, and the annual plan `3` in the second table
- Calculate the number of days between the end of the free trial and the start of the annual plan for each customer
- Compute the average value of the number of days for all annual plan customers

```sql
WITH annual_upgrade_intervals AS (
    SELECT 
        s1.customer_id,
        -- number of days starting from end of free trial
        s2.start_date - s1.start_date - 7 AS days_to_upgrade
    FROM subscriptions AS s1
    INNER JOIN subscriptions AS s2
        ON s1.customer_id = s2.customer_id
        AND s1.plan_id = 0
        AND s2.plan_id = 3
)
SELECT 
    ROUND(AVG(days_to_upgrade)) AS avg_days_to_upgrade
FROM annual_upgrade_intervals;
```
|avg_days_to_upgrade|
|-------------------|
|98|

---
### 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)

- Calculate the number of days between the end of the free trial and the start of the annual plan for each customer
- Subtract this interval by 1, then perform integer division by 30
- This generates an index of the 30 day periods: 0 for 0-30, 1 for 31-60, 2 for 61-90, ...
- Group by 30 day periods and obtain the number of customers and average time to upgrade

```sql
-- number of days for customers to upgrade to annual plan after free trial
WITH annual_upgrade_by_30d AS (
    SELECT 
        s1.customer_id,
        -- number of days starting from end of free trial
        s2.start_date - s1.start_date - 7 AS days_to_upgrade,
        -- indexed by periods of 30 days
        -- subtract by 1 to include multiples of 30 as the upper bound when dividing into periods
        (s2.start_date - s1.start_date - 7 - 1) / 30 AS period_index
    FROM subscriptions AS s1
    INNER JOIN subscriptions AS s2
        ON s1.customer_id = s2.customer_id
        AND s1.plan_id = 0
        AND s2.plan_id = 3
), 
-- denote which period each customer falls under 
-- (0-30 days, 31-60 days, ...)
annual_upgrade_groups AS (
    SELECT 
        customer_id,
        days_to_upgrade,
        period_index, -- include index for ordering
        CASE 
            WHEN period_index = 0 THEN '0-30 days'
            ELSE (period_index*30) + 1 || '-' || 
                 (period_index+1) * 30 || ' days'
        END AS period_group
    FROM annual_upgrade_by_30d
)
-- group by period
-- get number of customers and average days to upgrade
SELECT 
    period_group,
    count(*) AS customers_count,
    round(avg(days_to_upgrade)) AS avg_days_to_upgrade
FROM annual_upgrade_groups
GROUP BY 
    period_index, -- include index for ordering
    period_group
ORDER BY
    period_index;
```
|period_group|customers_count|avg_days_to_upgrade|
|------------|---------------|-------------------|
|0-30 days|55|6|
|31-60 days|28|45|
|61-90 days|34|73|
|91-120 days|29|99|
|121-150 days|45|130|
|151-180 days|36|161|
|181-210 days|21|189|
|211-240 days|3|230|
|241-270 days|4|254|
|271-300 days|1|278|
|301-330 days|1|320|
|331-360 days|1|339|

---
### 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

- Assumption: this excludes customers who 'downgraded' from the free trial (of a Pro plan) to a Basic plan.
- Join the `subscriptions` table to itself on `customer_id`, and on `plan_id` with the pro monthly plan `2` in the first table, and basic monthly plan `1` in the second table
- Filter the `start_date` such that the the pro monthly plan started **before** the basic monthly plan for each customer, and that the basic monthly plan started in 2020.

```sql
SELECT 
    COUNT(s1.customer_id) AS customer_downgrade_count
FROM subscriptions AS s1
INNER JOIN subscriptions AS s2
    ON s1.customer_id = s2.customer_id
    AND s1.plan_id = 2 -- pro monthly plan
    AND s2.plan_id = 1 -- basic monthly plan
WHERE s1.start_date < s2.start_date -- pro downgraded to basic
    AND s2.start_date BETWEEN '2020-01-01' AND '2020-12-31';
```
|customer_downgrade_count|
|------------------------|
|0|
