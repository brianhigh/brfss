# Download BRFSS data for a few years and export to a DuckDB database file

# Attach packages, installing as needed
if(!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(haven, purrr, dplyr, duckdb)

# Define base URL and years for BRFSS SAS data files
base_url <- "https://www.cdc.gov/brfss/annual_data/"
years <- 2017:2021

# Define URLs for each file to be downloaded
urls <- paste0(base_url, years, "/files/LLCP", years, "XPT.zip")

# Define function to download, read, and export data for a given year
download_data <- function(url, ddb_fn = "brfss_data.duckdb") {
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
  
  # If DuckDB file exists, get column names and limit brfss_data to those names
  if (file.exists(ddb_fn)) {
    # Append data frame to DuckDB file, restricting to common columns
    con <- duckdb::dbConnect(duckdb(), ddb_fn)
    brfss_data <- brfss_data %>% select(any_of(dbListFields(con, "brfss_data")))
    duckdb::dbWriteTable(con, "brfss_data", brfss_data, append = TRUE)
    duckdb::dbDisconnect(con, shutdown = TRUE)
  } else {
    # Save data frame to new DuckDB file
    con <- duckdb::dbConnect(duckdb(), ddb_fn)
    duckdb::dbWriteTable(con, "brfss_data", brfss_data)
    duckdb::dbDisconnect(con, shutdown = TRUE)
  }
}

# Download, import, and save data for all years
result <- map(urls, download_data)
