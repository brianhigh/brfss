---
title: "Smoking and Drinking"
author: "Brian High"
date: "![CC BY-SA 4.0](cc_by-sa_4.png)"
output: 
  ioslides_presentation:
    fig_caption: yes
    fig_retina: 1
    fig_width: 7
    fig_height: 4
    keep_md: yes
    smaller: yes
fig_width: 8.5
fig_height: 3.5
keep_md: yes
smaller: yes
logo: logo_128.png
editor_options: 
  chunk_output_type: console
---

## SQL Examples: Smoking and Drinking

This is a demo of some basic SQL `SELECT` queries using BRFSS data from: 
http://www.cdc.gov/brfss/. We will also demonstrate use of `dbplyr` to perform 
queries for us, without our having to code the SQL statements ourselves.

We have downloaded the data for each respondent for the years 2012 through 2021. This dataset has 4,506,254 rows and 840 columns when [combined into a dataframe](get-brfss-data.md).

This dataset will be too large to fit in memory for most desktop and laptop 
computers. When this entire dataset is loaded into memory as an R dataframe, it consumes almost 30 GB of RAM. As of 2023, most workstations have only 16 GB of RAM or less.

Instead, we have [exported](download_brfss_into_duckdb.R) the data into a DuckDB database file. This allows access to just the data we need without loading all of it into memory at once. We have also limited the number of variables to only those present (359) in the first year's (2012) dataset. For 2021, we will create a separate table with all of the 
variables from that year, so we can look at some of the newer variables.

