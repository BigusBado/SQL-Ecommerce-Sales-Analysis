/* ============================================================================
   PROJECT: SQL E-COMMERCE SALES & CUSTOMER BEHAVIOR ANALYSIS
   DESCRIPTION: Analyzing revenue trends, product performance, and customer 
                segmentation for an e-commerce platform using SQL.
   ============================================================================ */

/* ----------------------------------------------------------------------------
   DATABASE SCHEMA
   ----------------------------------------------------------------------------
   - customers: Customer demographics and locations.
   - products: Product categories and identifiers.
   - orders: Order timestamps and fulfillment status.
   - order_items: Granular item pricing and freight values.
   ---------------------------------------------------------------------------- */


/* ============================================================================
   PART 1: REVENUE ANALYSIS
   ============================================================================ */

-- 1. TOTAL REVENUE GENERATION
-- Business Question: What is the total revenue generated across all processed orders?

select sum(price) + sum(freight_value) as total_revenue
from order_items;

/* RESULT: 
1252.38

INSIGHT: 
The total revenue establishes our baseline for company performance. Factoring in 
freight value alongside the product price ensures we are looking at the gross 
cash flow moving through the platform.
*/


-- 2. MONTHLY REVENUE TRENDS
-- Business Question: How is revenue distributed across different months?

select sum(oi.price)  +sum(oi.freight_value) as month_revenue
from order_items as oi left join orders as o on o.order_id = oi.order_id
group by strftime('%Y-%m' , o.order_purchase_timestamp);

/* RESULT: 
2024-01: 535.49
2024-02: 716.89

INSIGHT: 
Revenue grew by over 30% from January to February. This positive month-over-month 
trend indicates expanding market reach or highly successful seasonal marketing campaigns.
*/


-- 3. TOP PERFORMING PRODUCTS
-- Business Question: Which 10 specific products generate the most revenue?

select p.product_id , p.product_category_name , sum(oi.price) + sum(oi.freight_value)as revenue from products as p
inner join order_items as oi on p.product_id = oi.product_id
group by p.product_id , p.product_category_name
order by sum(oi.price) + sum(oi.freight_value) desc
limit 10;

/* RESULT: 
PROD-001 (Electronics) leads with 629.98, followed by PROD-002 (Furniture) at 340.00.

INSIGHT: 
A single product accounts for roughly 50% of the total revenue. The business is 
heavily reliant on this flagship item, suggesting an opportunity to cross-sell 
other products to buyers of this specific electronic device.
*/


-- 4. TOP PERFORMING CATEGORIES
-- Business Question: Which 5 product categories drive the highest sales?

select p.product_category_name , sum(oi.price) + sum(oi.freight_value)as revenue from products as p
inner join order_items as oi on p.product_id = oi.product_id
group by p.product_category_name
order by revenue desc
limit 5;

/* RESULT: 
1. Electronics (761.98)
2. Furniture (340.00)
3. Sports (99.90)
4. Health & Beauty (50.50)

INSIGHT: 
High-ticket categories like Electronics and Furniture dominate the revenue stream. 
Marketing budgets should be disproportionately allocated to these top categories 
to maximize Return on Ad Spend (ROAS).
*/


/* ============================================================================
   PART 2: CUSTOMER ANALYSIS
   ============================================================================ */

-- 5. HIGH-VALUE CUSTOMERS
-- Business Question: Who are the top 10 customers based on lifetime spending?

select c.customer_id,  sum(oi.price) + sum(oi.freight_value) as total_cust_spendings , c.customer_city , c.customer_state 
from customers c inner join orders as o on c.customer_id = o.customer_id
inner join order_items as oi on o.order_id = oi.order_id
group by c.customer_id, c.customer_city , c.customer_state
order by total_cust_spendings DESC
limit 10;

/* RESULT: 
CUST-001 from Sao Paulo leads with 629.98 spent.

INSIGHT: 
Our highest-spending users are concentrated in major hubs like Sao Paulo. We 
should consider launching localized loyalty programs or faster shipping options 
in the SP region to reward our best buyers.
*/


-- 6. AVERAGE ORDER VALUE (AOV)
-- Business Question: What is the average value generated per order item?

select round(avg(price+freight_value) , 2) as AOV
from order_items;

/* RESULT: 
178.91

INSIGHT: 
By measuring the average revenue per item, we can set strategic thresholds for 
promotions (e.g., "Free shipping on orders over 200") to incentivize customers 
to spend just above our current average.
*/


-- 7. CUSTOMER RETENTION (ONE-TIME VS. REPEAT)
-- Business Question: What is the ratio of one-time buyers to repeat customers?

with tab1 as (
  select c.customer_id , count(o.customer_id) as counti
  from customers as c inner join orders as o
  on c.customer_id = o.customer_id
  group by c.customer_id)
  , 
tab2 as (
	select customer_id
  		  ,case when counti = 1 then customer_id end as one_time_customers 
  		  ,Case when counti > 1 then customer_id end as recuring_customers
  		  ,row_number() over(PARTITION BY CASE WHEN counti = 1 THEN 'OneTime' ELSE 'Recurring' END 
          
  ORDER BY customer_id) as row_num
  	from tab1)
, tab3 as(
SELECT row_num , MAX(one_time_customers) AS one_time_customers 
,MAX(recuring_customers) as recuring_customers 
FROM tab2 
GROUP BY row_num
ORDER BY row_num
)
select ifnull(one_time_customers , '-') , count(one_time_customers) over() as number_of_one_time_customers , ifnull(recuring_customers , '-' ), count(recuring_customers) over() as number_of_recuring_customers
from tab3
group by one_time_customers , recuring_customers
order  by row_num;

/* RESULT: 
3 One-time customers, 1 Repeat customer.

INSIGHT: 
The majority of our user base consists of one-time purchasers. The business 
needs to implement stronger post-purchase lifecycle email campaigns to convert 
these one-off buyers into loyal, repeat customers.
*/


/* ============================================================================
   PART 3: ADVANCED ANALYSIS
   ============================================================================ */

-- 8. REVENUE CONCENTRATION (PARETO PRINCIPLE)
-- Business Question: What percentage of total revenue is driven by the top 20% of customers?

WITH all_cust_with_spendings AS (
    SELECT 
        c.customer_id,  
        (SUM(oi.price) + SUM(oi.freight_value)) AS total_cust_spendings
    FROM customers c 
    INNER JOIN orders o ON c.customer_id = o.customer_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id
),
value_per_20_perc AS (
    SELECT 
        total_cust_spendings,
        
NTILE(5) OVER(ORDER BY total_cust_spendings DESC) AS perc_bucket
    FROM all_cust_with_spendings
),
the20 AS (
    SELECT 
        SUM(CASE WHEN perc_bucket = 1 THEN total_cust_spendings ELSE 0 END) AS the_20
    FROM value_per_20_perc
)
SELECT 
    ROUND( 100.0 * the_20 / (SELECT SUM(price + freight_value) FROM order_items) , 2) AS percentage_from_top_20
FROM the20;

/* RESULT: 
50.3%

INSIGHT: 
The top 20% of our customers generate over half (50.3%) of total company revenue. 
This high concentration highlights the critical importance of VIP retention 
strategies; losing even a few top-tier customers would severely impact the bottom line.
*/
