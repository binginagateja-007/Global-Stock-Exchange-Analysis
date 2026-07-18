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

SELECT COUNT(*)
FROM GlobalIndexPrices;


SELECT TOP 10 *
FROM GlobalIndexPrices;