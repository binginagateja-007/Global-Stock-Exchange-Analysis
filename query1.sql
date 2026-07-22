CREATE DATABASE GlobalIndexAnalytics;

use GlobalIndexAnalytics

CREATE TABLE GlobalIndexPrices
(
    PriceID INT IDENTITY(1,1) PRIMARY KEY,

    TradeDate DATE NOT NULL,

    Ticker VARCHAR(20) NOT NULL,

    IndexName VARCHAR(100) NOT NULL,

    OpenPrice DECIMAL(18,4) NOT NULL,

    HighPrice DECIMAL(18,4) NOT NULL,

    LowPrice DECIMAL(18,4) NOT NULL,

    ClosePrice DECIMAL(18,4) NOT NULL,

    Volume BIGINT NOT NULL,

    CreatedAt DATETIME DEFAULT GETDATE()
);

ALTER TABLE GlobalIndexPrices
ADD CONSTRAINT UQ_GlobalIndexPrices
UNIQUE (TradeDate, Ticker);

SELECT   *
FROM GlobalIndexPrices;


------------------------------------------------MODULE 1 ANALYSIS ---------------------------------------------------
-- How many market records are available?
select COUNT(*) as Total_Records from GlobalIndexPrices

-- What is the first and latest trading date in the database?
select MIN(TradeDate) as StartingDate,
MAX(TradeDate) as EndDate
from GlobalIndexPrices

--How many unique global indices are we tracking?
select COUNT(Distinct Ticker) as Number_of_Indices 
from GlobalIndexPrices

-- Does every index have approximately the same number of trading records?
select Ticker ,COUNT(TradeDate) as Records
from GlobalIndexPrices
group by Ticker

-- Duplicate Detection using the Trade Date and Ticker
select TradeDate , 
Ticker,
COUNT(*) as Total_Records
from GlobalIndexPrices
group by TradeDate,Ticker
having COUNT(*) > 1

-- Null Values Inspection
select COUNT(*) as Total_Records,
SUM(case when PriceId  IS null THEN 1 ElSE 0 END) as null_priceid,
SUM(case when TradeDate is null then 1 else 0 end) as null_trade_date,
SUM(case when Ticker is null then 1 else 0 end) as null_ticker,
sum(case when IndexName is null then 1 else 0 end) as null_index_name,
SUM(case when OpenPrice is null then 1 else 0 end) as null_open_price,
sum(case when HighPrice is null then 1 else 0 end) as null_high_price,
sum(case when LowPrice is null then 1 else 0 end) as null_low_price,
Sum(case when ClosePrice is null then 1 else 0 end) as null_close_price,
sum(case when Volume is null then 1 else 0 end) as null_volume
from GlobalIndexPrices

-- Invalid Price Validation
select * from GlobalIndexPrices
where OpenPrice <= 0 or
HighPrice <= 0 or 
LowPrice <=0 or
ClosePrice <=0 

-- Price Consistency Validation
select * from GlobalIndexPrices
where not(HighPrice>=OpenPrice and HighPrice>=ClosePrice) and (LowPrice<=OpenPrice and LowPrice<=ClosePrice)


-- Negative Volume Check
select * from GlobalIndexPrices
where Volume=0

-- No trade date should be greater than today.
select * from 
GlobalIndexPrices
where TradeDate > CURRENT_DATE

------------------------------------------------MODULE 2 ANALYSIS ---------------------------------------------------
---Market Summary Table
select Indexname,Ticker ,
COUNT(TradeDate) as Trading_Days,
MIN(TradeDate) as First_Trade_date,
MAX(TradeDate) as Last_Trade_Date,
MAX(ClosePrice) as Highest_Closing_Price,
MIN(ClosePrice) as Lowest_Closing_Price,
AVG(ClosePrice) as Average_Closing_Price,
MAX(HighPrice) as Highest_high_price,
MIN(Highprice) as lowest_high_price,
AVG(HighPrice-LowPrice) as Daily_Average
from GlobalIndexPrices
group by IndexName,Ticker


-- Volume Profile Summary Table Index Name

select Indexname , Ticker,
MAX(Volume) as Highest_Volume,
MIN(CASE when volume > 0 then volume end) as Lowest_Non_Zero_Volume,
AVG(Case when Volume > 0 then volume end) as Average_Volume,
SUM(Case when volume = 0 or volume is null then 1 else 0 end) as Number_of_zero_volume_days
from GlobalIndexPrices
group by IndexName,Ticker

-- Which index has the highest closing value in the entire dataset?
select top 1 IndexName,
max(ClosePrice) as highest_closing_value
from GlobalIndexPrices
group by IndexName
order by MAX(ClosePrice) desc

-- Which index has the lowest closing value?
select top 1 IndexName,
MIN(ClosePrice) as lowest_closing_value
from GlobalIndexPrices
group by IndexName
order by MIN(ClosePrice) asc

-- Which index has the largest average daily trading range?
select top 1 IndexName ,
AVG(HighPrice-LowPrice) as Average_Closing_Price
from GlobalIndexPrices
group by IndexName
order by AVG(HighPrice-ClosePrice) desc

-- Which index has the highest average closing price?
select top 1 IndexName ,
AVG(ClosePrice) as Average_Closing_Price
from GlobalIndexPrices
group by IndexName
order by AVG(ClosePrice) desc

-- Which index has the most trading days?
select top 1 IndexName ,
COUNT(TradeDate) as Trading_Days
from GlobalIndexPrices
group by IndexName
order by COUNT(TradeDate) desc


-- Data Distribution Check


--Total Records
--Distinct Trading Years
--Average Records per Year

