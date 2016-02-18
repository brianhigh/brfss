# BRFSS SQL Examples
Brian High  
2/18/2016  

## SQL Examples

This is a demo of some basic SQL `SELECT` queries using BRFSS data 
from: http://www.cdc.gov/brfss/. 

Only one table is used, so we will not need and "JOIN" statements. 

The CDC has provided a 
[codebook](http://www.cdc.gov/brfss/annual_data/2013/pdf/codebook13_llcp.pdf) 
for use in understanding variables and codes.

## Connect to MySQL Database

We will connect to the `localhost` and `brfss` database using an `anonymous` 
account.


```r
library(RMySQL)
```

```
## Loading required package: DBI
```

```r
con <- dbConnect(MySQL(), 
                 host="localhost", 
                 username="anonymous", 
                 password="Ank7greph-", 
                 dbname="brfss")
```

## Count Smokers by Education Level

The `USENOW3` variable stores a value indicating if the survey respondent is
currently a smoker or not. A value of `1` (Every day) or `2` (Some days) means 
"is a smoker". We will restrict the year (`IYEAR`) to `2013` and the 
state (`X_STATE`) to `53`, which is "Washington". The education level 
(`_IMPEDUC`), an integer from 1-6, is stored in the database as `X_IMPEDUC`.


```r
sql <- "SELECT X_IMPEDUC AS Education, 
               count(USENOW3) AS Smokers 
        FROM brfss 
        WHERE IYEAR = 2013
              AND X_STATE = 53 
              AND (USENOW3 = 1 OR USENOW3 = 2) 
        GROUP BY X_IMPEDUC 
        ORDER BY X_IMPEDUC DESC;"

rs <- dbGetQuery(con, sql)
rs
```

```
##   Education Smokers
## 1         6      62
## 2         5      85
## 3         4     114
## 4         3      17
## 5         2       5
```

## Relabel Education Level

We will relabel the codes for education level to have meaningful labels. We will
abbreviate the "Value Label" text descriptions from the codebook as follows.


```r
edu.labels <- c("none", "elementary", "some high school", "high school grad", 
                "some college", "college grad")
rs$Education <- factor(rs$Education, levels=1:6, labels=edu.labels)
rs
```

```
##          Education Smokers
## 1     college grad      62
## 2     some college      85
## 3 high school grad     114
## 4 some high school      17
## 5       elementary       5
```

## Histogram of Smokers by Education Level


```r
library(ggplot2)

ggplot(data=rs, aes(x=Education, y=Smokers, fill=Education)) +
    geom_bar(stat="identity")
```

![](sql_examples_files/figure-html/unnamed-chunk-4-1.png)\

## Count Drinkers by Education Level

The `DRNKANY5` variable stores a value indicating if the survey respondent has 
consumed an alcoholic drink in the past 30 days. We will use this value to 
indicate if the survey respondent is currently a drinker or not. A value of
`1` means "is a drinker". Again, we will just look at Washington state in 2013.


```r
sql <- "SELECT X_IMPEDUC AS Education, 
               count(DRNKANY5) AS Drinkers 
        FROM brfss 
        WHERE IYEAR = 2013
              AND X_STATE = 53 
              AND DRNKANY5 = 1 
        GROUP BY X_IMPEDUC 
        ORDER BY X_IMPEDUC DESC;"

rs <- dbGetQuery(con, sql)
rs$Education <- factor(rs$Education, levels=1:6, labels=edu.labels)
rs
```

```
##          Education Drinkers
## 1     college grad     3093
## 2     some college     1887
## 3 high school grad     1244
## 4 some high school      138
## 5       elementary       55
## 6             none        3
```

## Histogram of Drinkers by Education Level


```r
ggplot(data=rs, aes(x=Education, y=Drinkers, fill=Education)) +
    geom_bar(stat="identity")
```

![](sql_examples_files/figure-html/unnamed-chunk-6-1.png)\

## Smokers by Year

We can get a count of all smokers by year to look for annual trends.


```r
sql <- "SELECT IYEAR as Year, 
               count(USENOW3) AS Smokers 
        FROM brfss 
        WHERE IYEAR <= 2014 
              AND X_STATE = 53 
              AND (USENOW3 = 1 OR USENOW3 = 2) 
        GROUP BY IYEAR 
        ORDER BY IYEAR;"


rs <- dbGetQuery(con, sql)
rs$Year <- factor(rs$Year)
smokers <- rs
smokers
```

```
##   Year Smokers
## 1 2012     388
## 2 2013     283
## 3 2014     233
```

## Drinkers by Year

The trend for drinkers is similar, though there are many more drinkers.


```r
sql <- "SELECT IYEAR as Year, 
               count(DRNKANY5) AS Drinkers 
        FROM brfss 
        WHERE IYEAR <= 2014
              AND X_STATE = 53 
              AND DRNKANY5 = 1 
        GROUP BY IYEAR 
        ORDER BY IYEAR;"

rs <- dbGetQuery(con, sql)
rs$Year <- factor(rs$Year)
drinkers <- rs
drinkers
```

```
##   Year Drinkers
## 1 2012     8976
## 2 2013     6420
## 3 2014     5819
```

## Line Plot of Smokers and Drinkers by Year

We can compare smokers and drinkers with a line plot.


```r
consumers <- merge(smokers, drinkers, "Year")

library(tidyr)
consumers <- gather(consumers, key=Type, value=Count, -Year)
consumers
```

```
##   Year     Type Count
## 1 2012  Smokers   388
## 2 2013  Smokers   283
## 3 2014  Smokers   233
## 4 2012 Drinkers  8976
## 5 2013 Drinkers  6420
## 6 2014 Drinkers  5819
```

```r
ggplot(data=consumers, aes(x=Year, y=Count, group=Type, color=Type)) +
    geom_line()
```

![](sql_examples_files/figure-html/unnamed-chunk-9-1.png)\

## Close Database Connection

Since we are done with the database, we can close the connect to it.


```r
# Close connection
dbDisconnect(con)
```

```
## [1] TRUE
```
