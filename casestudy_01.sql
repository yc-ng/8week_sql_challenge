/* --------------------
   Case Study Questions
   --------------------*/

/* tables: sales, members, menu*/

-- 1. What is the total amount each customer spent at the restaurant?
-- customer A spent $76, B spent $74 and C spent $36.

SELECT
	sales.customer_id,
    SUM(price) AS total_spending
FROM sales
LEFT JOIN menu
	ON sales.product_id = menu.product_id
GROUP BY sales.customer_id
ORDER BY sales.customer_id;

-- 2. How many days has each customer visited the restaurant?
-- A visited on 4 days, B visited on 6 days, C visited on 2 days

SELECT
	customer_id,
    COUNT (DISTINCT order_date) AS days_visited
FROM sales
GROUP BY customer_id
ORDER BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
-- A purchased sushi & curry, B purchased curry, C purchased ramen.

-- this seems overkill
WITH ordered_sales AS (
  SELECT
      customer_id,
      order_date,
      product_id,
      RANK() OVER(PARTITION BY customer_id ORDER BY order_date) AS purchase_order
  FROM sales
)

SELECT
	os.customer_id,
    menu.product_name
FROM ordered_sales os
INNER JOIN menu
	ON os.product_id = menu.product_id
WHERE purchase_order = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
-- Ramen was the most purchased item, purchased 8 times by all customers.

SELECT
	menu.product_name,
    COUNT(*) AS purchases
FROM sales
INNER JOIN menu
ON sales.product_id = menu.product_id
GROUP BY menu.product_name
ORDER BY purchases DESC;

-- 5. Which item was the most popular for each customer?
-- Ramen was most popular for A, all 3 items were equally popular for B, ramen was most popular for C.

SELECT
	sales.customer_id,
	menu.product_name,
    COUNT(*) AS purchases
FROM sales
INNER JOIN menu
ON sales.product_id = menu.product_id
GROUP BY sales.customer_id, menu.product_name
ORDER BY sales.customer_id, purchases DESC;

-- 6. Which item was purchased first by the customer after they became a member?
-- A purchased curry, B purchased sushi.

WITH members_sales AS (
  SELECT
      sales.customer_id,
      sales.order_date,
      sales.product_id,
      RANK() OVER(PARTITION BY sales.customer_id ORDER BY sales.order_date) AS purchase_order
  FROM sales
  INNER JOIN members
    ON sales.customer_id = members.customer_id
  WHERE sales.order_date >= members.join_date
)

SELECT
	ms.customer_id,
    menu.product_name
FROM members_sales ms
INNER JOIN menu
	ON ms.product_id = menu.product_id
WHERE purchase_order = 1;


-- 7. Which item was purchased just before the customer became a member?
-- A purchased sushi & curry, B purchased sushi.

WITH before_member_sales AS (
  SELECT
      sales.customer_id,
      sales.order_date,
      sales.product_id,
      RANK() OVER(PARTITION BY sales.customer_id ORDER BY sales.order_date DESC) AS purchase_order
  FROM sales
  LEFT JOIN members
    ON sales.customer_id = members.customer_id
  WHERE sales.order_date < members.join_date
)

SELECT
	bms.customer_id,
    menu.product_name
FROM before_member_sales AS bms
INNER JOIN menu
	ON bms.product_id = menu.product_id
WHERE purchase_order = 1;

-- 8. What is the total items and amount spent for each member before they became a member?
-- A spent $25 on 2 items, B spent $40 on 3 items

WITH before_member_sales AS (
  SELECT
      sales.customer_id,
      sales.order_date,
      sales.product_id,
      RANK() OVER(PARTITION BY sales.customer_id ORDER BY sales.order_date DESC) AS purchase_order
  FROM sales
  LEFT JOIN members
    ON sales.customer_id = members.customer_id
  WHERE sales.order_date < members.join_date
)

SELECT
    bms.customer_id,
    COUNT(bms.product_id) AS orders,
    SUM(menu.price) AS total_spending
FROM before_member_sales AS bms
INNER JOIN menu
	ON bms.product_id = menu.product_id
GROUP BY bms.customer_id
ORDER BY bms.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH order_points AS (
    SELECT
        *,
        CASE WHEN menu.product_name = 'sushi' THEN 2*menu.price
        ELSE menu.price END AS points
    FROM sales
    LEFT JOIN menu
        ON sales.product_id = menu.product_id
)

SELECT
    customer_id,
    SUM(points) as total_points
FROM order_points
GROUP BY customer_id
ORDER BY customer_id;


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH member_order_points AS (
    SELECT
        sales.customer_id,
        sales.order_date,
        members.join_date,
        menu.product_name,
        menu.price,
        CASE WHEN sales.order_date >= members.join_date
              AND sales.order_date < members.join_date + 7 THEN 2*menu.price
             WHEN menu.product_name = 'sushi' THEN 2*menu.price
        ELSE menu.price END AS points
    FROM sales
    LEFT JOIN menu
        ON sales.product_id = menu.product_id
    INNER JOIN members
        ON sales.customer_id = members.customer_id
)

SELECT
    customer_id,
    SUM(points)
FROM member_order_points AS mop
WHERE order_date <= '2021-01-31'
GROUP BY customer_id
ORDER BY customer_id;