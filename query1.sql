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


select IndexName,
YEAR(TradeDate) as _Year,
MONTH(TradeDate) as MonthNumber,
DATENAME(month,TradeDate) as Month_Name,
COUNT(*) as TradingDays,
AVG(ClosePrice) as AverageClosingPrice,
MAX(ClosePrice) as HighestClosingPrice,
MIN(ClosePrice) as LowestClosingPrice,
AVG(Case when Volume > 0 then Volume End) as AverageVolume,
AVG(HighPrice-LowPrice) as DailyAverage
from GlobalIndexPrices
group by IndexName,YEAR(TradeDate) ,
MONTH(TradeDate) ,
DATENAME(month,TradeDate) 


-- Quarterly Performance
--  Lowest Close Average Volume (excluding 0)Average Daily Range

select 
IndexName,
YEAR(TradeDate) as Yearr,
'Q'+DATENAME(quarter,TradeDate) as QuarterName,
COUNT(*) as TradingDays,
AVG(ClosePrice) as AverageClosingPrice,
MAX(ClosePrice) as HighestClosingPrice,
MIN(ClosePrice) as LowestClosingPrice,
AVG(case when volume > 0 then volume end) as AverageVolume
from GlobalIndexPrices
group by IndexName,YEAR(TradeDate),DATENAME(quarter,TradeDate)


-- Task 3 — Yearly Performance

select IndexName,
YEAR(TradeDate) as Yeaar,
COUNT(*) as TradingDays,
MAX(ClosePrice) as HighestClosePrice,
MIN(ClosePrice) as LowestClosePrice,
AVG(ClosePrice) as AverageClosingPrice,
AVG(case when volume>0 then volume end) as AverageVolume,
MAX(Volume) as Highestvolume,
MIN(case when volume > 0 then volume end) as LowestVolume
from GlobalIndexPrices
group by IndexName,YEAR(TradeDate)
order by IndexName,YEAR(TradeDate)

-- TASK 4 - Year-over-Year (YoY) Growth

with cta1 as (
    select IndexName ,
    YEAR(TradeDate) as Yearr,
    AVG(ClosePrice) as CurrentAverageCp
    from GlobalIndexPrices
    group by IndexName,YEAR(TradeDate)
),
cta2 as (
    select IndexName,
    [Yearr],
    CurrentAverageCp,
    LAG(CurrentAverageCp,1,NULL) over (partition by IndexName order by [Yearr]) as prevAverageCp
    from cta1
)
select 
IndexName,
[Yearr],
CurrentAverageCp,
[prevAverageCp],
(CurrentAverageCp-[prevAverageCp]) as YoYChange,
((CurrentAverageCp - prevAverageCp) * 1.0 / NULLIF(prevAverageCp, 0)) AS [YoY Growth %]
from cta2
order by IndexName,Yearr

--- Month-over-Month (MoM) Growth

with dat as (
    select 
        IndexName,
        YEAR(TradeDate) as Yearr,
        DATENAME(Month,TradeDate) as Month_Name,
        MONTH(TradeDate) as mon,
        AVG(Closeprice) as AverageCloseprice
        from GlobalIndexPrices
        group by IndexName,Year(TradeDate),DATENAME(Month,TradeDate),MONTH(TradeDate)
),
metrics as (
    select 
        IndexName,
        [Yearr],
        [Month_Name],
        [mon],
        AverageCloseprice,
        LAG(AverageClosePrice,1,NULL) over (partition by IndexName order by [Yearr],[mon]) as prevcp
        from dat
)
select 
    IndexName,
    [Yearr],
    [Month_Name],
    [mon],
    AverageCloseprice,
    [prevcp],
    ((AverageClosePrice-[prevcp])*1.0/[prevcp])*100 as [MoMGrowth%]
    from metrics
    order by IndexName,Yearr,mon

-- Best Performing Year : Which year had the highest average closing price for each index?

with best as (
    select 
        IndexName,
        YEAR(TradeDate) as Yearr,
        AVG(ClosePrice) as AverageClosePrice
        from GlobalIndexPrices
        group by IndexName,YEAR(TradeDate)
    ),
