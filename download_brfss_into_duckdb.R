# Download BRFSS data for a few years and export to a DuckDB database file

# Attach packages, installing as needed
if(!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(haven, purrr, dplyr, duckdb)

# Define base URL and years for BRFSS SAS data
base_url <- "https://www.cdc.gov/brfss/annual_data/"
years <- 2012:2021

# Define URLs for BRFSS SAS data for years 2017 through 2021
urls <- paste0(base_url, years, "/files/LLCP", years, "XPT.zip")

# Define function to download and import data for a given year
download_data <- function(url) {
  # Download ZIP file and extract XPT file
  temp_file <- tempfile(fileext = ".zip")
  download.file(url, temp_file, mode = "wb", quiet = TRUE)
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
dir.create(file.path("data"), recursive = TRUE, showWarnings = FALSE)
con <- duckdb::dbConnect(duckdb(), file.path("data", "brfss_data.duckdb"))

# Download, import, and save data for all years
result <- map(urls, download_data)

# Close database connection
duckdb::dbDisconnect(con, shutdown = TRUE)

# ------------ Tests --------------

# Open database connection
con <- duckdb::dbConnect(duckdb(), file.path("data", "brfss_data.duckdb"))

# Add two indexes to improve query performance, removing first if already there 
dbExecute(con, 
          "DROP INDEX IF EXISTS brfss_iyear_idx;
           DROP INDEX IF EXISTS brfss_iyear_state_idx;
           CREATE INDEX brfss_iyear_idx ON brfss_data (IYEAR);
           CREATE INDEX brfss_iyear_state_idx ON brfss_data (IYEAR, _STATE);")

# Check that database contains data from years 2017-2021
brfss_data <- tbl(con, "brfss_data")
result <- brfss_data %>% 
  select("Year" = IYEAR, "State" = `_STATE`) %>% 
  group_by(Year, State) %>% 
  summarize(Respondents = n(), .groups = "drop") %>% 
  group_by(Year) %>% 
  summarize(`Mean Respondents` = mean(Respondents, na.rm = TRUE),
            `SD Respondents` = sd(Respondents, na.rm = TRUE),
            .groups = "drop") %>% 
  arrange(Year)
result %>% show_query()
result %>% collect()

# Close database connection
duckdb::dbDisconnect(con, shutdown = TRUE)
