# Case Study 3 - [Foodie-Fi](https://8weeksqlchallenge.com/case-study-3/)

## ER Diagram 

![ER diagram for case study 3](er_diagram_03.PNG)

*Diagram adapted from [case study webpage](https://8weeksqlchallenge.com/case-study-3/)*

## Part A - Customer Journey

Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.

<details>
<summary>Method and sample query</summary>

- For each customer, obtain the plan name and start dates by joining the `subscriptions` and `plans` table.

``` sql
SELECT
    s.customer_id,
    p.plan_name,
    s.start_date
FROM subscriptions AS s
INNER JOIN "plans" AS p
    ON s.plan_id = p.plan_id
WHERE s.customer_id = 1
ORDER BY s.start_date;
```
</details>

---
Note: The 7-day free trial offers features from the Pro plan, and automatically continues to a monthly Pro subscription unless customers downgrade to Basic, upgrades to an annual Pro plan, or cancels.
- Basic plan customers have limited access and can only stream videos.
- Pro plan customers have no watch time limits and can download videos for offline viewing.

Customer 1 signed up for the 7-day free trial and opted for a Basic subscription after the trial ended.

|customer_id|plan_name|start_date|
|-----------|---------|----------|
|1|trial|2020-08-01|
|1|basic monthly|2020-08-08|

Customer 2 - signed up for the free trial and upgraded to a annual Pro subscription afterwards.

|customer_id|plan_name|start_date|
|-----------|---------|----------|
|2|trial|2020-09-20|
|2|pro annual|2020-09-27|

Customer 11 - signed up for the free trial but declined to subscribe after the trial ended.

|customer_id|plan_name|start_date|
|-----------|---------|----------|
|11|trial|2020-11-19|
|11|churn|2020-11-26|

Customer 13 - signed up for the free trial and initially opted for a Basic subscription. Upgraded to a monthly Pro plan 3 months later.

|customer_id|plan_name|start_date|
|-----------|---------|----------|
|13|trial|2020-12-15|
|13|basic monthly|2020-12-22|
|13|pro monthly|2021-03-29|

Customer 15 - signed up for the free trial and continued with a monthly Pro subscription. Cancelled the service after about one month.

|customer_id|plan_name|start_date|
|-----------|---------|----------|
|15|trial|2020-03-17|
|15|pro monthly|2020-03-24|
|15|churn|2020-04-29|

Customer 16 - signed up for the free trial and initially opted for a Basic subscription. Upgraded to an annual Pro plan 4 months later.

|customer_id|plan_name|start_date|
|-----------|---------|----------|
|16|trial|2020-05-31|
|16|basic monthly|2020-06-07|
|16|pro annual|2020-10-21|

Customer 18 - signed up for the free trial and continued with a monthly Pro subscription afterwards.

|customer_id|plan_name|start_date|
|-----------|---------|----------|
|18|trial|2020-07-06|
|18|pro monthly|2020-07-13|

Customer 19 - signed up for the free trial and continued with a monthly Pro subscription. Upgraded to an annual Pro plan after 2 months.

|customer_id|plan_name|start_date|
|-----------|---------|----------|
|19|trial|2020-06-22|
|19|pro monthly|2020-06-29|
|19|pro annual|2020-08-29|