WITH YearlyCounts AS (
    SELECT 
        IndexName,
        COUNT(TradeDate) AS TotalRecords,
        YEAR(TradeDate) AS Trading_Year
    FROM 
        GlobalIndexPrices
    GROUP BY 
        IndexName,YEAR(TradeDate)
)
SELECT 
    IndexName,
    SUM(TotalRecords) AS Total_Trading_Days,
    COUNT(Trading_Year) AS Total_Trading_Years,
    AVG(TotalRecords) AS Average_Records_Per_Year
FROM 
    YearlyCounts
GROUP BY 
    IndexName
ORDER BY 
    Average_Records_Per_Year DESC;

-----------------------------------------------MODULE 3 ANALYSIS------------------------------------------------------------------------------------


-- Create a Daily Performance Dataset

with perform as (
select 
    TradeDate,
    IndexName,
    Ticker,
    ClosePrice,
    LAG(ClosePrice,1,NULL) over (partition by IndexName order by TradeDate) as previous_close_price
from GlobalIndexPrices
)
select 
    TradeDate,
    IndexName,
    Ticker,
    ClosePrice,
    previous_close_price,
    (ClosePrice-previous_close_price) as ClosePrice_change,
    ((ClosePrice-previous_close_price)/previous_close_price)*100 as ClosePrice_Change
    from perform



-- To find out the  Biggest Gain Dayy
with dailyperform as (
select 
    TradeDate as [Date],
    IndexName as [Index],
    ClosePrice as Currentprice,
    LAG(ClosePrice,1,NULL) over (partition by IndexName order by TradeDate) as Previous_closeprice
    from GlobalIndexPrices
),
calculatedprice as (
    select 
    [Date],
    [Index],
    [Currentprice],
    [Previous_closeprice],
    (([Currentprice]-[Previous_closeprice])*1.0/[Previous_closeprice])*100 as ClosePrice_PCT
    from dailyperform
    where [Previous_closeprice] is not null
    )
select
top 1
[Date],
[Index],
[Currentprice],
[Previous_closeprice],
ROUND(ClosePrice_PCT,2) as daily_return_average
from calculatedprice
order by ClosePrice_PCT desc


-- To findout the biggest day losss

with dailyperform as (
select 
    TradeDate as [Date],
    IndexName as [Index],
    ClosePrice as Currentprice,
    LAG(ClosePrice,1,NULL) over (partition by IndexName order by TradeDate) as Previous_closeprice
    from GlobalIndexPrices
),
calculatedprice as (
    select 
    [Date],
    [Index],
    [Currentprice],
    [Previous_closeprice],
    (([Currentprice]-[Previous_closeprice])*1.0/[Previous_closeprice])*100 as ClosePrice_PCT
    from dailyperform
    where [Previous_closeprice] is not null
    )
select
top 1
[Date],
[Index],
[Currentprice],
[Previous_closeprice],
ROUND(ClosePrice_PCT,2) as daily_return_average
from calculatedprice
order by ClosePrice_PCT asc

-- Largest Absolute Price Change : Which Day was Highest PriceChange

with calculation as (
    select 
    TradeDate as [Date],
    IndexName as [Index],
    ClosePrice as Currentclose,
    LAG(ClosePrice,1,NULL) over (partition by IndexName order by TradeDate) as previousclose_price
    from GlobalIndexPrices
)
select Top 1
[Date],
[Index],
[Currentclose] ,
[previousclose_price],
([Currentclose]-[previousclose_price]) as close_price_change
from calculation
order by close_price_change desc


-- Biggest Intraday Movement : Which trading day had the largest intraday swing?

with intraday as (
    select 
    TradeDate as [Date],
    IndexName as [Index],
    HighPrice as [High],
    LowPrice as [Low]
    from GlobalIndexPrices
    )
select Top 1
[Date],
[Index],
[High],
[Low],
([High]-[Low]) as Intra_day_range
from intraday
order by Intra_day_range desc

-- Highest Trading Volume Day : Which market recorded the highest trading volume in history?
select top 1 
TradeDate,
IndexName,
Volume
from GlobalIndexPrices
order by Volume desc


-- Best Trading Day for Each Index
--For every index, identify: Date,Daily Return %, Previous Close , Current Close

with cta1 as (
    select 
        TradeDate,
        IndexName,
        ClosePrice as Currentclose,
        LAG(ClosePrice,1,NULL) over(partition by IndexName order by TradeDate) as previousclose
        from GlobalIndexPrices
),
cta2 as (
    select 
    TradeDate,
    IndexName,
    Currentclose,
    previousclose,
    ((Currentclose-previousclose)*1.0/previousclose)*100 as dailyreturn_pct,
    ROW_NUMBER() over (partition by IndexName order by ((Currentclose-previousclose)*1.0/previousclose)*100 desc) AS rnk
    from cta1
    )
select
TradeDate,
IndexName,
Currentclose,
previousclose,
ROUND(dailyreturn_pct,2) as DailyReturnpct
from cta2
where rnk=1


-- Worst Trading Day for Each Index


with cta3 as (
    select 
        TradeDate,
        IndexName,
        ClosePrice as Currentclose,
        LAG(ClosePrice,1,NULL) over(partition by IndexName order by TradeDate) as previousclose
        from GlobalIndexPrices
),
cta4 as (
    select 
    TradeDate,
    IndexName,
    Currentclose,
    previousclose,
    ((Currentclose-previousclose)*1.0/previousclose)*100 as dailyreturn_pct,
    ROW_NUMBER() over (partition by IndexName order by ((Currentclose-previousclose)*1.0/previousclose)*100 asc) AS rnk
    from cta3
    )
select
TradeDate,
IndexName,
Currentclose,
previousclose,
ROUND(dailyreturn_pct,2) as DailyReturnpct
from cta4
where rnk=2

-----------------------------------MODULE 4 ANALYSIS ------------------------------------------------------

-- Monthly Market Performence
