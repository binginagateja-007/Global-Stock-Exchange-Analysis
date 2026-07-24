use GlobalIndexAnalytics


--- BUILDING the Views which would be helpful for the upcoming Power BI

Create View vw_DailyPerformence
AS

select 
	TradeDate,
	Ticker,
	IndexName,
	ClosePrice,

	LAG(ClosePrice) over(partition by Ticker order by TradeDate) as [PreviousClose],
	ClosePrice - LAG(ClosePrice) over(partition by Ticker order by TradeDate) 
	as [PriceChange],
	(ClosePrice-LAG(ClosePrice)
	over(partition by Ticker order by TradeDate)/
	NULLIF(LAG(ClosePrice) over(partition by Ticker order by TradeDate),0))*100 as [DailyReturnPct],
	case 
		when ClosePrice > Lag(ClosePrice) over(partition by Ticker order by TradeDate)
		then 'Up'
		when ClosePrice < Lag(ClosePrice) over(partition by Ticker order by TradeDate)
		then 'Down'
	    else 'No Change'
	end as MarketChange
	from GlobalIndexPrices

select top 100 * from vw_DailyPerformence

---vw_MovingAverages
--TradeDate Ticker IndexName ClosePrice MovingAverage7 MovingAverage30

create view vw_MovingAverages
AS

select
	TradeDate,
	Ticker,
	IndexName,
	ClosePrice,
	AVG(ClosePrice) over (partition by Ticker order by TradeDate rows between 6 preceding and current row) as  [MovingAverage7],
	AVG(ClosePrice) over (partition by Ticker order by TradeDate rows between 29 preceding and current row) as [MovingAverage30]
from GlobalIndexPrices

select top 100 * from vw_MovingAverages

--vw_RunningMetrics

create view vw_RunningMetrics
AS

select 
	TradeDate,
	Ticker,
	IndexName,
	ClosePrice,
	SUM(ClosePrice) over(partition by Ticker order by TradeDate rows between unbounded preceding and current row) as [RunningClose],
	MAX(ClosePrice) over(partition by Ticker order by TradeDate rows between unbounded preceding and current row) as [HighestRunningClose],
	MIN(ClosePrice) over(partition by Ticker order by TradeDate rows between unbounded preceding and current row) as [LowestRunningClose]
from GlobalIndexPrices

select Top 100 * from vw_RunningMetrics

--- vw_MonthlyPerformance

create view vw_MonthlyPerformance
as 
select 
	YEAR(TradeDate) as [Yearr],
	DATENAME(MONTH,TradeDate) as [Monthh],
	Ticker,
	IndexName,
	COUNT(*) as TradingDays,
	AVG(ClosePrice) as [AverageClosePrice],
	MAX(ClosePrice) as [HighestClosePrice],
	MIN(ClosePrice) as [LowestClosePrice],
	AVG(HighPrice-LowPrice) as [AverageDailyRange]
from GlobalIndexPrices
group by YEAR(TradeDate),
		DATENAME(Month,TradeDate),
		Ticker,
		IndexName

select Top 100 * from vw_MonthlyPerformance

--vw_YearlyPerformance

create view vw_YearlyPerformance
AS
select 
	YEAR(TradeDate) as [Yearr],
	Ticker,
	IndexName,
	COUNT(*) as [TradingDays],
	AVG(ClosePrice) as [AverageClosePrice],
	MAX(ClosePrice) as [HighestClosePrice],
	MIN(ClosePrice) as [LowestClosePrice],
	AVG(HighPrice-LowPrice) as [AverageDailyRange],
	MAX(HighPrice) as [HighestHighPrice],
	MIN(LowPrice) as [LowestLowPrice]
from GlobalIndexPrices
group by 
	YEAR(TradeDate),
	Ticker,
	IndexName
	
select top 100 * from vw_YearlyPerformance


--vw_MarketSummar
CREATE VIEW vw_MarketSummary
AS

WITH LatestMarketData AS
(
    SELECT
        Ticker,
        IndexName,
        TradeDate,
        ClosePrice,
        ROW_NUMBER() OVER
        (
            PARTITION BY Ticker
            ORDER BY TradeDate DESC
        ) AS RN
    FROM GlobalIndexPrices
),

MarketAggregates AS
(
    SELECT
        Ticker,
        IndexName,

        COUNT(*) AS TradingDays,
        MIN(TradeDate) AS FirstTradeDate,
        MAX(TradeDate) AS LatestTradeDate,
        AVG(ClosePrice) AS AverageClosePrice,
        MAX(ClosePrice) AS HighestClosePrice,
        MIN(ClosePrice) AS LowestClosePrice,
        MAX(HighPrice) AS HighestHighPrice,
        MIN(LowPrice) AS LowestLowPrice,
        AVG(HighPrice - LowPrice) AS AverageDailyRange,

        AVG(CASE
                WHEN Volume > 0 THEN CAST(Volume AS FLOAT)
            END) AS AverageVolume,

        MAX(Volume) AS HighestTradingVolume

    FROM GlobalIndexPrices

    GROUP BY
        Ticker,
        IndexName
)

SELECT
    MA.Ticker,
    MA.IndexName,
    MA.TradingDays,
    MA.FirstTradeDate,
    MA.LatestTradeDate,
    LMD.ClosePrice AS LatestClosePrice,
    MA.AverageClosePrice,
    MA.HighestClosePrice,
    MA.LowestClosePrice,
    MA.HighestHighPrice,
    MA.LowestLowPrice,
    MA.AverageDailyRange,
    MA.AverageVolume,
    MA.HighestTradingVolume

FROM MarketAggregates MA

INNER JOIN LatestMarketData LMD
    ON MA.Ticker = LMD.Ticker
   AND LMD.RN = 1;


select top 100 * from vw_MarketSummary