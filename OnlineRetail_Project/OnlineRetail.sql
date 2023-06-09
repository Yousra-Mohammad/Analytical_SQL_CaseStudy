-- Q1: 
---------1st Query -->Top 5 Selling product by revenue--------
with rank_CTE as
(
select stockcode , sum(quantity*price)as revenu 
 from tableRetail group by stockcode  order by revenu Desc )
 
select * from (select stockcode ,dense_rank() over(order by revenu ) Top5_Selling_Products   from rank_CTE )
where  TOP_SELLING_PRODUCTS <=5;

-- Description for the query 
/*
This SQL query is designed to find the top 5 selling products in our online-retial-store
and this information can be useful for the business to identify the top-performing products in terms of revenue, and it can be used to inform inventory and sales strategies, 
such as ensuring that these products are always in stock, increasing marketing efforts to promote these products, 
or bundling these products with other complementary items to increase sales.
*/

-------------------------------------------------------------------------------------------------------------------------------------------

----2nd Query  --> the top 10 customers in terms of Revenue

select CUSTOMER_ID ,TOTAL_REVENUE, ranking 
from  (SELECT CUSTOMER_ID, SUM(Quantity * price) as TOTAL_REVENUE , Dense_rank() over( order by SUM(Quantity * price) DESC) as ranking FROM tableRetail
GROUP BY CUSTOMER_ID
ORDER BY TOTAL_REVENUE DESC)
where ranking <=10

-- Description for the query 
/*
This SQL query is designed to identify the top 10 customers in terms of revenue generated by their purchases
This can be useful for the business to identify the top customers who generate the most revenue for the company.
These customers may be targeted for special promotions, loyalty programs, or other incentives to maintain their loyalty and encourage them to continue making purchases.
*/

