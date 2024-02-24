show databases;

create database inventory_management;

use inventory_management;

# TABLE - 'stock' -------------------------------------------------------------------------------------------------------------------------------------

create table stock
(sku_id varchar(6),
current_stock float,
units varchar(5),
avg_lead_time_in_days smallint,
max_lead_time_in_days smallint,
unit_price float);

select * from stock; # after importing data

update stock
set current_stock=round(current_stock,3); 

update stock
set unit_price=round(unit_price,2);

# calculation of minimum lead time (assuming [min_lead_time + max_lead_time]/2 = avg_lead_time)

alter table stock
add column min_lead_time_in_days smallint after max_lead_time_in_days;

update stock
set min_lead_time_in_days=avg_lead_time_in_days*2-max_lead_time_in_days;

select * from stock;

# TABLE - 'past_orders' -------------------------------------------------------------------------------------------------------------------------------

create table past_orders
(order_date varchar(10),
sku_id varchar(6),
order_quantity float);

select * from past_orders; # after importing data

# checking uniqueness of dates

select distinct(left(order_date,2)) as months from past_orders
order by months;

select distinct(mid(order_date,4,2)) as dates from past_orders
order by dates;

select distinct(right(order_date,4)) as years from past_orders
order by years;

# TABLE - 'past_orders_summary' -----------------------------------------------------------------------------------------------------------------------

select count(distinct(order_date)) as number_of_order_dates from past_orders; # number of unique dates in table 'past_orders' = 500

create table past_orders_summary as
select sku_id,count(sku_id) as num_of_orders,round(sum(order_quantity),3) as total_order_qty,round(sum(order_quantity)/500,3) as avg_qty_per_day,
round(max(order_quantity),3) as max_qty_per_day,round(min(order_quantity),3) as min_qty_per_day from past_orders
group by sku_id;

select * from past_orders_summary;

# TABLE - 'stock_summary' (by joining tables 'stock' and 'past_orders_summary') -----------------------------------------------------------------------
                        
create table stock_summary as
select a.*,b.total_order_qty,b.num_of_orders,b.avg_qty_per_day,b.max_qty_per_day,b.min_qty_per_day from stock as a left join past_orders_summary as b 
on a.sku_id=b.sku_id
order by a.sku_id;

select * from stock_summary;

alter table stock_summary
add column (safety_stock float,reorder_point float);

# calculation of safety stock

update stock_summary
set safety_stock=round(((max_lead_time_in_days-avg_lead_time_in_days)*avg_qty_per_day),3);

# calculation of reorder point

update stock_summary
set reorder_point=round(safety_stock+(avg_lead_time_in_days*avg_qty_per_day),3);

# stock classification on the basis of abc, safety stock & reorder point

alter table stock_summary
add column (stock_class varchar(1),safety_stock_level varchar(6),reorder_required varchar(3));

# 1. 'abc' stock classification (on the basis of unit price)

update stock_summary
set stock_class=case
when unit_price>=10000 then 'A'
when unit_price<100 then 'C'
else 'B'
end;

# 2. stock classification (on the basis of safety level)

update stock_summary
set safety_stock_level=if(current_stock>=safety_stock,'Safe','Danger');

# 3. stock classification (on the basis of reorder required)

update stock_summary
set reorder_required=if(current_stock<=reorder_point,'Yes','No');

# INVENTORY OPTIMIZATION ANALYSIS FROM TABLE 'stock_summary' --------------------------------------------------------------------------------------------

select * from stock_summary;

# list of stock items which have no current stock

select sku_id from stock_summary
where current_stock=0;

# list of stock items having their maximum lead time > 40 days with their maximum lead time, and then average lead time sorted in descending order

select sku_id,avg_lead_time_in_days,max_lead_time_in_days from stock_summary
where max_lead_time_in_days>40
order by max_lead_time_in_days desc,avg_lead_time_in_days desc;

# list of stock items for which no order is ever received, but they have current stock

select sku_id,current_stock from stock_summary
where current_stock>0 and total_order_qty is null;

# list of top 20% stock items in terms of total quantity ordered

select sku_id,total_order_qty from stock_summary
order by total_order_qty desc
limit 61; # 20% of 303 stock items = 61 stock items (approx.)

# list of stock items (with their number of orders) having number of orders below average in ascending order

select sku_id,num_of_orders from stock_summary
where num_of_orders<(select avg(num_of_orders) from stock_summary)
order by num_of_orders;

# list of stock items (with their minimum quantity per day) having minimum quantity per day NOT BELOW AVERAGE in descending order

select sku_id,min_qty_per_day from stock_summary
where min_qty_per_day>=(select avg(min_qty_per_day) from stock_summary)
order by min_qty_per_day desc;

# number of stock items on the basis of 'abc' classification, safety stock level & reorder requirement

select stock_class,count(sku_id) as number_of_stock_items from stock_summary
group by stock_class
order by stock_class; # on the basis of 'abc' classification only

select safety_stock_level,count(sku_id) as number_of_stock_items from stock_summary
group by safety_stock_level
order by safety_stock_level desc; # on the basis of safety stock level only

select reorder_required,count(sku_id) as number_of_stock_items from stock_summary
group by reorder_required
order by reorder_required; # on the basis of reorder requirement only

select stock_class,safety_stock_level,reorder_required,count(sku_id) as number_of_stock_items from stock_summary
group by stock_class,safety_stock_level,reorder_required
order by stock_class,safety_stock_level desc,reorder_required; # on all 3 basis - 'abc' classification, safety stock level & reorder requirement