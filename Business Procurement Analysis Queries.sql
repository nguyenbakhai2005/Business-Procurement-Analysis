USE [Project DA 2]
select *
from [Dataset_Procurement.xlsx - Data];
--C1 How has spending behavior changed over the years? Are there any seasonal patterns that influence ordering behavior?
with cte1 as(
select	PO_Year year,
		MONTH(PO_Date) month, 
		sum(Line_Net) total_spend_per_month
from [Dataset_Procurement.xlsx - Data]
group by PO_Year,MONTH(PO_Date)
)
select	year, 
		month, 
		total_spend_per_month,
		lag(total_spend_per_month) over (order by year,month) as previous_month_spend,
		round((total_spend_per_month - lag(total_spend_per_month) over (order by year,month))/ nullif(lag(total_spend_per_month) over (order by year,month),0)*100,2) month_growth_percentage
from cte1;
--C2 "Where is the money going?": Top 5 product categories, departments, suppliers, or regions account for the highest share of spending?
select	top 5
		Category, 
		Department, 
		Supplier_Region, 
		round(sum(Line_Net)*100/sum(sum(Line_Net)) over(),2) percentage_of_total
from [Dataset_Procurement.xlsx - Data]
group by Category, Department, Supplier_Region
order by percentage_of_total desc;
--C3 Budget control: How much does actual spending deviate from the budget? Which categories consistently exceed their allocated limits?
select	category,
		sum(Line_Net) total_spend, 
		sum(Budget_Total) total_budget, 
		sum(Line_Net)-sum(Budget_Total) diff_amount,
		round((sum(Line_Net)-sum(Budget_Total))*100/sum(Budget_Total),2) diff_percentage
from [Dataset_Procurement.xlsx - Data]
group by Category
order by diff_amount;
--C4 Measuring negotiation effectiveness: Which projects or contracts are generating the greatest cost savings for the company?
select	Contract_Type, 
		sum(Savings_Amount) total_savings, 
		round(sum(Savings_Amount)*100/sum(sum(Savings_Amount)) over(),2) percentage_of_total
from [Dataset_Procurement.xlsx - Data]
group by Contract_Type
order by total_savings desc;
--C5 Supplier profile: What are the risk levels, tier classifications, and ESG scores of the top 5 suppliers accounting for the highest share of spending?
select top 5 
		Supplier_Name,
		Supplier_ID, 
		Supplier_Risk,
		Supplier_Tier,
		Supplier_ESG_Score,
		sum(Line_Net) total_spend
from [Dataset_Procurement.xlsx - Data]
group by Supplier_Name,Supplier_ID, Supplier_Risk,Supplier_Tier,Supplier_ESG_Score
order by total_spend desc;
--C6 Effectiveness of the "Preferred Supplier" policy: Is there a clear performance difference between preferred suppliers and occasional (non-preferred) suppliers? What proportion of total spending goes to single-source suppliers?
select	Preferred_Supplier, 
		sum(Line_Net) total_spend, 
		round(avg(Savings_Pct),2) avg_savings_percentage, 
		round(avg(Days_Late),2) avg_days_late,
		round(avg(Supplier_ESG_Score),2) avg_esg_score,
		round(cast(sum(case when On_Time_Delivery = 'Yes' then 1.0 else 0 end)*100/count(*) as decimal(12,2)),2) on_time_percentage
from [Dataset_Procurement.xlsx - Data]
group by Preferred_Supplier;


select	Single_Source_Flag, 
		sum(Line_Net) total_spend,
		round(sum(Line_Net)*100/ sum(sum(Line_Net)) over(),2) spend_percentage
from [Dataset_Procurement.xlsx - Data]
group by Single_Source_Flag
--C7 OTIF (On-time Delivery): What is the average on-time delivery rate? Which suppliers or departments are experiencing the most severe delays?
select round(cast(sum(case when On_Time_Delivery = 'Yes' then 1.0 else 0 end)*100/count(*) as decimal(12,2)),2) on_time_percent
from [Dataset_Procurement.xlsx - Data];


