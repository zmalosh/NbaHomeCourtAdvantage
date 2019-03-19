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

WITH RegulationScores_CTE AS (
	SELECT sch.GameID as 'GameID'
		, CAST(REPLACE(LEFT(AwayScoreByQuarter, 2), ';', '') AS TINYINT) + 
		CAST(REPLACE(SUBSTRING(AwayScoreByQuarter, 
					CHARINDEX(';', AwayScoreByQuarter,1) + 1, 2), ';','') AS TINYINT) +
		CAST(REPLACE(SUBSTRING(AwayScoreByQuarter,
					CHARINDEX(';', AwayScoreByQuarter, 
					CHARINDEX(';', AwayScoreByQuarter, 1) + 1) + 1,2), ';','') AS TINYINT) +
		CAST(REPLACE(SUBSTRING(AwayScoreByQuarter,
					CHARINDEX(';', AwayScoreByQuarter,
					CHARINDEX(';', AwayScoreByQuarter, 1) +
					CHARINDEX(';', AwayScoreByQuarter, 1) + 1) + 1,2), ';','') AS TINYINT)
			as 'AwayScore'
		, CAST(REPLACE(LEFT(HomeScoreByQuarter, 2), ';', '') AS TINYINT) + 
		CAST(REPLACE(SUBSTRING(HomeScoreByQuarter, 
					CHARINDEX(';', HomeScoreByQuarter,1) + 1, 2), ';','') AS TINYINT) +
		CAST(REPLACE(SUBSTRING(HomeScoreByQuarter,
					CHARINDEX(';', HomeScoreByQuarter, 
					CHARINDEX(';', HomeScoreByQuarter, 1) + 1) + 1,2), ';','') AS TINYINT) +
		CAST(REPLACE(SUBSTRING(HomeScoreByQuarter,
					CHARINDEX(';', HomeScoreByQuarter,
					CHARINDEX(';', HomeScoreByQuarter, 1) +
					CHARINDEX(';', HomeScoreByQuarter, 1) + 1) + 1,2), ';','') AS TINYINT) 
			as 'HomeScore'
	FROM GameSchedules as sch
),
HomeStadiums_CTE AS (
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
			GROUP BY ts.Season, ts.TeamID, sch.StadiumID
		) as t
	) as x
	INNER JOIN Stadiums as s ON x.StadiumID = s.StadiumID
	WHERE x.StadiumRank = 1
),
SeasonGameOrder_CTE AS (
	SELECT sch.GameID
		, sch.GameDate
		, ts.Season
		, ts.TeamID
		, ROW_NUMBER() OVER (PARTITION BY ts.Season, ts.TeamID ORDER BY GameDate asc)
			as 'GameOrder'
	FROM TeamSeasons as ts
	INNER JOIN GameSchedules as sch ON ts.Season = sch.Season
		AND ts.TeamID IN (sch.HomeTeamID, sch.AwayTeamID)
	WHERE sch.GameTypeID IN (@playoffsGameTypeID, @regSeasonGameTypeID)
		AND sch.StatusID IN (@finalGameStatusID
			, @forfeitByAwayStatusID
			, @forfeitByBothStatusID
			, @forfeitByHomeStatusID)
),
TeamPrevGame_CTE AS (
	SELECT ts.TeamID
		, gmOrd_cur.GameID as 'CurrentGameID'
		, gmOrd_lst.GameID as 'PrevGameID'
		, ABS(DATEDIFF(DAY, gmOrd_cur.GameDate, gmOrd_lst.GameDate)) as 'RestDays'
		, gmOrd_cur.GameOrder as 'CurGameNumber'
	FROM TeamSeasons as ts
	INNER JOIN SeasonGameOrder_CTE as gmOrd_cur ON ts.Season = gmOrd_cur.Season
		AND ts.TeamID = gmOrd_cur.TeamID
	INNER JOIN SeasonGameOrder_CTE as gmOrd_lst ON gmOrd_cur.Season = gmOrd_lst.Season
		AND gmOrd_cur.TeamID = gmOrd_lst.TeamID
		AND gmOrd_cur.GameOrder = gmOrd_lst.GameOrder + 1
),
TeamGameBoxscores_CTE AS (
	SELECT tBox.GameID
		, tBox.TeamID
		, tBox.Season
		, CASE WHEN (tBox.TeamID = sch.HomeTeamID AND sch.HomeScore > sch.AwayScore) 
							OR (tBox.TeamID = sch.AwayTeamID AND sch.HomeScore < sch.AwayScore)
				THEN 1
				WHEN sc.HomeScore = sc.AwayScore
				THEN 0.5
				ELSE 0
				END as 'GameResult'
		, CASE WHEN (tBox.TeamID = sch.AwayTeamID AND sc.HomeScore > sc.AwayScore) 
							OR (tBox.TeamID = sch.HomeTeamID AND sc.HomeScore < sc.AwayScore)
				THEN 1
				WHEN sc.HomeScore = sc.AwayScore
				THEN 0.5
				ELSE 0
				END as 'OppGameResult'
		, CASE WHEN tBox.TeamID = sch.HomeTeamID
				THEN sc.HomeScore 
				ELSE sc.AwayScore END as 'Score'
		, CASE WHEN tBox.TeamID = sch.AwayTeamID
				THEN sc.HomeScore
				ELSE sc.AwayScore END as 'OppScore'
		, tBox.Assists as 'Assists'
		, tOppBox.Assists as 'OppAssists'
		, tBox.Rebounds as 'Rebounds'
		, tOppBox.Rebounds as 'OppRebounds'
		, tBox.Steals as 'Steals'
		, tOppBox.Steals as 'OppSteals'
		, tBox.Blocks as 'Blocks'
		, tOppBox.Blocks as 'OppBlocks'
		, tBox.FreeThrowsAttempted as 'FreeThrowAtts'
		, tOppBox.FreeThrowsAttempted as 'OppFreeThrowAtts'
		, tBox.FreeThrowsMade as 'FreeThrowMakes'
		, tOppBox.FreeThrowsMade as 'OppFreeThrowMakes'
		, tBox.ThreePointFieldGoalsMade as 'ThreePointMakes'
		, tOppBox.ThreePointFieldGoalsMade as 'OppThreePointMakes'
		, tBox.PersonalFouls as 'Fouls'
		, tOppBox.PersonalFouls as 'OppFouls'
		, tBox.Turnovers as 'Turnovers'
		, tOppBox.Turnovers as 'OppTurnovers'
	FROM TeamBoxscoreStats as tBox
	INNER JOIN GameSchedules as sch ON tBox.GameID = sch.GameID
	INNER JOIN TeamBoxscoreStats as tOppBox ON tBox.GameID = tOppBox.GameID
		AND tBox.TeamID <> tOppBox.TeamID
	INNER JOIN RegulationScores_CTE as sc ON sch.GameID = sc.GameID
	WHERE sch.GameTypeID IN (@playoffsGameTypeID, @regSeasonGameTypeID)
		AND sch.StatusID = @finalGameStatusID
		AND sch.Season >= @minSeason
		AND sch.Season <= @maxSeason
),
GameWindow_CTE as (
	SELECT cur.TeamID, cur.Season, cur.GameID as 'CurGameID', prev.GameID as 'PrevGameID'
	FROM SeasonGameOrder_CTE as cur
	INNER JOIN SeasonGameOrder_CTE as prev ON cur.Season = prev.Season
		AND cur.TeamID = prev.TeamID
		AND cur.GameOrder > prev.GameOrder
		AND (cur.GameOrder - @pastGameCount) <= prev.GameOrder
	WHERE cur.GameOrder > @pastGameCount
),
PrevGameStats_CTE as (
	SELECT sch.GameID as 'GameID'
		, ts.TeamID as 'TeamID'
		, COUNT(*) as 'GameCnt'
		, AVG(CAST(pBox_past.GameResult AS REAL)) as 'GameResult'
		, AVG(CAST(pBox_past.OppGameResult AS REAL)) as 'OppGameResult'
		, AVG(CAST(pBox_past.Score AS REAL)) as 'Score'
		, AVG(CAST(pBox_past.OppScore AS REAL)) as 'OppScore'
		, AVG(CAST(pBox_past.Assists AS REAL)) as 'Assists'
		, AVG(CAST(pBox_past.OppAssists AS REAL)) as 'OppAssists'
		, AVG(CAST(pBox_past.Rebounds AS REAL)) as 'Rebounds'
		, AVG(CAST(pBox_past.OppRebounds AS REAL)) as 'OppRebounds'
		, AVG(CAST(pBox_past.Steals AS REAL)) as 'Steals'
		, AVG(CAST(pBox_past.OppSteals AS REAL)) as 'OppSteals'
		, AVG(CAST(pBox_past.Blocks AS REAL)) as 'Blocks'
		, AVG(CAST(pBox_past.OppBlocks AS REAL)) as 'OppBlocks'
		, AVG(CAST(pBox_past.FreeThrowAtts AS REAL)) as 'FreeThrowAtts'
		, AVG(CAST(pBox_past.OppFreeThrowAtts AS REAL)) as 'OppFreeThrowAtts'
		, AVG(CAST(pBox_past.FreeThrowMakes AS REAL)) as 'FreeThrowMakes'
		, AVG(CAST(pBox_past.OppFreeThrowMakes AS REAL)) as 'OppFreeThrowMakes'
		, AVG(CAST(pBox_past.Fouls AS REAL)) as 'Fouls'
		, AVG(CAST(pBox_past.OppFouls AS REAL)) as 'OppFouls'
		, AVG(CAST(pBox_past.Turnovers AS REAL)) as 'Turnovers'
		, AVG(CAST(pBox_past.OppTurnovers AS REAL)) as 'OppTurnovers'
		, AVG(CAST(pBox_past.ThreePointMakes AS REAL)) as 'ThreePointMakes'
		, AVG(CAST(pBox_past.OppThreePointMakes AS REAL)) as 'OppThreePointMakes'
	FROM TeamSeasons as ts
	INNER JOIN GameSchedules as sch ON ts.Season = sch.Season
		AND ts.TeamID IN (sch.HomeTeamID, sch.AwayTeamID)
	INNER JOIN GameWindow_CTE as win ON sch.GameID = win.CurGameID
		AND ts.Season = win.Season 
		AND ts.TeamID = win.TeamID
	INNER JOIN TeamGameBoxscores_CTE as pBox_past ON win.PrevGameID = pBox_past.GameID
		AND pBox_past.TeamID = ts.TeamID
	INNER JOIN TeamGameBoxscores_CTE as pOppBox_past ON pBox_past.GameID = pOppBox_past.GameID
		AND pBox_past.TeamID <> pOppBox_past.TeamID
	WHERE sch.GameTypeID IN (@playoffsGameTypeID, @regSeasonGameTypeID)
		AND sch.StatusID = @finalGameStatusID
		AND sch.Season >= @minSeason
		AND sch.Season <= @maxSeason
	GROUP BY sch.GameID, ts.TeamID
)