The CDC has provided a 
[codebook](https://www.cdc.gov/brfss/annual_data/2021/pdf/codebook21_llcp-v2-508.pdf) 
for use in understanding variables and codes. In particular, we will focus on tobacco, 
marijuana, and alcohol use in the United States and the Pacific Nortwest (PNW) 
states (Alask, Idaho, Montana, Oregon, and Washington).

## Setup

Load the required R packages, installing as needed.


```r
if(!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(knitr, dplyr, ggplot2, tidyr, stringr, ggh4x, duckdb, readr, httr)
```

Set `knitr` rendering options, the number of digits to display, and a palette.


```r
opts_chunk$set(tidy=FALSE, cache=FALSE, fig.height=3.5)
options(digits=4)
cbPalette <- c("#CC79A7", "#D55E00", "#999999", "#0072B2", "#009E73", "#E69F00")
```

Connect to the DuckDB database file.


```r
ddb_fn <- file.path("data", "brfss_data.duckdb")
con <- duckdb::dbConnect(duckdb(), ddb_fn)
```

## Table Size

Print the number of rows and columns, as well as number of indexes.


```r
sql <- "SELECT COUNT(*) AS rows FROM brfss;"
rs <- dbGetQuery(con, sql)
cat(rs$rows, "row(s)")
```

```
## 4506254 row(s)
```

```r
sql <- "SELECT * FROM brfss LIMIT 1;"
rs <- dbGetQuery(con, sql)
cat(ncol(rs), "column(s)")
```

```
## 359 column(s)
```

```r
sql <- "select * from duckdb_indexes;"
rs <- dbGetQuery(con, sql)
cat(nrow(rs), "index(es)")
```

```
## 1 index(es)
```

## Count Respondents by Year

Let's count (`COUNT`) the number of respondents per year (`GROUP BY`), sorting 
by year (`ORDER BY`).


```r
sql <- "SELECT IYEAR AS Year, COUNT(*) AS Respondents 
        FROM brfss 
        GROUP BY IYEAR 
        ORDER BY IYEAR;"
dbGetQuery(con, sql)
```

```
##    Year Respondents
## 1  2012      472103
## 2  2013      489678
## 3  2014      465523
## 4  2015      435361
## 5  2016      483233
## 6  2017      452322
## 7  2018      430153
## 8  2019      418580
## 9  2020      408476
## 10 2021      427317
## 11 2022       23508
```

## Respondents per Education Level

Look at the number of respondents in 2021 and aggregate by education level.


```r
sql <- "SELECT _EDUCAG AS Education, COUNT(*) AS Respondents 
        FROM brfss 
        WHERE IYEAR = 2021 
        GROUP BY _EDUCAG 
        ORDER BY _EDUCAG;"
dbGetQuery(con, sql)
```

```
##   Education Respondents
## 1         1       25477
## 2         2      108779
## 3         3      117271
## 4         4      173407
## 5         9        2383
```

The education level (`_EDUCAG`) is an integer from 1-4 (or 9 meaning 
"Don't know", "Missing", etc.). Do we see a trend? Is our sample skewed?

## Count Smokers by Education Level

Use the `SMOKDAY2` variable to see if the survey respondent is
a "smoker" or not. A value of `1` (Every day) or `2` (Some days) means 
"is a smoker".


```r
sql <- "SELECT _EDUCAG AS Education, 
COUNT(SMOKDAY2) AS Smokers 
FROM brfss 
WHERE IYEAR = 2021 AND _EDUCAG <= 4 
AND (SMOKDAY2 IN (1, 2)) 
GROUP BY _EDUCAG 
ORDER BY _EDUCAG;"
dbGetQuery(con, sql)
```

```
##   Education Smokers
## 1         1    6175
## 2         2   19597
## 3         3   16807
## 4         4    9771
```

The number of respondents varies by education level, so we will 
calculate "prevalence" as a fraction of respondents per education level.

## Count Smokers by Education Level

We can get a count of smokers and total respondents per education level in one 
query by using the `IF()` function within the `COUNT()` function.


```r
sql <- "SELECT _EDUCAG AS Education, 
COUNT(*) AS Respondents, 
COUNT(IF(SMOKDAY2 IN (1, 2), 1, NULL)) AS Smokers 
FROM brfss 
WHERE IYEAR = 2021 AND _EDUCAG <= 4 
GROUP BY _EDUCAG 
ORDER BY _EDUCAG;"
rs <- dbGetQuery(con, sql)
rs
```

```
##   Education Respondents Smokers
## 1         1       25477    6175
## 2         2      108779   19597
## 3         3      117271   16807
## 4         4      173407    9771
```

The `IF()` condition `SMOKDAY2 IN (1, 2)` was taken from the `WHERE` 
clause. We had to make this change so that `COUNT(*)` counts all respondents.

## Smoking Prevalence by Education Level

We use functions from the `dplyr` package to calculate smoking prevalence. This
is the number of smokers as a fraction of respondents for each education level.


```r
smokers <- rs %>% group_by(Education) %>% 
  mutate(`Smoking Prevalence` = Smokers/Respondents)
smokers
```

```
## # A tibble: 4 × 4
## # Groups:   Education [4]
##   Education Respondents Smokers `Smoking Prevalence`
##       <dbl>       <dbl>   <dbl>                <dbl>
## 1         1       25477    6175               0.242 
## 2         2      108779   19597               0.180 
## 3         3      117271   16807               0.143 
## 4         4      173407    9771               0.0563
```

## Relabel Education Level

Now, we relabel the codes for education level to meaningful text strings. We 
abbreviate the "Value Label" text descriptions from the codebook as follows.


```r
edu.labels <- c("some school", "high school grad", "some college", "college grad")
smokers$Education <- factor(smokers$Education, levels = 1:4, labels = edu.labels)
smokers
```

```
## # A tibble: 4 × 4
## # Groups:   Education [4]
##   Education        Respondents Smokers `Smoking Prevalence`
##   <fct>                  <dbl>   <dbl>                <dbl>
## 1 some school            25477    6175               0.242 
## 2 high school grad      108779   19597               0.180 
## 3 some college          117271   16807               0.143 
## 4 college grad          173407    9771               0.0563
```

## Smoking Prevalence by Education Level


```r
ggplot(smokers, aes(x = Education, y = `Smoking Prevalence`, fill = Education)) +
  geom_bar(stat = "identity")
```

![](sql_examples_files/figure-html/unnamed-chunk-10-1.png)<!-- -->

## Count Smokers by Education and Year

Let's compare smoking by year from 2012 to 2021. We will modify our prevalence 
calculation to exclude the "Don't Know/Refused/Missing" responses from the denominator.


```r
sql <- "SELECT IYEAR AS Year, _EDUCAG AS Education, 
COUNT(IF(SMOKDAY2 IN (1, 2), 1, NULL)) AS Smokers, 
COUNT(IF(SMOKDAY2 = 3, 1, NULL)) AS NonSmokers 
FROM brfss 
WHERE (IYEAR BETWEEN 2012 AND 2021)
AND _EDUCAG <= 4 
GROUP BY IYEAR, _EDUCAG 
ORDER BY IYEAR, _EDUCAG;"

rs <- dbGetQuery(con, sql)
smokers <- rs %>% group_by(Year, Education) %>% 
    mutate(`Smoking Prevalence` = Smokers/sum(Smokers, NonSmokers, na.rm = TRUE),
           Education = factor(Education, levels = 1:4, labels = edu.labels),
           Year = factor(Year))
```

## Smoking by Education and Year


```r
ggplot(smokers, aes(x = Year, y = `Smoking Prevalence`, 
                    color = Education, group = Education)) + geom_line()
```

![](sql_examples_files/figure-html/unnamed-chunk-12-1.png)<!-- -->

## Smokers, Chewers, and Snuffers

`SMOKDAY2` represents smoking and `USENOW3` represents "chewing" or "snuffing".


```r
sql <- "SELECT IYEAR AS Year, _EDUCAG AS Education, 
COUNT(*) AS Respondents, 
COUNT(IF(SMOKDAY2 IN (1, 2), 1, NULL)) AS Smokers,
COUNT(IF(USENOW3 = 1 OR USENOW3 = 2, 1, NULL)) AS Chewers
FROM brfss 
WHERE (IYEAR BETWEEN 2012 AND 2021)
AND _EDUCAG <= 4 
GROUP BY IYEAR, _EDUCAG 
ORDER BY IYEAR, _EDUCAG;"

rs <- dbGetQuery(con, sql)
tobacco_use <- rs %>% group_by(Year, Education) %>% 
  mutate(Smokers = Smokers/Respondents, 
         `Chewers and Snuffers` = Chewers/Respondents) %>%
  mutate(Education = factor(Education, levels = 1:4, labels = edu.labels),
         Year = factor(Year)) %>% 
  select(-Respondents, -Chewers) %>%
  pivot_longer(c(-Year, -Education), names_to = "Type", values_to = "Prevalence")
```

## Smokers, Chewers, and Snuffers


```r
ggplot(tobacco_use, aes(x = Year, y = Prevalence, 
                        color = Education, group = Education)) + geom_line() + 
  ggh4x::facet_grid2(. ~ Type, scales = "free_y", independent = "y") + 
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1))
```

![](sql_examples_files/figure-html/unnamed-chunk-14-1.png)<!-- -->

## 2021 Smoking & Vaping by Age & Sex

We will compare the proportion of smokers (`SMOKDAY2`) and e-cigarette (`ECIGNOW1`) 
or other electronic vaping product users ("vapers"), and those who are both, by 
age group (`_AGE_G`) and birth sex (`BIRTHSEX`) for 2021. 

Since `ECIGNOW1` is not available for previous years, and is not present in our
database's "brfss" table, we will use a different table (`brfss2021`) that was 
made by importing just the 2021 dataset from the BRFSS website.


```r
sql <- 'SELECT _AGE_G AS "Age Group", BIRTHSEX AS Gender, 
COUNT(*) AS Respondents, 
COUNT(IF(SMOKDAY2 IN (1, 2), 1, NULL)) AS Smokers,
COUNT(IF(ECIGNOW1 IN (1, 2), 1, NULL)) AS Vapers, 
COUNT(IF((SMOKDAY2 IN (1, 2)) OR (ECIGNOW1 IN (1, 2)), 1, NULL)) AS SmokeOrVapers,
COUNT(IF((SMOKDAY2 IN (1, 2)) AND (ECIGNOW1 IN (1, 2)), 1, NULL)) AS SmokeAndVapers, 
FROM brfss2021 WHERE IYEAR = 2021 AND (Gender IN (1, 2)) 
GROUP BY _AGE_G, BIRTHSEX ORDER BY _AGE_G, BIRTHSEX;'

rs <- dbGetQuery(con, sql)
```

## 2021 Smoking & Vaping by Age & Sex

Variables `_AGE_G` and `BIRTHSEX` are categorical, so apply labels with `factor()`. 

Reshape using `pivot_longer()` to store `Smoke`, `Vape`,and `Smoke and Vape` in `Factor` 
with values in `Prevalance`. This allows plotting by Factor in different colors.


```r
age.labels <- c('18-24', '25-34', '35-44', '45-54', '55-64', '65+')

consumers <- rs %>% group_by(`Age Group`, Gender) %>%
  mutate(`Smoke` = Smokers/Respondents,
         `Vape` = Vapers/Respondents,
         `Smoke or Vape` = SmokeOrVapers/Respondents,
         `Smoke and Vape` = SmokeAndVapers/Respondents,
         `Age Group` = factor(`Age Group`, levels = 1:6, labels = age.labels)) %>%
    pivot_longer(c(`Smoke`, `Vape`, `Smoke or Vape`, `Smoke and Vape`), 
                 names_to = "Factor", values_to = "Prevalence") %>%
  mutate(Gender = factor(Gender, levels = 2:1, labels = c("Female", "Male")))
```

## 2021 Smoking & Vaping by Age & Sex


```r
ggplot(consumers, aes(x = `Age Group`, y = `Prevalence`, 
                    color = Factor, group = Factor)) + 
  geom_line() + scale_color_manual(values = cbPalette) + facet_wrap(. ~ Gender) +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1))
```

![](sql_examples_files/figure-html/unnamed-chunk-17-1.png)<!-- -->

## 2021 Marijuana Use by Age & Sex

We will use a line plot to compare the proportion of marijuana users by usage type 
(`RSNMRJN2`) by age group (`_AGE_G`) and birth sex (`BIRTHSEX`) for 2021.


```r
sql <- 'SELECT _AGE_G AS "Age Group", BIRTHSEX AS Gender, RSNMRJN2, MARIJAN1
FROM brfss2021 WHERE IYEAR = 2021 AND (Gender IN (1, 2));'

rs <- dbGetQuery(con, sql)
```

This time, we will count respondents and marijuana users in R. Although that 
means reading more data into memory, at allows us to more easily handle the 
mix of counts (for prevalence) and averages (days of use) that we will need.


```r
respondents <- rs %>% group_by(`Age Group`, Gender) %>% 
  summarise(Respondents = n(), .groups = "drop")

mj.use.counts <- rs %>% filter(RSNMRJN2 %in% 1:3) %>% 
  group_by(`Age Group`, Gender, RSNMRJN2) %>% 
  summarise(Users = n(), .groups = "drop")
```

## 2021 Marijuana Use by Age & Sex

Now we merge in the respondent and user counts with the mean monthly usage values.


```r
consumers <- rs %>% 
  filter(RSNMRJN2 %in% 1:3, MARIJAN1 >= 1 & MARIJAN1 <= 30) %>%
  group_by(`Age Group`, Gender, RSNMRJN2) %>% 
  summarise(MARIJAN1 = mean(MARIJAN1, na.rm = TRUE), .groups = "drop") %>% 
  left_join(respondents, by = c('Age Group', 'Gender')) %>%
  left_join(mj.use.counts, by = c('Age Group', 'Gender', 'RSNMRJN2'))
```

Variables `_AGE_G`, `BIRTHSEX`, and `RSNMRJN2` are categorical, so apply labels 
with `factor()`.


```r
mj.use.labels <- c('Medical', 'Non-medical', 'Both Medical and \nNon-medical')

consumers <- consumers %>% 
  mutate(Prevalence = Users/Respondents,
         RSNMRJN2 = factor(RSNMRJN2, levels = 1:3, labels = mj.use.labels),
         `Age Group` = factor(`Age Group`, levels = 1:6, labels = age.labels),
         Gender = factor(Gender, levels = 2:1, labels = c("Female", "Male"))) %>% 
  rename("Use Type" = RSNMRJN2, "DaysPerMonth" = MARIJAN1)
```

## 2021 Marijuana Use by Age & Sex

We will plot Prevalence by Age Group as we have done earlier, and color by Use Type, 
but this time we will make the size of the points/circles relative to the mean 
monthly use per group/type. Since the points become jumbled together with 
increasing age, we will also add lines with the points, using the same group 
colors. We will reduce the opacity (`alpha`) because the lines and points cross 
and overlap.


```r
p <- ggplot(consumers, aes(x = `Age Group`, y = `Prevalence`, 
                      color = `Use Type`, group = `Use Type`)) + 
  geom_line(alpha = 0.7, show.legend = FALSE) + 
  geom_point(aes(size = DaysPerMonth), alpha = 0.5) + 
  guides(color = guide_legend(title = "Use Type", override.aes = list(size = 3)),
         size = guide_legend(title = "Average Days Used \nper Month (30 days)")) + 
  scale_color_manual(values = cbPalette) + facet_wrap(. ~ Gender) + 
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1))
```

## 2021 Marijuana Use by Age & Sex

![](sql_examples_files/figure-html/unnamed-chunk-23-1.png)<!-- -->

## Count Drinkers by Education Level

The `DRNKANY5` variable stores a value indicating if the survey respondent has 
consumed an alcoholic drink in the past 30 days. We will use this value to 
indicate if the survey respondent is currently a "drinker" or not. A value of
`1` means "is a drinker". Again, we will just look at 2021.


```r
sql <- "SELECT _EDUCAG AS Education, 
COUNT(*) AS Respondents, 
COUNT(IF(DRNKANY5 = 1, 1, NULL)) AS Drinkers 
FROM brfss 
WHERE IYEAR = 2021
AND _EDUCAG <= 4 
GROUP BY _EDUCAG 
ORDER BY _EDUCAG;"

rs <- dbGetQuery(con, sql)
```

## Drinking Prevalence by Education Level

Again, using `dplyr`, we can calculate drinking prevalence.


```r
drinkers <- rs %>% group_by(Education) %>% 
  mutate(`Drinking Prevalence` = Drinkers/Respondents,
         Education = factor(Education, levels = 1:4, labels = edu.labels))
drinkers
```

```
## # A tibble: 4 × 4
## # Groups:   Education [4]
##   Education        Respondents Drinkers `Drinking Prevalence`
##   <fct>                  <dbl>    <dbl>                 <dbl>
## 1 some school            25477     7044                 0.276
## 2 high school grad      108779    41838                 0.385
## 3 some college          117271    55338                 0.472
## 4 college grad          173407   100642                 0.580
```

## Drinking Prevalence by Education Level


```r
ggplot(drinkers, aes(x = Education, y = `Drinking Prevalence`, fill = Education)) +
  geom_bar(stat = "identity")
```

![](sql_examples_files/figure-html/unnamed-chunk-26-1.png)<!-- -->

## Count Drinkers by Education and Year

Let's see how drinking compares from 2012 to 2021. We will also
modify our prevalence calculation to exclude the "Don't Know/Refused/Missing" 
responses from the denominator.


```r
sql <- "SELECT IYEAR AS Year, _EDUCAG AS Education, 
COUNT(IF(DRNKANY5 = 1, 1, NULL)) AS Drinkers, 
COUNT(IF(DRNKANY5 = 2, 1, NULL)) AS NonDrinkers 
FROM brfss 
WHERE (IYEAR BETWEEN 2012 AND 2021)
AND _EDUCAG <= 4 
GROUP BY IYEAR, _EDUCAG 
ORDER BY IYEAR, _EDUCAG;"

rs <- dbGetQuery(con, sql)
drinkers <- rs %>% group_by(Year, Education) %>% 
    mutate(`Drinking Prevalence` = 
           Drinkers/sum(Drinkers, NonDrinkers, na.rm = TRUE),
           Education = factor(Education, levels = 1:4, labels = edu.labels))
```

## Drinking by Education and Year


```r
ggplot(drinkers, aes(x = Year, y = `Drinking Prevalence`, 
                     color = Education, group = Education)) + geom_line()
```

![](sql_examples_files/figure-html/unnamed-chunk-28-1.png)<!-- -->

## Drinkers and Binge Drinkers

Let's compare drinkers (`DRNKANY5 = 1`) and binge drinkers (`_RFBING5 = 2`) 
for 2012-2021. Binge drinkers are defined as males having five or more drinks 
on one occasion and females having four or more drinks on one occasion.


```r
sql <- "SELECT IYEAR AS Year, _EDUCAG AS Education, 
COUNT(*) AS Respondents, 
COUNT(IF(DRNKANY5 = 1, 1, NULL)) AS Drinkers, 
COUNT(IF(DRNKANY5 = 2, 1, NULL)) AS NonDrinkers, 
COUNT(IF(_RFBING5 = 2, 1, NULL)) AS BingeDrinkers, 
COUNT(IF(_RFBING5 = 1, 1, NULL)) AS NonBingeDrinkers 
FROM brfss 
WHERE (IYEAR BETWEEN 2012 AND 2021)
AND _EDUCAG <= 4 
GROUP BY IYEAR, _EDUCAG 
ORDER BY IYEAR, _EDUCAG;"
```

## Drinkers and Binge Drinkers

As before, we will exclude the "Don't Know/Refused/Missing" 
responses from the denominator in our our prevalence calculations.


```r
rs <- dbGetQuery(con, sql)
drinkers <- rs %>% group_by(Year, Education) %>% 
  mutate(Drinkers = 
           Drinkers/sum(Drinkers, NonDrinkers, na.rm = TRUE),
         `Binge Drinkers` = 
           BingeDrinkers/sum(BingeDrinkers, NonBingeDrinkers, na.rm = TRUE),
         Education = factor(Education, levels = 1:4, labels = edu.labels)) %>% 
  select(Year, Education, Drinkers, `Binge Drinkers`) %>%
  pivot_longer(c(-Year, -Education), names_to = "Type", values_to = "Prevalence")
```

## Drinkers and Binge Drinkers


```r
ggplot(drinkers, aes(x = Year, y = Prevalence, 
                     color = Education, group = Education)) + geom_line() + 
  ggh4x::facet_grid2(. ~ Type, scales = "free_y", independent = "y") +  
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1))
```

![](sql_examples_files/figure-html/unnamed-chunk-31-1.png)<!-- -->

## Smoking and Drinking Prevalence

Prepare prevalence data as before, but reshape to allow faceting by risk factor.


```r
sql <- "SELECT IYEAR AS Year, _EDUCAG AS Education, 
COUNT(IF(SMOKDAY2 IN (1, 2), 1, NULL)) AS Smokers, 
COUNT(IF(SMOKDAY2 = 3, 1, NULL)) AS NonSmokers,
COUNT(IF(DRNKANY5 = 1, 1, NULL)) AS Drinkers,
COUNT(IF(DRNKANY5 = 2, 1, NULL)) AS NonDrinkers
FROM brfss 
WHERE (IYEAR BETWEEN 2012 AND 2021) AND _EDUCAG <= 4 
GROUP BY IYEAR, _EDUCAG 
ORDER BY IYEAR, _EDUCAG;"

consumers <- dbGetQuery(con, sql) %>% 
  group_by(Year, Education) %>% 
  mutate(Smoking = Smokers/sum(Smokers, NonSmokers, na.rm = TRUE), 
         Drinking = Drinkers/sum(Drinkers, NonDrinkers, na.rm = TRUE),
         Education = factor(Education, levels = 1:4, labels = edu.labels)) %>%
  select(Year, Education, Smoking, Drinking) %>%
  pivot_longer(c(Smoking, Drinking), 
               names_to = "Factor", values_to = "Prevalence")
```

## Smoking and Drinking Prevalence


```r
ggplot(consumers, aes(x = Year, y = Prevalence, group = Factor, color = Factor)) + 
    geom_line() + facet_grid(Factor ~ Education, scales = "free_y") +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) + 
    scale_color_manual(values = cbPalette)
```

![](sql_examples_files/figure-html/unnamed-chunk-33-1.png)<!-- -->

## Alternative to Writing SQL

Wouldn't it be nice to do this in R without having to write SQL too? 

You can use the `dbplyr` package, which will automatically load if `dplyr` 
is loaded, to translate R code to SQL for you. This allows you to use R
code instead if SQL to get your data from the database.


```r
brfss_data <- tbl(con, "brfss")
result <- brfss_data %>% 
  select("Year" = IYEAR, "Education" = `_EDUCAG`, State = `_STATE`, 
         SMOKDAY2, DRNKANY5) %>%
  filter(Year >= 2012, Year <= 2021, Education <= 4)
```

Don't do too much cleanup here, though. Just focus on selecting and filtering
the data to minimize how much to read from the database. Cleanup comes later. 
The reason is that complex `dbplyr` queries can be slow and are more prone to 
error.

## View the SQL Query

While this didn't actually execute the query and return the dataset, it did
create a SQL query that we'll use next.


```r
result %>% show_query()
```

```
## <SQL>
## SELECT
##   IYEAR AS "Year",
##   _EDUCAG AS Education,
##   _STATE AS State,
##   SMOKDAY2,
##   DRNKANY5
## FROM brfss
## WHERE (IYEAR >= 2012.0) AND (IYEAR <= 2021.0) AND (_EDUCAG <= 4.0)
```

## Prepare Data for Plotting

To actually execute the SQL query, we use `collect()`. Then we perform the same steps as we did previously on the SQL query results, but using R instead of a mix of R and SQL.


```r
consumers <- collect(result) %>% 
  mutate(Smoker = ifelse(SMOKDAY2 %in% 1:2, 1, 0)) %>% 
  mutate(NonSmoker = ifelse(SMOKDAY2 == 3, 1, 0)) %>% 
  mutate(Drinker = ifelse(DRNKANY5 == 1, 1, 0)) %>% 
  mutate(NonDrinker = ifelse(DRNKANY5 == 2, 1, 0)) %>% 
  group_by(Year, Education) %>% 
  summarize(
    Smoking = sum(Smoker, na.rm = TRUE)/sum(Smoker, NonSmoker, na.rm = TRUE),
    Drinking = sum(Drinker, na.rm = TRUE)/sum(Drinker, NonDrinker, na.rm = TRUE),
    .groups = "keep") %>% 
  mutate(Education = factor(Education, levels = 1:4, labels = edu.labels)) %>% 
  pivot_longer(c(Smoking, Drinking), 
               names_to = "Factor", values_to = "Prevalence")
```

## Smoking and Drinking Prevalence


```r
# Use the same ggplot() command as before
ggplot(consumers, aes(x = Year, y = Prevalence, group = Factor, color = Factor)) + 
    geom_line() + facet_grid(Factor ~ Education, scales = "free_y") + 
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) + 
    scale_color_manual(values = cbPalette)
```

![](sql_examples_files/figure-html/unnamed-chunk-37-1.png)<!-- -->

## 2021 Drinking Amount by Age & Sex

Using `dbplyr`, compare drinking frequency (`ALCDAY5`) and amount 
(`AVEDRNK3`) by age group and sex at birth (`BIRTHSEX`) in 2021. Exclude 
non-drinkers.


```r
drinkers <- tbl(con, "brfss2021") %>% 
  select("Year" = IYEAR, "Age Group" = `_AGE_G`, DRNKANY5, 
         "Gender" = BIRTHSEX, ALCDAY5, AVEDRNK3) %>%
  filter(Year == 2021, DRNKANY5 == 1, Gender %in% 1:2) %>% collect(result) %>%
  mutate(DaysPerMonth = 
           case_when(ALCDAY5 >= 101 & ALCDAY5 <= 107 ~ (ALCDAY5 - 100) * (30/7),
                     ALCDAY5 >= 201 & ALCDAY5 <= 230 ~ ALCDAY5 - 200,
                     .default = NA)) %>% 
  mutate(DrinksPerDay = 
           case_when(AVEDRNK3 >= 1 & AVEDRNK3 <= 76 ~ AVEDRNK3,
                     .default = NA)) %>% 
  mutate(DrinksPerMonth = DrinksPerDay * DaysPerMonth) %>% 
  group_by(Gender, `Age Group`) %>% 
  summarize(across(c(DrinksPerDay, DrinksPerMonth), ~ mean(.x, na.rm = TRUE)),
            .groups = "drop") %>% 
  mutate(`Age Group` = factor(`Age Group`, levels = 1:6, labels = age.labels),
         Gender = factor(Gender, levels = 2:1, labels = c("Female", "Male")))
```

## 2021 Drinking Amount by Age & Sex


```r
ggplot(drinkers, aes(x = `Age Group`, y = DrinksPerMonth, color = Gender)) + 
  geom_point(aes(size = DrinksPerDay)) + ylab("Drinks per Month (30 days)") + 
  guides(color = guide_legend(title = "Sex at Birth"),
         size = guide_legend(title = "Drinks per \nDrinking Day"))
```

![](sql_examples_files/figure-html/unnamed-chunk-39-1.png)<!-- -->

## 2021 Drinking by Race and Income

Using `dbplyr`, compare drinking frequency (`ALCDAY5`) and amount 
(`AVEDRNK3`) by race (`_IMPRACE`) and income group (`_INCOMG1`) in 2021. Exclude 
non-drinkers.


```r
drinkers <- tbl(con, "brfss2021") %>% 
  select("Year" = IYEAR, "Income Group" = `_INCOMG1`, DRNKANY5, 
         "Race" = `_IMPRACE`, ALCDAY5, AVEDRNK3) %>%
  filter(Year == 2021, DRNKANY5 == 1, `Income Group` <= 7) %>% collect(result) %>%
  mutate(DaysPerMonth = 
           case_when(ALCDAY5 >= 101 & ALCDAY5 <= 107 ~ (ALCDAY5 - 100) * (30/7),
                     ALCDAY5 >= 201 & ALCDAY5 <= 230 ~ ALCDAY5 - 200,
                     .default = NA)) %>% 
  mutate(DrinksPerDay = 
           case_when(AVEDRNK3 >= 1 & AVEDRNK3 <= 76 ~ AVEDRNK3,
                     .default = NA)) %>% 
  mutate(DrinksPerMonth = DrinksPerDay * DaysPerMonth) %>% 
  group_by(Race, `Income Group`) %>% 
  summarize(across(c(DrinksPerDay, DrinksPerMonth), ~ mean(.x, na.rm = TRUE)),
            .groups = "drop") 
```

## 2021 Drinking by Race and Income


```r
income.labels <- c('<$15K', '$15K-$25K', '$25K-$35K', '$35K-$50K', 
                   '$50K-$100K', '$100K-$200K', '$200K+')

race.labels <- 
  c('White, Non-Hispanic', 'Black, Non-Hispanic', 'Asian, Non-Hispanic ', 
    'American Indian/Alaskan Native, Non-Hispanic', 'Hispanic', 
    'Other race, Non-Hispanic')

drinkers <- drinkers %>% 
  mutate(`Income Group` = factor(`Income Group`, levels = 1:7, 
                                 labels = income.labels, ordered = TRUE),
         Race = factor(Race, levels = 1:6, labels = race.labels))

p <- ggplot(drinkers, aes(x = `Income Group`, y = DrinksPerMonth, 
                          color = Race, group = Race)) + 
  geom_line(alpha = 0.5, show.legend = FALSE) + 
  geom_point(aes(size = DrinksPerDay), alpha = 0.5) + 
  ylab("Drinks per Month (30 days)") + 
  guides(color = guide_legend(title = "Race", override.aes = list(size = 3)),
         size = guide_legend(title = "Drinks per \nDrinking Day")) + 
  scale_color_manual(values = cbPalette) + 
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1))
```

## 2021 Drinking by Race and Income

![](sql_examples_files/figure-html/unnamed-chunk-42-1.png)<!-- -->

## Speeding up Queries

If we retrieve all of the data for Washington state (state FIPS code = 53) respondents 
for 2012-2021, we can just use R commands for subsetting and work entirely from memory.


```r
# Get all Washington State data from 2012-2021 from database as a dataframe
brfss_data <- tbl(con, "brfss")
result <- brfss_data %>% 
  filter(IYEAR >= 2012, IYEAR <= 2021, `_STATE` == 53)
brfsswa1221 <- collect(result)
dim(brfsswa1221)
```

```
## [1] 131816    359
```

```r
# Remove 100 columns that contain only NA , zero (0), or the empty string ('')
brfsswa1221 <- brfsswa1221 %>% select_if(~ !(all(is.na(.) | . == 0 | . == "")))
dim(brfsswa1221)
```

```
## [1] 131816    249
```

## Check on Memory, Write to File

We will compare the size of the dataset in memory (RAM) and as a file (RDS).


```r
# Report data table size and dimensions
cat("The data table consumes", object.size(brfsswa1221) / 1024^2, "MB", 
    "with", dim(brfsswa1221)[1], "observations and", 
    dim(brfsswa1221)[2], "variables", "\n")
```

```
## The data table consumes 250.7 MB with 131816 observations and 249 variables
```

```r
# Save as a RDS and check on the size
filename <- file.path("data", "brfsswa1221.rds")
if (! file.exists(filename)) saveRDS(brfsswa1221, filename)
cat(paste(c("Size of RDS file is", 
            round(file.size(filename) / 1024^2, 1), "MB", "\n")))
```

```
## Size of RDS file is 8.5 MB
```

In the future, if we only want to work with Washington State data from 2012-2021, then we can just read from the RDS file instead of using the Duck DB database.

## Reproduce Results without SQL

We can test our subset by reproducing our SQL query with R commands as before.


```r
consumers <- brfsswa1221 %>%
  select("Year" = IYEAR, "Education" = `_EDUCAG`, State = `_STATE`, 
         SMOKDAY2, DRNKANY5) %>%
  filter(Year >= 2012, Year <= 2021, Education <= 4) %>% 
  mutate(Smoker = ifelse(SMOKDAY2 %in% 1:2, 1, 0)) %>% 
  mutate(NonSmoker = ifelse(SMOKDAY2 == 3, 1, 0)) %>% 
  mutate(Drinker = ifelse(DRNKANY5 == 1, 1, 0)) %>% 
  mutate(NonDrinker = ifelse(DRNKANY5 == 2, 1, 0)) %>% 
  group_by(Year, Education) %>% 
  summarize(
    Smoking = sum(Smoker, na.rm = TRUE)/sum(Smoker, NonSmoker, na.rm = TRUE),
    Drinking = sum(Drinker, na.rm = TRUE)/sum(Drinker, NonDrinker, na.rm = TRUE),
    .groups = "keep") %>% 
  mutate(Education = factor(Education, levels = 1:4, labels = edu.labels)) %>% 
  pivot_longer(c(Smoking, Drinking), 
               names_to = "Factor", values_to = "Prevalence")
```

## WA Smoking and Drinking Prevalence


```r
# Use the same ggplot() command as used earlier
ggplot(consumers, aes(x = Year, y = Prevalence, group = Factor, color = Factor)) + 
    geom_line() + facet_grid(Factor ~ Education, scales = "free_y") + 
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) + 
    scale_color_manual(values = cbPalette)
```

![](sql_examples_files/figure-html/unnamed-chunk-46-1.png)<!-- -->

## Compare PNW States: Get FIPS Codes

We can easily compare states if we know the codes used in the BRFSS dataset. The
codes are known as [FIPS codes](https://www.cdc.gov/brfss/annual_data/1996/files/fipscode.txt). We can 
lookup the FIPS code for Pacific Northwest (PNW) states like this:


```r
# Get a table of state FIPS codes and state names
fips_fn <- file.path("data", "fips.csv")
if (! file.exists(fips_fn)) {
  url <- "https://www.cdc.gov/brfss/annual_data/1996/files/fipscode.txt"
  GET(url) %>% content("text", encoding = "UTF-8") %>% 
    str_replace_all('\\r\\n', '\n') %>% 
    read_fwf(skip = 3, n_max = 51, col_types = c("i", "c"), 
                 col_positions = fwf_widths(c(12, NA))) %>%
    rename("state_fips" = X1, "state_name" = X2) %>% 
    mutate(state_name = str_to_title(state_name)) %>%
    mutate(state_name = str_replace(state_name, " Of ", " of ")) %>% 
    write_csv(fips_fn)
}

# Import data and create a vector of PNW state FIPS codes to use for filtering
fips <- read_csv(fips_fn, col_types = c('i', 'c'))
pnw_states <- c("Alaska", "Idaho", "Montana", "Oregon", "Washington")
pnw_state_fips <- fips %>% filter(state_name %in% pnw_states) %>% pull(state_fips)
```

## Compare PNW States: Respondents

To see these FIPS codes used in action, let's count the number of respondents 
per PNW state for the 2012-2021 timespan.


```r
brfss_data <- tbl(con, "brfss")

result <- brfss_data %>% rename(State = `_STATE`, "Year" = IYEAR) %>% 
  filter(State %in% pnw_state_fips, Year >= 2012, Year <= 2021) %>%
  group_by(State) %>% summarize(N = n()) %>% arrange(desc(N))

inner_join(fips, collect(result), by = c('state_fips' = 'State'))
```

```
## # A tibble: 5 × 3
##   state_fips state_name      N
##        <dbl> <chr>       <dbl>
## 1          2 Alaska      37843
## 2         16 Idaho       54889
## 3         30 Montana     67848
## 4         41 Oregon      55492
## 5         53 Washington 131816
```

## Compare PNW States: Prep for Plot


```r
brfss_data <- tbl(con, "brfss")

result <- brfss_data %>% 
  select("Year" = IYEAR, "Education" = `_EDUCAG`, State = `_STATE`, 
         SMOKDAY2, DRNKANY5) %>%
  filter(Year >= 2012, Year <= 2021, Education <= 4, State %in% pnw_state_fips)

consumers <- collect(result) %>% 
  mutate(Smoker = ifelse(SMOKDAY2 %in% 1:2, 1, 0)) %>% 
  mutate(NonSmoker = ifelse(SMOKDAY2 == 3, 1, 0)) %>% 
  mutate(Drinker = ifelse(DRNKANY5 == 1, 1, 0)) %>% 
  mutate(NonDrinker = ifelse(DRNKANY5 == 2, 1, 0)) %>% 
  group_by(Year, State, Education) %>% 
  summarize(
    Smoking = sum(Smoker, na.rm = TRUE)/sum(Smoker, NonSmoker, na.rm = TRUE),
    Drinking = sum(Drinker, na.rm = TRUE)/sum(Drinker, NonDrinker, na.rm = TRUE),
    .groups = "keep") %>% 
  mutate(Education = factor(Education, levels = 1:4, labels = edu.labels)) %>% 
  pivot_longer(c(Smoking, Drinking), 
               names_to = "Factor", values_to = "Prevalence") %>%
  inner_join(fips, by = c('State' = 'state_fips')) %>% 
  mutate(State = state_name) %>% select(-state_name)
```

## PNW Smoking and Drinking Prevalence


```r
# Use the same ggplot() command as before, modified to color by state
ggplot(consumers, aes(x = Year, y = Prevalence, group = State, color = State)) + 
    geom_line() + facet_grid(Factor ~ Education, scales = "free_y") + 
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) + 
    scale_color_manual(values = cbPalette)
```

![](sql_examples_files/figure-html/unnamed-chunk-50-1.png)<!-- -->

## PNW Smoking and Drinking Prevalence

Age group (`_AGE_G`) is a 6-level ordinal variable. Apply labels with `factor()`.


```r
age.labels <- c('18-24', '25-34', '35-44', '45-54', '55-64', '65+')
consumers <- tbl(con, "brfss") %>% 
  select("Year" = IYEAR, "Age Group" = `_AGE_G`, State = `_STATE`, 
         SMOKDAY2, DRNKANY5) %>%
  filter(Year >= 2012, Year <= 2021, State %in% pnw_state_fips) %>% 
  collect() %>% 
  mutate(Smoker = ifelse(SMOKDAY2 %in% 1:2, 1, 0)) %>% 
  mutate(NonSmoker = ifelse(SMOKDAY2 == 3, 1, 0)) %>% 
  mutate(Drinker = ifelse(DRNKANY5 == 1, 1, 0)) %>% 
  mutate(NonDrinker = ifelse(DRNKANY5 == 2, 1, 0)) %>% 
  group_by(State, `Age Group`) %>% 
  summarize(
    Smoking = sum(Smoker, na.rm = TRUE)/sum(Smoker, NonSmoker, na.rm = TRUE),
    Drinking = sum(Drinker, na.rm = TRUE)/sum(Drinker, NonDrinker, na.rm = TRUE),
    .groups = "keep") %>% 
  pivot_longer(c(Smoking, Drinking), 
               names_to = "Factor", values_to = "Prevalence") %>%
  inner_join(fips, by = c('State' = 'state_fips')) %>% 
  mutate(State = state_name) %>% select(-state_name) %>%
  mutate(`Age Group` = factor(`Age Group`, levels = 1:6, labels = age.labels))
```

## PNW Smoking and Drinking Prevalence

Plot drinking and smoking prevalence by age group and state for 2012-2021.


```r
ggplot(consumers, 
       aes(x = `Age Group`, y = Prevalence, group = State, color = State)) + 
  geom_line() + facet_grid(. ~ Factor)
```

![](sql_examples_files/figure-html/unnamed-chunk-52-1.png)<!-- -->

## 2021 PNW Marijuana Use

Let's compare marijuana usage by education and state in 2021 for Alaska, Idaho, 
and Montana. (We do not have data on this for Oregon and Washington.)


```r
sql <- 'SELECT IYEAR, _STATE AS State, _EDUCAG AS Education, 
AVG(IF(MARIJAN1 BETWEEN 1 AND 30, MARIJAN1, NULL)) AS DaysPerMonth, 
COUNT(IF(MARIJAN1 BETWEEN 1 AND 30, 1, NULL)) AS Users, 
COUNT(IF(MARIJAN1 = 88, 1, NULL)) AS NonUsers 
FROM brfss2021 
WHERE (IYEAR = 2021) AND _EDUCAG <= 4 
GROUP BY State, IYEAR, _EDUCAG 
ORDER BY State, IYEAR, _EDUCAG;'

rs <- dbGetQuery(con, sql)

users <- rs %>% filter(State %in% pnw_state_fips) %>% 
  inner_join(fips, by = c('State' = 'state_fips')) %>% 
  mutate(State = state_name) %>% select(-state_name) %>%
  drop_na(DaysPerMonth ) %>% group_by(State, Education) %>% 
    mutate(`Prevalence` = Users/sum(Users, NonUsers, na.rm = TRUE),
           Education = factor(Education, levels = 1:4, labels = edu.labels))
```

## 2021 PNW Marijuana Use


```r
ggplot(users, aes(x = Education, y = `Prevalence`, 
                    color = State, group = State)) + 
  geom_line(alpha = 0.7, show.legend = FALSE) + 
  geom_point(aes(size = DaysPerMonth), alpha = 0.5) + 
  guides(color = guide_legend(title = "State", override.aes = list(size = 3)),
         size = guide_legend(title = "Days of Use \nper Month"))
```

![](sql_examples_files/figure-html/message-1.png)<!-- -->

## Compare other Variables

Now that you know how to query the database, compare other variables, such as:

- Smoking and drinking with cholesterol (`_RFCHOL3`) or heart disease (`_MICHD`) 
- BMI category (`_BMI5CAT`) and exercise (`EXERANY2`) or sleep (`SLEPTIM1`)
- Health care access (`HLTHPLN1`) and household income (`INCOME2`)
- Stress (`QLSTRES2`) and marital status (`MARITAL`)
- Internet use (`INTERNET`) and mental health (`MENTHLTH`) 
- Life satisfaction (`LSATISFY`) and social/emotional support (`EMTSUPRT)`
- What are *you* curious about?

## Close Database Connection

Once we are done with the database, we can close the connection to it.


```r
# Close connection
dbDisconnect(con, shutdown = TRUE)
```

### What if I forget?

If you forget to close the connection, you will get an error if you try to reopen it.

```
Failed to open database: IO Error: 
Could not set lock on file "data/brfss_data.duckdb": 
Resource temporarily unavailable
```

### Write-Ahead-Log (`.wal`) Files

If you close your R session without first closing the connection, a `.wal` file 
may be left behind, preventing new connections. In that case, you could remove 
this file manually. Otherwise, R will cleanup that file for you after you close 
your connection with `dbDisconnect()`.
