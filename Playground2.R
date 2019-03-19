library(corrplot)
library(ggplot2)
library(gridExtra)
library(leaps)
library(knitr)
library(plyr)

pValDigits <- 4
pastGameWindow <- 8
minSeason <- 2005
maxSeason <- 2016
corrPlotCexSize <- 4
stepEntryVal <- qchisq(0.05, 1, lower.tail = FALSE)

nba.games <- read.csv('NbaGames.csv', header = TRUE, sep = ',')
nba.games <- nba.games[nba.games$GameTypeID == 1,]
nba.games <- nba.games[as.character(nba.games$Attendance) != 'NULL',]
nba.games <- nba.games[as.integer(as.character(nba.games$Attendance)) > 0,]
nba.games$Season <- as.factor(nba.games$Season)
nba.games$GameTypeID <- as.factor(nba.games$GameTypeID)
nba.games$AwayScore <- as.integer(as.character(nba.games$AwayScore))
nba.games$HomeScore <- as.integer(as.character(nba.games$HomeScore))
nba.games$TotalScore <- as.integer(nba.games$HomeScore + nba.games$AwayScore)
nba.games$HomeMargin <- nba.games$HomeScore - nba.games$AwayScore
nba.games$Attendance <- as.numeric(as.character(nba.games$Attendance)) / 1000
nba.games$GameDate <- as.Date(nba.games$GameDate)
nba.games$IsNeutralSite <- nba.games$IsNeutralSite == 1
nba.games$AreSameConference <- nba.games$AreSameConference == 1
nba.games$AreSameDivision <- nba.games$AreSameDivision == 1
nba.games$HomeTravDiff <- nba.games$HomeMilesTraveled - nba.games$AwayMilesTraveled
nba.games$AwayMilesAway <- nba.games$AwayMilesAway / 100
nba.games$AwayMilesTraveled <- nba.games$AwayMilesTraveled / 100
nba.games$HomeMilesTraveled <- nba.games$HomeMilesTraveled / 100

nba.games <- nba.games[(nba.games$IsNeutralSite == FALSE),]

corrVarColNames <- c('HomeScore', 'AwayScore', 'Attendance', 'AwayRest', 'HomeRest', 'HomeRestAdv', 'AwayMilesTraveled', 'HomeTravDiff', 'AwayMilesAway', 'AwayGameNum', 'HomeGameNum', 'HomeResult', 'AwayResult')
corrVars <- nba.games[, corrVarColNames]
scheduleCor <- cor(corrVars)

restCounts <- rbind(data.frame(RestDays = nba.games$HomeRest), data.frame(RestDays = nba.games$AwayRest))
restCounts.freq <- table(restCounts$RestDays)
restCounts.disp <- matrix(ncol = length(restCounts.freq), nrow = 4)
restCounts.disp[1,] <- as.integer(names(restCounts.freq))
restCounts.disp[2,] <- as.integer(restCounts.freq)
restCounts.disp[3,] <- restCounts.freq / nrow(restCounts)
for (val in seq(from = 1, to = ncol(restCounts.disp), by = 1)) {
	restCounts.disp[4, val] <- sum(restCounts.disp[3, (restCounts.disp[1,] <= restCounts.disp[1, val])])
}
restCounts.disp[3,] <- round(restCounts.disp[3,], digits = 2)
restCounts.disp[4,] <- round(restCounts.disp[4,], digits = 2)
restCounts.disp <- as.data.frame(restCounts.disp)
rownames(restCounts.disp) <- c('RestDays', 'Freq', 'Density', 'Cum Density')
colnames(restCounts.disp) <- restCounts.disp["RestDays",]
restCounts.disp <- restCounts.disp[c('Freq', 'Density', 'Cum Density'),]
restCounts.disp['Freq',] <- as.character(as.integer(restCounts.disp['Freq',]))

restDaysMax <- 5
nba.games$HomeRest <- ifelse(nba.games$HomeRest > restDaysMax, restDaysMax, nba.games$HomeRest)
nba.games$AwayRest <- ifelse(nba.games$AwayRest > restDaysMax, restDaysMax, nba.games$AwayRest)
#nba.games$HomeRest <- factor(ifelse(nba.games$HomeRest > restDaysMax, restDaysMax, nba.games$HomeRest), labels = seq(from = 0, to = restDaysMax, by = 1))
#nba.games$AwayRest <- factor(ifelse(nba.games$AwayRest > restDaysMax, restDaysMax, nba.games$AwayRest), labels = seq(from = 0, to = restDaysMax, by = 1))

kable(restCounts.disp)

corrplot(scheduleCor, tl.col = 'black', number.font = 2, method = 'number', order = 'AOE', tl.cex = 0.6, number.cex = corrPlotCexSize / (ncol(corrVars) * 0.7), cl.pos = 'b', cl.cex = 0.4)

nba.tTest.points <- t.test(nba.games$HomeScore, nba.games$AwayScore, paired = TRUE)
nba.tTest.points.ciDisp <- paste('(', round(nba.tTest.points$conf.int[1], digits = 2), ',', round(nba.tTest.points$conf.int[2], digits = 2), ']', sep = '')
nba.tTest.points.sum <- data.frame('t-value' = round(c(nba.tTest.points$statistic), digits = 2)
						, 'df' = round(c(nba.tTest.points$parameter), digits = 0)
						, 'p-value' = format.pval(c(nba.tTest.points$p.value), digits = pValDigits)
						, 'CI' = c(nba.tTest.points.ciDisp)
						, 'Mean Est' = round(c(nba.tTest.points$estimate[1]), digits = 4)
					)