SELECT sch.GameID as 'GameID'
	, sch.Season
	, CASE WHEN sch.GameTypeID = @regSeasonGameTypeID THEN 1
		WHEN sch.GameTypeID = @playoffsGameTypeID THEN 2
		WHEN sch.GameTypeID = @preseasonGameTypeID THEN 3
		ELSE NULL END as 'GameTypeID'
	, ats.Alias as 'AwayTeam'
	, hts.Alias as 'HomeTeam'
	, sc.AwayScore as 'AwayScore'
	, sc.HomeScore as 'HomeScore'
	, CAST(sch.GameDate AS DATE) as 'GameDate'
	, CASE WHEN sch.StadiumID = hHmStadLookup.StadiumID
			AND sch.HomeTeamID = hHmStadLookup.TeamID
			AND sch.Season = hHmStadLookup.Season 
		THEN 0
		ELSE 1
		END as 'IsNeutralSite'
	, sch.TotalQuarters - 4 as 'OvertimePeriods'
	, sch.Attendance as 'Attendance'
	, aPrevGmLookup.RestDays - 1 as 'AwayRest'
	, hPrevGmLookup.RestDays - 1 as 'HomeRest'
	, aPrevGmLookup.CurGameNumber as 'AwayGameNum'
	, hPrevGmLookup.CurGameNumber as 'HomeGameNum'
	, CAST(ABS(
			GEOGRAPHY::Point(stad.Latitude, stad.Longitude, @srid)
			.STDistance(GEOGRAPHY::Point(aPrevGmStad.Latitude, aPrevGmStad.Longitude, @srid)
		)*@metersToMiles) AS INT) as 'AwayMilesTraveled'
	, CAST(ABS(
			GEOGRAPHY::Point(stad.Latitude, stad.Longitude, @srid)
			.STDistance(GEOGRAPHY::Point(hPrevGmStad.Latitude, hPrevGmStad.Longitude, @srid)
		)*@metersToMiles) AS INT) as 'HomeMilesTraveled'
	, CAST(ABS(
			GEOGRAPHY::Point(stad.Latitude, stad.Longitude, @srid)
			.STDistance(GEOGRAPHY::Point(aHmStadLookup.Latitude, aHmStadLookup.Longitude, @srid)
		)*@metersToMiles) AS INT) as 'AwayMilesAway'
	, CAST(ABS(
			GEOGRAPHY::Point(stad.Latitude, stad.Longitude, @srid)
			.STDistance(GEOGRAPHY::Point(hHmStadLookup.Latitude, hHmStadLookup.Longitude, @srid)
		)*@metersToMiles) AS INT) as 'HomeMilesAway'
	, CASE WHEN ats.ConferenceID = hts.ConferenceID
		THEN 1
		ELSE 0
		END as 'AreSameConference'
	, CASE WHEN ats.ConferenceID = hts.ConferenceID AND ats.DivisionID = hts.DivisionID
		THEN 1
		ELSE 0
		END as 'AreSameDivision'
	, CASE WHEN sch.HomeScore > sch.AwayScore THEN 1 ELSE 0 END as 'HomeResult'
	, CASE WHEN sch.AwayScore > sch.HomeScore THEN 1 ELSE 0 END as 'AwayResult'
	, (hPrevGmLookup.RestDays - 1) - (aPrevGmLookup.RestDays - 1) as 'HomeRestAdv'
	, hBox.Assists as 'HomeAssists'
	, hBox.Rebounds as 'HomeRebounds'
	, hBox.Steals as 'HomeSteals'
	, hBox.Turnovers as 'HomeTurnovers'
	, hBox.PersonalFouls as 'HomeFouls'
	, hBox.FreeThrowsAttempted as 'HomeFreeThrowAtts'
	, hBox.FreeThrowsMade as 'HomeFreeThrowMakes'
	, hBox.Blocks as 'HomeBlocks'
	, hBox.ThreePointFieldGoalsMade as 'HomeThreePointMakes'
	, aBox.Assists as 'AwayAssists'
	, aBox.Rebounds as 'AwayRebounds'
	, aBox.Steals as 'AwaySteals'
	, aBox.Turnovers as 'AwayTurnovers'
	, aBox.PersonalFouls as 'AwayFouls'
	, aBox.FreeThrowsAttempted as 'AwayFreeThrowAtts'
	, aBox.FreeThrowsMade as 'AwayFreeThrowMakes'
	, aBox.Blocks as 'AwayBlocks'
	, aBox.ThreePointFieldGoalsMade as 'AwayThreePointMakes'
	, hpgs.Score as 'PrevHomeScore'
	, hpgs.Assists as 'PrevHomeAssists'
	, hpgs.Rebounds as 'PrevHomeRebounds'
	, hpgs.Steals as 'PrevHomeSteals'
	, hpgs.Turnovers as 'PrevHomeTurnovers'
	, hpgs.Fouls as 'PrevHomeFouls'
	, hpgs.FreeThrowAtts as 'PrevHomeFreeThrowAtts'
	, hpgs.FreeThrowMakes as 'PrevHomeFreeThrowMakes'
	, hpgs.Blocks as 'PrevHomeBlocks'
	, hpgs.ThreePointMakes as 'PrevHomeThreePointMakes'
	, apgs.Score as 'PrevAwayScore'
	, apgs.Assists as 'PrevAwayAssists'
	, apgs.Rebounds as 'PrevAwayRebounds'
	, apgs.Steals as 'PrevAwaySteals'
	, apgs.Turnovers as 'PrevAwayTurnovers'
	, apgs.Fouls as 'PrevAwayFouls'
	, apgs.FreeThrowAtts as 'PrevAwayFreeThrowAtts'
	, apgs.FreeThrowMakes as 'PrevAwayFreeThrowMakes'
	, apgs.Blocks as 'PrevAwayBlocks'
	, apgs.ThreePointMakes as 'PrevAwayThreePointMakes'
	, hpgs.OppScore as 'PrevOppHomeScore'
	, hpgs.OppAssists as 'PrevOppHomeAssists'
	, hpgs.OppRebounds as 'PrevOppHomeRebounds'
	, hpgs.OppSteals as 'PrevOppHomeSteals'
	, hpgs.OppTurnovers as 'PrevOppHomeTurnovers'
	, hpgs.OppFouls as 'PrevOppHomeFouls'
	, hpgs.OppFreeThrowAtts as 'PrevOppHomeFreeThrowAtts'
	, hpgs.OppFreeThrowMakes as 'PrevOppHomeFreeThrowMakes'
	, hpgs.OppBlocks as 'PrevOppHomeBlocks'
	, hpgs.OppThreePointMakes as 'PrevOppHomeThreePointMakes'
	, apgs.OppScore as 'PrevOppAwayScore'
	, apgs.OppAssists as 'PrevOppAwayAssists'
	, apgs.OppRebounds as 'PrevOppAwayRebounds'
	, apgs.OppSteals as 'PrevOppAwaySteals'
	, apgs.OppTurnovers as 'PrevOppAwayTurnovers'
	, apgs.OppFouls as 'PrevOppAwayFouls'
	, apgs.OppFreeThrowAtts as 'PrevOppAwayFreeThrowAtts'
	, apgs.OppFreeThrowMakes as 'PrevOppAwayFreeThrowMakes'
	, apgs.OppBlocks as 'PrevOppAwayBlocks'
	, apgs.OppThreePointMakes as 'PrevOppAwayThreePointMakes'
