# This script was written by chatGPT with some edits by Brian High
# 2023-04-04

# Load necessary packages
library(haven)
library(purrr)
library(dplyr)
library(duckdb)

# Define base URL and years for BRFSS SAS data
base_url <- "https://www.cdc.gov/brfss/annual_data/"
years <- 2017:2021

# Define URLs for BRFSS SAS data for years 2017 through 2021
urls <- paste0(base_url, years, "/files/LLCP", years, "XPT.zip")

# Define function to download and import data for a given year
download_data <- function(url) {
  # Download ZIP file and extract XPT file
  temp_file <- tempfile(fileext = ".zip")
  download.file(url, temp_file, mode = "wb")
  on.exit(unlink(temp_file))
  unzip(temp_file, exdir = "brfss_data")
  
  # Read XPT files into a dataframe
  files <- list.files("brfss_data", pattern = ".XPT", full.names = TRUE)
  brfss_data <- map_df(files, read_xpt)
  
  # Remove temporary files and folders
  unlink("brfss_data", recursive = TRUE)

  # Store data in database
  if ("brfss_data" %in% dbListTables(con, "brfss_data")) {
    # Append data frame to DuckDB file, restricting to common columns
    brfss_data <- brfss_data %>% select(any_of(dbListFields(con, "brfss_data")))
    duckdb::dbWriteTable(con, "brfss_data", brfss_data, append = TRUE)
  } else {
    # Save data frame to new DuckDB table
    duckdb::dbWriteTable(con, "brfss_data", brfss_data)
  }
}

# Open database connection
con <- duckdb::dbConnect(duckdb(), "brfss_data.duckdb")

# Download, import, and save data for all years
result <- map(urls[2:5], download_data)

# Close database connection
duckdb::dbDisconnect(con, shutdown = TRUE)


# Check that database contains data from years 2017-2021
con <- duckdb::dbConnect(duckdb(), brfss_data.duckdb)

query <- '
SELECT IYEAR AS Year, COUNT(*) AS Respondents
FROM brfss_data
GROUP BY IYEAR
ORDER BY IYEAR;
'

dbGetQuery(con, query)
##   Year Respondents
## 1 2017      438337
## 2 2018      430153
## 3 2019      418580
## 4 2020      408476
## 5 2021      427317
## 6 2022       23508

duckdb::dbDisconnect(con, shutdown = TRUE)
