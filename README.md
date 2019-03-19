# NbaHomeCourtAdvantage
This project looks at the impact of scheduling on results in the NBA. This is done through the lens of home court advantage and the factors that are directly related, such as rest days and distance travelled. The running average is included for the given statistic, such as team/opp score or team/opp fouls, are also included to provide a baseline for that statistic.

## Project Context - Academic
This project was created to satisfy the capstone requirement for the MS in Business Analytics program at the University of Cincinnati. The final report was submitted on 30 November 2017 and accepted on 01 December 2017. The MS was conferred on 2018 April 26 in conjunction with an MBA.

## Project Context - Professional
The research was intended to be used in the creation of a Monte Carlo simulation engine for Fox Sports. Public release of this work was authorized given the academic objectives for the report.

## Things I Would Do Differently - 2019 March 18
* Investigate rest days as a categorical variable
* Add variables for both total trip length and current progression into the current trip for the away team
  + This would be for number of days, number of games, and distance traveled.
* Introduce a new section that introduces new models for postseason games.
* Focus on using the _tidyverse_
  + _tidyverse_ is a collection of libraries with a common approach to common data science functions. This common approach and the surrounding community allow for improved support and debugging
  + Use _dplyr_ instead of _plyr_
  + Use _tidyr_ instead of _reshape_
  + _ggplot2_ is already part of _tidyverse_