FROM GameSchedules as sch
INNER JOIN RegulationScores_CTE as sc ON sch.GameID = sc.GameID
INNER JOIN Stadiums as stad ON sch.StadiumID = stad.StadiumID
INNER JOIN StadiumSeasons as stadSea ON stad.StadiumID = stadSea.StadiumID
	AND sch.Season = stadSea.Season

INNER JOIN TeamSeasons as ats ON sch.Season = ats.Season
	AND sch.AwayTeamID = ats.TeamID
INNER JOIN TeamPrevGame_CTE as aPrevGmLookup ON sch.GameID = aPrevGmLookup.CurrentGameID
	AND sch.AwayTeamID = aPrevGmLookup.TeamID
INNER JOIN GameSchedules as aPrevGm ON aPrevGmLookup.PrevGameID = aPrevGm.GameID
INNER JOIN Stadiums as aPrevGmStad ON aPrevGm.StadiumID = aPrevGmStad.StadiumID
INNER JOIN HomeStadiums_CTE as aHmStadLookup ON sch.AwayTeamID = aHmStadLookup.TeamID
	AND sch.Season = aHmStadLookup.Season
INNER JOIN TeamBoxscoreStats as aBox ON ats.TeamID = aBox.TeamID AND sch.GameID = aBox.GameID
INNER JOIN PrevGameStats_CTE as apgs ON sch.GameID = apgs.GameID
	AND sch.AwayTeamID = apgs.TeamID

