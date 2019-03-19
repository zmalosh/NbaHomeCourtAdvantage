USE FoxSports_SportsData_NBA
GO

DECLARE @regSeasonGameTypeID INT = 1;
DECLARE @playoffsGameTypeID INT = 2;
DECLARE @preseasonGameTypeID INT = 3;
DECLARE @finalGameStatusID INT = 2;
DECLARE @forfeitByAwayStatusID INT = 4;
DECLARE @forfeitByHomeStatusID INT = 5;
DECLARE @forfeitByBothStatusID INT = 7;
DECLARE @srid INT = 4326; -- SRID Geography TYPE. DEFINED BY EXTERNAL STANDARD
DECLARE @metersToMiles REAL = (0.62137119/1000);
DECLARE @pastGameCount INT = 4;
DECLARE @minSeason INT = 2005;
DECLARE @maxSeason INT = 2016;

WITH HomeStadiums_CTE AS (
	SELECT x.Season, x.TeamID, x.StadiumID, s.Latitude, s.Longitude
	FROM (
		SELECT t.Season
			, t.TeamID
			, t.StadiumID
			, ROW_NUMBER() OVER (PARTITION BY t.Season, t.TeamID ORDER BY GameCount desc)
				as 'StadiumRank'
		FROM (
			SELECT ts.Season, ts.TeamID, sch.StadiumID, COUNT(*) as 'GameCount'
			FROM TeamSeasons as ts
			INNER JOIN GameSchedules as sch ON ts.Season = sch.Season
				AND ts.TeamID = sch.HomeTeamID
			WHERE sch.GameTypeID IN (@playoffsGameTypeID, @regSeasonGameTypeID)
				AND sch.Season >= @minSeason
				AND sch.Season <= @maxSeason
			GROUP BY ts.Season, ts.TeamID, sch.StadiumID
		) as t
	) as x
	INNER JOIN Stadiums as s ON x.StadiumID = s.StadiumID
	WHERE x.StadiumRank = 1
),
ValidStadiums_CTE AS (
	SELECT ts.Alias as 'TeamAlias'
		, ts.TeamID
		, CASE WHEN LEFT(ss.[Name], LEN('Nassau')) = 'Nassau'
			THEN 'Nassau Coliseum'
			ELSE ss.[Name] 
			END as 'StadiumName'
		, st.Season
		, st.Longitude
		, st.Latitude
	FROM (
		SELECT hst.TeamID
			, hst.StadiumID
			, hst.Longitude
			, hst.Latitude
			, hst.Season
			, ROW_NUMBER() OVER (PARTITION BY hst.TeamID, hst.StadiumID ORDER BY Season desc)
				as 'StadiumOrder'
		FROM HomeStadiums_CTE as hst
	) as st
	INNER JOIN TeamSeasons as ts ON st.Season = ts.Season AND st.TeamID = ts.TeamID
	INNER JOIN StadiumSeasons as ss ON st.Season = ss.Season AND st.StadiumID = ss.StadiumID
	WHERE st.StadiumOrder = 1 AND st.Season = @maxSeason
)

SELECT a.StadiumName + ' (' + a.TeamAlias + ')' as 'A'
	, b.StadiumName + ' (' + b.TeamAlias + ')' as 'B'
	, CAST(ABS(
			GEOGRAPHY::Point(a.Latitude, a.Longitude, @srid)
			.STDistance(GEOGRAPHY::Point(b.Latitude, b.Longitude, @srid)
		)*@metersToMiles) AS INT) as 'StadDistMiles'
FROM ValidStadiums_CTE as a
CROSS JOIN ValidStadiums_CTE as b