bmetrics as (
    select 
        IndexName,
        [Yearr],
        [AverageClosePrice],
        RANK() over (partition by IndexName order by AverageClosePrice desc) as rnk
        from best
    )
select 
    IndexName,
    [Yearr],
    [AverageClosePrice]
    from bmetrics
    where rnk=1


--- Worst Performing Year : Which year had the worst average closing price for each index?
with best as (
    select 
        IndexName,
        YEAR(TradeDate) as Yearr,
        AVG(ClosePrice) as AverageClosePrice
        from GlobalIndexPrices
        group by IndexName,YEAR(TradeDate)
    ),
bmetrics as (
    select 
        IndexName,
        [Yearr],
        [AverageClosePrice],
        RANK() over (partition by IndexName order by AverageClosePrice asc) as rnk
        from best
    )
select 
    IndexName,
    [Yearr],
    [AverageClosePrice]
    from bmetrics
    where rnk=1


-- Best Performing Month Across all available years, which calendar month has 
--historically shown the highest average closing price for each index?


with hist as (
    select 
        IndexName ,
        MONTH(TradeDate) as Month_Number,
        DATENAME(MONTH,TradeDate) as Month_Name,
        AVG(ClosePrice) as AverageCp
    from GlobalIndexPrices
    group by IndexName,MONTH(TradeDate),DATENAME(MONTH,TradeDate)
),
hist2 as (
    select
        IndexName,
        [Month_Number],
        [Month_Name],
        [AverageCp],
        RANK() over (partition by IndexName order by AverageCp desc) as rnk
        from hist
    )
select 
IndexName,
[Month_Number],
[Month_Name],
[AverageCp]
from hist2
where rnk=1
order by IndexName

-- Worst Performing Month


with hist as (
    select 
        IndexName ,
        MONTH(TradeDate) as Month_Number,
        DATENAME(MONTH,TradeDate) as Month_Name,
        AVG(ClosePrice) as AverageCp
    from GlobalIndexPrices
    group by IndexName,MONTH(TradeDate),DATENAME(MONTH,TradeDate)
),
hist2 as (
    select
        IndexName,
        [Month_Number],
        [Month_Name],
        [AverageCp],
        RANK() over (partition by IndexName order by AverageCp asc) as rnk
        from hist
    )
select 
IndexName,
[Month_Number],
[Month_Name],
[AverageCp]
from hist2
where rnk=1
order by IndexName


--Monthly Trend Consistency

WITH MonthlyAverages AS (
    SELECT 
        IndexName AS [Index],
        YEAR(TradeDate) AS [TradingYear],
        MONTH(TradeDate) AS [MonthNumber],
        AVG(ClosePrice) AS [AvgMonthlyClose]
    FROM 
        GlobalIndexPrices
    GROUP BY 
        IndexName,
        YEAR(TradeDate),
        MONTH(TradeDate)
),
MonthlyReturns AS (
    SELECT 
        [Index],
        [TradingYear],
        [MonthNumber],
        [AvgMonthlyClose],
        LAG([AvgMonthlyClose], 1, NULL) OVER (
            PARTITION BY [Index] 
            ORDER BY [TradingYear], [MonthNumber]
        ) AS [PrevAvgMonthlyClose]
    FROM 
        MonthlyAverages
)
SELECT 
    [Index],
    COUNT(DISTINCT [TradingYear]) AS [Number of Years],
    COUNT([AvgMonthlyClose]) AS [Total Months],
    AVG((( [AvgMonthlyClose] - [PrevAvgMonthlyClose] ) * 100.0) / NULLIF([PrevAvgMonthlyClose], 0)) AS [Average Monthly Return],
    MAX([AvgMonthlyClose]) AS [Highest Monthly Average],
    MIN([AvgMonthlyClose]) AS [Lowest Monthly Average]
FROM 
    MonthlyReturns
GROUP BY 
    [Index]
ORDER BY 
    [Index];


--------------------------------------------MODULE 5 ANALYSIS------------------------------------------------------------------------------------------