-----------------------------------------------------------------------------------------------------------------------------------------

 -------3rd Query --> Customer LTV--------------
 
 with 
 Tenuure as (
 select distinct Customer_ID, TRUNC((LAST_PURCHASE - FIRST_PURCHASE ),0) as Tenure
 from 
(Select  Customer_ID ,
 last_value(Order_Date) over(partition by Customer_ID order by Order_Date  rows between unbounded preceding and unbounded following ) as LAST_PURCHASE,
 first_value(Order_Date) over(partition by Customer_ID order by Order_Date) as FIRST_PURCHASE 
 from (select  Customer_ID , TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI') as Order_Date from tableRetail 
          group by Customer_ID,TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI') ) ) )
 , 
 TR_CTE as   
  (
   select Customer_ID  ,sum(Price * Quantity) AS "Total Revenue" , COUNT( Distinct Invoice) AS "Total Orders" from  tableRetail 
   group by Customer_ID 
  )
  
SELECT C.Customer_ID, "Total Revenue" ,  "Total Orders", Tenure
,(CASE WHEN Tenure > 0 then ("Total Revenue" / "Total Orders") * (365 / Tenure) ELSE 0 END) AS CustomerLifetimeValue 
FROM TR_CTE  C inner join Tenuure T on T.Customer_ID = C.Customer_ID
ORDER BY CustomerLifetimeValue DESC ; 
--ORDER BY Tenure DESC;

--Query  Description 
/*
This query calculates the customer lifetime value (CLV) for each customer. 
CLV is a measure of the total value that a customer is expected to generate for the business over their entire lifetime. 
It can help the business identify their most valuable customers and focus on retaining them.
*/
-----------------------------------------------------------------------------------------------------------------------------------

 -------4th Query --> Shows the correlation between tenure and the total Revenue over the customer --------------
 
 
 with 
 Tenuure as (
 select distinct Customer_ID, TRUNC((LAST_PURCHASE - FIRST_PURCHASE ),0) as Tenure
 from 
(Select  Customer_ID ,
 last_value(Order_Date) over(partition by Customer_ID order by Order_Date  rows between unbounded preceding and unbounded following ) as LAST_PURCHASE,
 first_value(Order_Date) over(partition by Customer_ID order by Order_Date) as FIRST_PURCHASE 
 from (select  Customer_ID , TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI') as Order_Date from tableRetail 
          group by Customer_ID,TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI') ) ) )
 , 
 TR_CTE as   
  (
   select Customer_ID  ,sum(Price * Quantity) AS "Total Revenue" , COUNT( Distinct Invoice) AS "Total Orders" from  tableRetail 
   group by Customer_ID 
  )
 
 select CORR(Tenuure.Tenure , TR_CTE."Total Revenue") as Corr_coefficient
 from  Tenuure  
 INNER JOIN TR_CTE  
 ON  Tenuure.Customer_ID = TR_CTE.Customer_ID

 /*A correlation coefficient of 0.415816219737184 indicates a weak positive correlation 
between the two variables (Tenure & Total Revenue ). 
The closer the correlation coefficient is to 1, the stronger the positive correlation.
 A correlation coefficient of 0 indicates no correlation between the two variables. A negative correlation coefficient indicates 
 a negative correlation between the two variables
*/

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-----5th Query ---> test that  "Pareto principle" has been acheived or not 


with TOP20 as 
(select sum(total_Revenue) as "TR_TOP20_customers" from (select Customer_ID, 
    total_Revenue, percent_rank() over(order by total_Revenue DESC ) *100 as ranking 
    from (select Customer_ID , sum(quantity * price)  as total_Revenue   from tableRetail group by Customer_ID) ) 
    where ranking <=20 ),
 TR as (select sum(quantity * price) as "Total Revenue" from tableRetail )
 
select  Trunc(("TR_TOP20_customers" /  "Total Revenue" ),4) * 100 as "Top20%_Of_TotalRevenue"
from  TOP20 , TR ;

/*As we can see in the above output the percentage of the total revenue of 
the top 20% of customers are responsible for 73.31% of the total revenue, 
then the "Pareto principle" is nearly to being met, as it states that roughly 80% of consequences come
 from 20% of causes. In this case, it would mean that around  25-30% of customers are responsible for  80% of the Revenue. 
*/
 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Q2 : 

with D_CTE as 
(select  customer_ID ,TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI') as Order_Date  , invoice from tableRetail 
  group by customer_ID, TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI') ,invoice ),
RT_CTE as 
(select customer_ID,last_value(Order_Date) over( partition by CUSTOMER_ID order by Order_Date rows between unbounded preceding and unbounded following ) as Last_Order
,  last_value(Order_Date) over(order by Order_Date rows between unbounded preceding and unbounded following ) as Recent_Transaction 
 from D_CTE D  )
, FREQ_CTE as 
(
  select D.customer_ID, count (Distinct Order_Date)   as Frequency,  SUM(Quantity * Price) AS Monetary  from D_CTE D inner join tableRetail R
  on D.customer_ID = R.customer_ID
 Group by D.customer_ID
)

select customer_ID , Recency , Frequency , Monetary , r_Score , fm_Score
,CASE 
    WHEN r_Score = 5 AND fm_Score = 5 OR r_Score = 5 AND fm_Score = 4 OR r_Score = 4 AND fm_Score = 5 THEN 'Champions'
    WHEN r_Score = 5 AND fm_Score = 2 OR r_Score = 4 AND fm_Score = 2 OR r_Score = 3 AND fm_Score = 3 OR r_Score = 4 AND fm_Score = 3 THEN 'Potential loyalists'
    WHEN r_Score = 5 AND fm_Score = 3 OR r_Score = 4 AND fm_Score = 4 OR r_Score = 3 AND fm_Score = 5 OR r_Score = 3 AND fm_Score = 4   THEN 'Loyal Customer'
    WHEN r_Score = 5 AND fm_Score = 1 THEN 'Recent Customer'
    WHEN r_Score = 4 AND fm_Score = 1 OR r_Score = 3 AND fm_Score = 1  THEN 'Promising'
    WHEN r_Score = 3 AND fm_Score = 2 OR r_Score = 2 AND fm_Score = 3 OR r_Score = 2 AND fm_Score = 2 THEN 'Customer Needing Attention'
    WHEN r_Score = 2 AND fm_Score = 5 OR r_Score = 2 AND fm_Score = 4 OR r_Score = 1 AND fm_Score = 3 THEN 'At Risk '
    WHEN r_Score = 1 AND fm_Score = 5 OR r_Score = 1 AND fm_Score = 4 THEN 'Can''t Lose Them'
    WHEN r_Score = 1 AND fm_Score = 2  THEN 'Hibernating '
    WHEN r_Score = 1 AND fm_Score = 1 THEN 'Lost  '
END AS Customer_Segment

from 
(select  customer_ID , Recency , Frequency , Monetary , ntile(5) OVER (ORDER BY Recency DESC) as r_Score 
, trunc(((ntile(5) OVER (ORDER BY Frequency DESC) )+ (ntile(5) OVER (ORDER BY Monetary DESC)) )/2 ,0) as fm_Score
from 
 (select   R.customer_ID ,Trunc((Recent_Transaction - Last_Order ),0) as Recency , Frequency , Monetary 
 from RT_CTE R inner join FREQ_CTE  F on R.Customer_ID=F.CUSTOMER_ID 
 group by R.customer_ID ,Trunc((Recent_Transaction - Last_Order ),0) , Frequency , Monetary ) )
 order by Customer_ID


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--Q3.a: 

WITH Days_CTE AS
 (
  SELECT   
    cust_id, 
    Calendar_Dt,
    LAG(Calendar_Dt, 1) OVER (PARTITION BY cust_id ORDER BY Calendar_Dt) AS Previous_Order,
    (Calendar_Dt - LAG(Calendar_Dt, 1) OVER (PARTITION BY cust_id ORDER BY Calendar_Dt)) AS Days_betn
  FROM  Daily_Transactions
  ORDER BY  Calendar_Dt
)

SELECT 
  cust_id, COUNT(CASE Days_betn WHEN 1 THEN 1 ELSE Null END)  as Maximum_Consecutive_Days
FROM Days_CTE 
GROUP BY cust_id
order by cust_id


-----------------------------------------------------------------------------------------------------------------------------------------------------

--Q3.b 

with RT_CTE as 
(
SELECT  Cust_Id, Calendar_Dt,Amt_LE
, SUM(Amt_LE) OVER (PARTITION BY Cust_Id ORDER BY Calendar_Dt) AS running_total
,first_value(Calendar_Dt) over (partition by Cust_Id order by Calendar_Dt ) as First_order 
    FROM Daily_Transactions 
 )
 ,
 threshold_CTE as 
 (
 Select  distinct Cust_Id, first_value(Calendar_Dt) over (partition by Cust_Id order by Calendar_Dt ) as threshold_Day  from RT_CTE 
 where running_total >=250
)

select avg(distinct (threshold_Day - First_order)) as "Average Num of Days " from RT_CTE R inner join threshold_CTE T on R.cust_id = T.cust_id 
















