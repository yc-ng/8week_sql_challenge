/* --------------------
   Case Study Questions
   --------------------*/

/* tables: sales, members, menu*/

-- 1. What is the total amount each customer spent at the restaurant?

SELECT 
    sales.customer_id AS customer,
    SUM(price) AS spending_total
FROM sales
INNER JOIN menu 
    ON sales.product_id = menu.product_id
GROUP BY sales.customer_id
ORDER BY sales.customer_id;

-- 2. How many days has each customer visited the restaurant?

SELECT 
    customer_id AS customer,
    COUNT(DISTINCT order_date) AS days_visited
FROM sales
GROUP BY customer_id
ORDER BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?

WITH ordered_sales AS (
    SELECT 
        customer_id,
        order_date,
        product_id,
        RANK() OVER(
            PARTITION BY customer_id 
            ORDER BY order_date) AS purchase_order
    FROM sales
)
SELECT DISTINCT 
    os.customer_id AS customer,
    menu.product_name AS first_purchase
FROM ordered_sales AS os
INNER JOIN menu
	ON os.product_id = menu.product_id
WHERE purchase_order = 1
ORDER BY os.customer_id;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT 
    menu.product_name AS product,
    COUNT(sales.product_id) AS purchases
FROM sales
INNER JOIN menu
    ON sales.product_id = menu.product_id
GROUP BY menu.product_name
ORDER BY purchases DESC
LIMIT 1;

-- 5. Which item was the most popular for each customer?

-- count purchases of items for each customer
-- rank number of purchases in descending order
WITH item_popularity AS (
    SELECT 
        sales.customer_id,
        menu.product_name,
        COUNT(sales.product_id) AS purchases,
        RANK() OVER(
            PARTITION BY customer_id
            ORDER BY COUNT(sales.product_id) DESC
        ) AS popular_rank
    FROM sales
    INNER JOIN menu
        ON sales.product_id = menu.product_id
    GROUP BY 
        sales.customer_id, 
        menu.product_name
)
SELECT 
    customer_id AS customer,
    product_name AS most_popular_item,
    purchases
FROM item_popularity
WHERE popular_rank = 1
ORDER BY 
    customer, 
    most_popular_item;

-- 6. Which item was purchased first by the customer after they became a member?

-- filter sales for members 
-- rank order of purchase by date
WITH members_sales AS (
    SELECT 
        sales.customer_id,
        sales.order_date,
        sales.product_id,
        RANK() OVER(
            PARTITION BY sales.customer_id 
            ORDER BY sales.order_date) AS purchase_order
    FROM sales
    INNER JOIN members
        ON sales.customer_id = members.customer_id
    WHERE sales.order_date >= members.join_date
)
SELECT 
    ms.customer_id,
    menu.product_name
FROM members_sales AS ms
INNER JOIN menu
	ON ms.product_id = menu.product_id
WHERE purchase_order = 1;


-- 7. Which item was purchased just before the customer became a member?

-- filter sales for customers before they became members
-- rank order of purchase by date in reverse
WITH before_member_sales AS (
    SELECT 
        sales.customer_id,
        sales.order_date,
        sales.product_id,
        RANK() OVER(
            PARTITION BY sales.customer_id 
            ORDER BY sales.order_date DESC) AS rev_purchase_order
    FROM sales
    INNER JOIN members
        ON sales.customer_id = members.customer_id
    WHERE sales.order_date < members.join_date
)
-- retrieve the last item(s) ordered before customer becomes a member
SELECT 
    bms.customer_id AS customer,
    menu.product_name AS last_purchase_before_member
FROM before_member_sales AS bms
INNER JOIN menu
    ON bms.product_id = menu.product_id
WHERE rev_purchase_order = 1
ORDER BY 
    customer, 
    last_purchase_before_member;

-- 8. What is the total items and amount spent for each member before they became a member?

-- filter sales for customers before become members
WITH before_member_sales AS (
    SELECT 
        sales.customer_id,
        sales.order_date,
        sales.product_id,
    FROM sales
    INNER JOIN members
        ON sales.customer_id = members.customer_id
    WHERE sales.order_date < members.join_date
)
SELECT 
    bms.customer_id AS customer,
    COUNT(bms.product_id) AS orders_num,
    SUM(menu.price) AS spending_total
FROM before_member_sales AS bms
INNER JOIN menu
    ON bms.product_id = menu.product_id
GROUP BY bms.customer_id
ORDER BY bms.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

-- compute points per sale based on item price
-- 2x points for sushi
WITH order_points AS (
    SELECT 
        sales.customer_id,
        CASE 
            WHEN menu.product_name = 'sushi' THEN 20 * menu.price
            ELSE 10 * menu.price 
        END AS points
    FROM sales
    INNER JOIN menu
        ON sales.product_id = menu.product_id
)
-- tally points for each customer
SELECT 
    customer_id AS customer,
    SUM(points) AS points_total
FROM order_points
GROUP BY customer_id
ORDER BY customer_id;


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

-- compute points per sale based on item price
-- 2x points for all items in the 1st week of membership
-- 2x points for sushi (does not stack with 1st week of membership)
WITH member_order_points AS (
    SELECT 
        sales.customer_id,
        sales.order_date,
        members.join_date,
        menu.product_name,
        menu.price,
        CASE 
            WHEN sales.order_date 
                BETWEEN members.join_date
                AND members.join_date + 6 THEN 20 * menu.price
            WHEN menu.product_name = 'sushi' THEN 20 * menu.price
            ELSE 10 * menu.price 
        END AS points
    FROM sales
    INNER JOIN menu
        ON sales.product_id = menu.product_id
    INNER JOIN members
        ON sales.customer_id = members.customer_id
)
-- tally points for each member
SELECT 
    customer_id AS customer,
    SUM(points) AS points_total
FROM member_order_points
WHERE order_date <= '2021-01-31'
GROUP BY customer_id
ORDER BY customer_id;


-- Bonus 1: join all the things

SELECT
    sales.customer_id,
    sales.order_date,
    menu.product_name,
    menu.price,
    CASE 
        WHEN members.customer_id IS NOT NULL
        AND sales.order_date >= members.join_date THEN 'Y'
        ELSE 'N' 
    END AS member
FROM sales
INNER JOIN menu
    ON sales.product_id = menu.product_id
LEFT JOIN members
    ON sales.customer_id = members.customer_id
ORDER BY 
    sales.customer_id,
    sales.order_date,
    menu.product_name;

-- Bonus 2: rank all the things

WITH joined_data AS (
    SELECT
        sales.customer_id,
        sales.order_date,
        menu.product_name,
        menu.price,
        CASE 
            WHEN members.customer_id IS NOT NULL
            AND sales.order_date >= members.join_date THEN 'Y'
        ELSE 'N' END AS member
    FROM sales
    INNER JOIN menu
        ON sales.product_id = menu.product_id
    LEFT JOIN members
        ON sales.customer_id = members.customer_id
)
SELECT
    customer_id,
    order_date,
    product_name,
    price,
    member,
    CASE 
        WHEN member = 'Y' THEN
            DENSE_RANK() OVER(
                PARTITION BY customer_id, member 
                ORDER BY order_date)
        ELSE null 
    END AS ranking
FROM joined_data
ORDER BY 
    customer_id, 
    order_date;