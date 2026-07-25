use GlobalIndexAnalytics

----creating a stored procedure which Returns complete historical price data for a selected market.
create Procedure dbo.sp_GetMarketHistory
@Ticker VARCHAR(20)
AS
BEGIN
SET nocount on
select
	TradeDate,
	Ticker,
	IndexName,
	OpenPrice,
	HighPrice,
	LowPrice,
	ClosePrice,
	Volume
from dbo.GlobalIndexPrices
where Ticker=@Ticker
order by TradeDate asc
end
go

EXEC dbo.sp_GetMarketHistory '^GSPC';


--sp_GetMarketByDateRange : Return all market records that fall within a user selected date range.

Create Procedure dbo.sp_GetMarketByDateRange
@StartDate DATE,
@EndDate DATE
AS 
BEGIN
set nocount on
select
	TradeDate,
	Ticker,
	IndexName,
	OpenPrice,
	HighPrice,
	LowPrice,
	ClosePrice,
	Volume
from dbo.GlobalIndexPrices
where TradeDate between @StartDate and @EndDate
order by TradeDate,Ticker
end
go


EXEC dbo.sp_GetMarketByDateRange
    @StartDate = '2023-01-01',
    @EndDate = '2023-12-31';

-- -- sp_GetLatestMarketSnapshot : the latest available record for every market.

create procedure dbo.sp_GetLatestMarketSnapshot
AS
Begin
set nocount on;
with cta1 as (
	select 
	    TradeDate,
		Ticker ,
		IndexName,
		OpenPrice,
		HighPrice,
		LowPrice,
		ClosePrice,
		Volume,
		ROW_NUMBER() over (partition by Ticker order by TradeDate desc) as rwn
	from dbo.GlobalIndexPrices
)
select 
 TradeDate,
 Ticker,
 IndexName,
 OpenPrice,
 HighPrice,
 LowPrice,
 ClosePrice,
 Volume
 from cta1
 where rwn=1
end
go



--sp_GetTopPerformingMarkets : top N performing markets based on their latest closing price

create Procedure dbo.sp_GetTopPerformingMarkets
@TOPn INT
AS 
Begin
set nocount on;
with cta2 as (
	select 
		TradeDate,
		Ticker,
		IndexName,
		ClosePrice,
		ROW_NUMBER() over (partition  by Ticker order by TradeDate desc) as rn
		from dbo.GlobalIndexPrices
)
select TOP(@TOPn)
	TradeDate,
	Ticker,
	IndexName,
	ClosePrice
	from cta2
	where rn=1
	order by ClosePrice desc
end;
go

-- sp_GetMonthlyPerformance : analyze monthly performance for a selected year

ALTER  procedure dbo.sp_GetMonthlyPerformance
@Yeaar INT
AS
begin
set nocount on;
select 
	Yearr,
	Monthh,
	MonthNumber,
	Ticker,
	IndexName,
	TradingDays,
	AverageClosePrice,
	HighestClosePrice,
	LowestClosePrice,
	AverageDailyRange
from vw_MonthlyPerformance
where Yearr=@Yeaar
order by MonthNumber,Monthh,Ticker
end;
go


EXEC dbo.sp_GetMonthlyPerformance 2025;

--