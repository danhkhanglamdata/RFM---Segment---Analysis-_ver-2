SELECT
	Contract,
    (DATEDIFF(day, MAX(CAST(purchase_date AS DATE)), '2022-09-01'))  AS recency,
	ROUND (cast(COUNT(distinct(cast(purchase_date AS DATE))) AS FLOAT) / cast((DATEDIFF(year,cast(created_date AS DATE), '2022-09-01')) AS FLOAT),2) AS frequency,
	 sum(gmv)  / (DATEDIFF(year,cast(created_date AS DATE), '2022-09-01')) AS monetary,
	DATEDIFF(year,cast(created_date AS DATE), '2022-09-01') AS customer_age,
	row_number() over ( order by( sum(gmv)  / (DATEDIFF(year,cast(created_date AS DATE), '2022-09-01')) ) desc ) as rn_monetary,
	row_number() over (order by( DATEDIFF(day, MAX(CAST(purchase_date AS DATE)), '2022-09-01'))  ) as rn_recency,
	ROW_NUMBER() over (order by( ROUND (cast(COUNT(distinct(cast(purchase_date AS DATE))) AS FLOAT) / cast((DATEDIFF(year,cast(created_date AS DATE), '2022-09-01')) AS FLOAT),2)) desc) as rn_frequency
into customer_rfm
FROM [dbo].Customer_Transaction ct
join [dbo].[Customer_Registered]  cr ON ct.CustomerID = cr.ID
where cr.stopdate is null
group by contract, created_date;

select contract, monetary, frequency, recency,
case when rn_monetary >= (select min(rn_monetary) from customer_rfm ) and rn_monetary <  ( select count(rn_monetary) * 0.25 from customer_rfm) then 1
	when rn_monetary >= ( select count(rn_monetary) * 0.25 from customer_rfm) and rn_monetary <  ( select count(rn_monetary) * 0.5 from customer_rfm) then 2
	when rn_monetary >= ( select count(rn_monetary) * 0.5 from customer_rfm) and rn_monetary <  ( select count(rn_monetary) * 0.75 from customer_rfm) then 3
	else 4 end as M, 
case when rn_frequency >= (select min(rn_frequency) from customer_rfm ) and rn_frequency <  ( select count(rn_frequency) * 0.25 from customer_rfm) then 1
	when rn_frequency >= ( select count(rn_frequency) * 0.25 from customer_rfm) and rn_frequency <  ( select count(rn_frequency) * 0.5 from customer_rfm) then 2
	when rn_frequency >= ( select count(rn_frequency) * 0.5 from customer_rfm) and rn_frequency <  ( select count(rn_frequency) * 0.75 from customer_rfm) then 3
	else 4 end as F, 
case when rn_recency >= (select min(rn_recency) from customer_rfm ) and rn_recency <  ( select count(rn_recency) * 0.25 from customer_rfm) then 4
	when rn_recency >= ( select count(rn_recency) * 0.25 from customer_rfm) and rn_recency <  ( select count(rn_recency) * 0.5 from customer_rfm) then 3
	when rn_recency >= ( select count(rn_recency) * 0.5 from customer_rfm) and rn_recency <  ( select count(rn_recency) * 0.75 from customer_rfm) then 2
	else 1 end as R
into #result
from customer_rfm


select *, concat(R,F,M) as RFM 
into customer_segmentation
from #result;	

select  RFM, count(*) as total_clients
from customer_segmentation
group by RFM

select  *
from customer_segmentation

--Mapping 
SELECT *,
CASE
	WHEN RFM IN ('111', '112', '121', '131', '141') THEN 'Lost'
	WHEN RFM IN ('332', '322', '231', '241', '233', '232', '223', '222', '132', '123', '122', '212', '211') THEN 'Hibernating'
	WHEN RFM IN ('144', '214', '215', '115', '114', '113') THEN 'Can’t Lose Them'
	WHEN RFM IN ('243', '242', '234', '224', '143', '142', '134', '133', '124') THEN 'At Risk'
	WHEN RFM IN ('331', '321', '312', '221', '213') THEN 'About To Sleep'
	WHEN RFM IN ('443', '434', '343', '334', '324') THEN 'Customers Needing Attention'
	WHEN RFM IN ('424', '413', '414', '415', '314', '313') THEN 'Promising'
	WHEN RFM IN ('422', '421', '412', '411', '311') THEN 'Recent Customers'
	WHEN RFM IN ('442', '441', '431', '433', '432', '423', '342', '341', '333', '323') THEN 'Potential Loyalist'
	WHEN RFM = '344' THEN 'Loyal Customers'
	WHEN RFM = '444' THEN 'Champion'
	ELSE 'New Customers'
END AS SEGMENTATION
FROM customer_segmentation