INNER JOIN TeamSeasons as hts ON sch.Season = hts.Season
	AND sch.HomeTeamID = hts.TeamID
INNER JOIN TeamPrevGame_CTE as hPrevGmLookup ON sch.GameID = hPrevGmLookup.CurrentGameID
	AND sch.HomeTeamID = hPrevGmLookup.TeamID
INNER JOIN GameSchedules as hPrevGm ON hPrevGmLookup.PrevGameID = hPrevGm.GameID
INNER JOIN Stadiums as hPrevGmStad ON hPrevGm.StadiumID = hPrevGmStad.StadiumID
INNER JOIN HomeStadiums_CTE as hHmStadLookup ON sch.HomeTeamID = hHmStadLookup.TeamID
	AND sch.Season = hHmStadLookup.Season
INNER JOIN TeamBoxscoreStats as hBox ON hts.TeamID = hBox.TeamID AND sch.GameID = hBox.GameID
INNER JOIN PrevGameStats_CTE as hpgs ON sch.GameID = hpgs.GameID
	AND sch.HomeTeamID = hpgs.TeamID

WHERE sch.GameTypeID IN (@playoffsGameTypeID, @regSeasonGameTypeID)
	AND sch.StatusID = @finalGameStatusID
	AND sch.Season >= 2005
	AND sch.Season < 2017
	AND hPrevGmLookup.CurGameNumber > 1
	AND aPrevGmLookup.CurGameNumber > 1