rownames(nba.tTest.points.sum) <- 't-Test'
kable(nba.tTest.points.sum, caption = 'Paired Two-Sample t-Test for Home Ice Advantage')

nba.arenaDist <- read.csv('NbaArenaDistance.csv')
colnames(nba.arenaDist) <- c('Stadium1', 'Stadium2', 'Distance')
nba.arenaDist <- nba.arenaDist[nba.arenaDist$Stadium1 != nba.arenaDist$Stadium2,]
nba.arenaDist <- nba.arenaDist[as.character(nba.arenaDist$Stadium1) < as.character(nba.arenaDist$Stadium2),]

nba.arenaDist.summary <- data.frame('Min' = min(nba.arenaDist$Distance), 'Q1' = quantile(nba.arenaDist$Distance, 0.25), 'Med' = median(nba.arenaDist$Distance), 'Mean' = round(mean(nba.arenaDist$Distance), digits = 2), 'Q3' = quantile(nba.arenaDist$Distance, 0.75), 'Max' = max(nba.arenaDist$Distance))
rownames(nba.arenaDist.summary) <- c('Distance')
kable(nba.arenaDist.summary, caption = 'Summary Statistics for Arena-to-Arena Distance')

nba.arenaDist <- nba.arenaDist[order(nba.arenaDist$Distance),]
nba.arenaDist.botDist <- nba.arenaDist[seq(from = 1, to = 7, by = 1),]
nba.arenaDist.botDist <- data.frame('Stadium1' = nba.arenaDist.botDist$Stadium1, 'Stadium2' = nba.arenaDist.botDist$Stadium2, 'Distance' = nba.arenaDist.botDist$Distance)
kable(nba.arenaDist.botDist, caption = paste('Bottom 7 Distances Between 2016 Home Arenas in Miles'))
nba.arenaDist <- nba.arenaDist[order(-nba.arenaDist$Distance),]
nba.arenaDist.topDist <- nba.arenaDist[seq(from = 1, to = 7, by = 1),]
nba.arenaDist.topDist <- data.frame('Stadium1' = nba.arenaDist.topDist$Stadium1, 'Stadium2' = nba.arenaDist.topDist$Stadium2, 'Distance' = nba.arenaDist.topDist$Distance)
kable(nba.arenaDist.topDist, caption = paste('Top 7 Distances Between 2016 Home Arenas in Miles'))

set.seed(010257)
regRound <- 4

subsetInd <- sample(nrow(nba.games), nrow(nba.games) * 0.7)
nba.games.train <- nba.games[subsetInd,]
nba.games.test <- nba.games[-subsetInd,]

binWidth <- 5
nba.score.home.plot <- ggplot(data = nba.games, aes(nba.games$HomeScore)) +
	geom_histogram(aes(y = ..density..), binwidth = binWidth, col = 'black', fill = 'white') +
	xlab('Home Score') +
	ggtitle('Histogram of Home Score') +
	geom_density(col = 2, bw = binWidth)

nba.score.away.plot <- ggplot(data = nba.games, aes(nba.games$AwayScore)) +
	geom_histogram(aes(y = ..density..), binwidth = binWidth, col = 'black', fill = 'white') +
	xlab('Away Score') +
	ggtitle('Histogram of Away Score') +
	geom_density(col = 2, bw = binWidth)
grid.arrange(nba.score.home.plot, nba.score.away.plot, ncol = 2)

nba.score.total.plot <- ggplot(data = nba.games, aes(nba.games$TotalScore)) +
	geom_histogram(aes(y = ..density..), binwidth = binWidth, col = 'black', fill = 'white') +
	xlab('Total Score') +
	ggtitle('Histogram of Total Score') +
	geom_density(col = 2, bw = binWidth)

nba.score.margin.plot <- ggplot(data = nba.games, aes(nba.games$HomeMargin)) +
	geom_histogram(aes(y = ..density..), binwidth = binWidth, col = 'black', fill = 'white') +
	xlab('Home Scoring Margin') +
	ggtitle('Histogram of Home Scoring Margin') +
	geom_density(col = 2, bw = binWidth)
grid.arrange(nba.score.total.plot, nba.score.margin.plot, ncol = 2)

nba.score.home.model <- step(lm('HomeScore ~ 1', data = nba.games.train), scope = list(upper = lm(as.formula('HomeScore ~ PrevHomeScore + PrevOppAwayScore + HomeRest + AwayRest + AwayMilesAway + HomeMilesTraveled + AwayMilesTraveled + HomeGameNum + Attendance'), data = nba.games.train)), direction = 'both', k = stepEntryVal)
summary(nba.score.home.model)
nba.score.away.model <- step(lm('AwayScore ~ 1', data = nba.games.train), scope = list(upper = lm(as.formula('AwayScore ~ PrevAwayScore + PrevOppHomeScore + HomeRest + AwayRest + AwayMilesAway + HomeMilesTraveled + AwayMilesTraveled + HomeGameNum + Attendance'), data = nba.games.train)), direction = 'both', k = stepEntryVal)
summary(nba.score.away.model)
