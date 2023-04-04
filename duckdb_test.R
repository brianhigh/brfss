# Compare data read times for "rds", "sqlite", and "duckdb" files.
# Data source: https://www.cdc.gov/brfss/annual_data/annual_data.htm
# For R code to download BRFSS, see: https://github.com/brianhigh/brfss
#
# Size of BRFSS "data.table" for years 2012-2018 is 16973.8 MB in memory.
# Size of dataset is   342.8 MB as (compressed) "rds" file.
# Size of dataset is  3179.6 MB as "sqlite" file.
# Size of dataset is 17596.0 MB as "duckdb" file.
# Dataset contains 3247335 observations and 685 variables.
#
# Summary of results:
#
# - readRDS is much faster at reading than Sqlite but not faster than DuckDB.
# - DuckDB is much faster than SQlite when reading entire tables.
# - DuckDB is much faster than SQlite when running new queries.
# - DuckDB is faster than SQlite for queries which have been run before.

system.time(brfss <- readRDS(file.path("data", "brfss_data.rds")))

##  user  system elapsed 
## 205.6     3.4   210.8 

library(DBI)

con <- dbConnect(RSQLite::SQLite(), "brfss_data.sqlite")
dbWriteTable(con, "brfss", brfss)
system.time(brfss_data <- dbReadTable(con, "brfss"))

## user  system elapsed 
## 1328      29    1367 

query <- '
SELECT IYEAR AS Year, COUNT(*) AS Respondents
FROM brfss
GROUP BY IYEAR
ORDER BY IYEAR;
'

# Running this query the first time creates an index for later.
system.time(res <- dbGetQuery(con, query))

## user  system elapsed 
## 8.80   12.89   74.42 

# Running a second time will be a lot faster because of the new index.
system.time(res <- dbGetQuery(con, query))

## user  system elapsed 
## 1.21    0.33    1.93

# Running a second time will be even faster because of caching.
system.time(res <- dbGetQuery(con, query))

## user  system elapsed 
## 1.17    0.24    1.46 

dbDisconnect(con)

con_duck <- dbConnect(duckdb::duckdb(), 'brfss_data.duckdb')
dbWriteTable(con_duck, "brfss", brfss)
system.time(brfss_data <- dbReadTable(con_duck, "brfss"))

## user  system elapsed 
##  155      15     171 

# This runs fast the first time because it's already indexed.
system.time(res <- dbGetQuery(con_duck, query))

## user  system elapsed 
## 0.50    0.15    1.33 

# Running a second time will be even faster because of caching.
system.time(res <- dbGetQuery(con_duck, query))

## user  system elapsed 
## 0.58    0.00    0.58

dbDisconnect(con_duck)

library(DBI)
con_duck <- dbConnect(duckdb::duckdb(), 'brfss_data.duckdb')

# Just read the whole dataset for comparison...
system.time(brfss_data <- dbReadTable(con_duck, "brfss"))

##   user  system elapsed
## 177.03   17.79  196.98

## This took almost as long as reading the "RDS" file.

library(dplyr)
library(dbplyr)

# Now read a subset using dbplyr...

# This just sets up the query
brfss_db <- tbl(con_duck, "brfss")
system.time(brfss_subset_db <- brfss_db %>%
                select(c("X_STATE", "X_GEOSTR", "IDATE", "IYEAR")) %>%
                filter(IYEAR > 2016))

## user  system elapsed
## 0.02    0.00    0.04

# This shows the tidyverse pipeline converted to a SQL query.
show_query(brfss_subset_db)

## <SQL>
## SELECT *
## FROM (SELECT "X_STATE", "X_GEOSTR", "IDATE", "IYEAR"
## FROM "brfss") "dbplyr_026"
## WHERE ("IYEAR" > 2016.0)

# This will actually perform the query and return the subset...
system.time(brfss_subset <- brfss_subset_db %>% collect())

## user  system elapsed
## 2.42    0.05    2.51

# Here we save that same SQL query as a character string.
query <- '
SELECT *
FROM (SELECT "X_STATE", "X_GEOSTR", "IDATE", "IYEAR"
FROM "brfss") "dbplyr_026"
WHERE ("IYEAR" > 2016.0);
'

# And now we run the SQL query the traditional way.
system.time(brfss_subset_from_sql <- as_tibble(dbGetQuery(con_duck, query)))

## user  system elapsed
## 2.37    0.03    2.42

# The run times are very comparable.

all_equal(brfss_subset, brfss_subset_from_sql)
## TRUE

# The results are identical.

dbDisconnect(con_duck)