with cte2 as(
	select	Supplier_Name,
			Category,
			count(On_Time_Delivery) total_delivery,
			cast(sum(case when On_Time_Delivery = 'Yes' then 1.0 else 0 end) as decimal(12,2)) on_time
	from [Dataset_Procurement.xlsx - Data]
	group by Supplier_Name, Category
)
select	Supplier_Name,
		Category,
		round(cast(sum(on_time) over(partition by Supplier_Name)*100/sum(total_delivery) over(partition by Supplier_Name)as decimal(12,2)),2) overall_on_time,
		round(cast(on_time*100/total_delivery as decimal(12,2)),2) category_on_time_percent
from cte2
order by overall_on_time desc,category_on_time_percent desc;
--C8 Lead Time analysis: How does delivery lead time vary across different contract types? Is there any relationship between late deliveries and high-risk suppliers?
select	Supplier_Name, 
		avg(Lead_Time_Days) avg_days_delivery,
		avg(Days_Late) avg_days_late,
		round(cast(sum(case when On_Time_Delivery = 'Yes' then 1.0 else 0 end)*100/count(*) as decimal(12,2)),2) on_time_percent
from [Dataset_Procurement.xlsx - Data]
group by Supplier_Name
order by avg_days_delivery;


select	Supplier_Risk, 
		avg(Lead_Time_Days) avg_days_delivery,
		avg(Days_Late) avg_days_late,
		round(cast(sum(case when On_Time_Delivery = 'Yes' then 1.0 else 0 end)*100/count(*) as decimal(12,2)),2) on_time_percent
from [Dataset_Procurement.xlsx - Data]
group by Supplier_Risk
order by avg_days_delivery;


select	Contract_Type, 
		avg(Lead_Time_Days) avg_days_delivery,
		avg(Days_Late) avg_days_late,
		round(cast(sum(case when On_Time_Delivery = 'Yes' then 1.0 else 0 end)*100/count(*) as decimal(12,2)),2) on_time_percent
from [Dataset_Procurement.xlsx - Data]
group by Contract_Type
order by avg_days_delivery;
--C9 Maverick Spend issue: How much off-contract (non-compliant) spending currently exists? How often are preferred suppliers being bypassed?
select	Maverick_Spend, 
		count(*) total_orders,
		round(cast(count(*)*100.0 / sum(count(*)) over() as decimal(12,2)),2) orders_percent,
		sum(Line_Net) total_spend,
		round(sum(Line_Net)*100.0/ sum(sum(Line_Net)) over(),2) spend_percent
from [Dataset_Procurement.xlsx - Data]
group by Maverick_Spend;
--C10 Procure-to-Pay performance: How high are the overdue, disputed, and unmatched invoice rates? What are the critical risk indicators across the P2P cycle?
select
		count(*) total_orders,
		round(cast(sum(case when invoice_status = 'Overdue' then 1.0 else 0 end)*100/count(*) as decimal(12,2)),2) overdue_percent,
		round(cast(sum(case when invoice_status = 'Disputed' then 1.0 else 0 end)*100/count(*) as decimal(12,2)),2) disputed_percent,
		round(cast(sum(case when Invoice_Match_Type = 'No Match' then 1.0 else 0 end)*100/count(*) as decimal(12,2)),2) unmatched_percent

from [Dataset_Procurement.xlsx - Data];


SELECT 
	Supplier_Name,
    count(*) total_red_flag_orders,
	round(cast(count(*)*100.0 / sum(count(*)) over() as decimal(12,2)),2) orders_percent,
    sum(Line_Net) Unpaid_Amount,
	round(sum(Line_Net)*100/sum(sum(Line_Net)) over(),2) percentage_of_total
FROM 
    [Dataset_Procurement.xlsx - Data]
where 
    Payment_Status = 'On Hold' and Invoice_Status = 'Disputed' and Invoice_Match_Type = 'No Match'
group by Supplier_Name
order by Unpaid_Amount DESC;