# Download BRFSS data for a few years and export to a DuckDB database file.
#
# Depending on your internet connection, etc., this may take 16 minutes or more
# to run. The DuckDB file it creates will be about 1.4 GB without indexing and
# 1.7 GB with indexing. The size of the file can grow over time as DuckDB adds 
# more indexes to improve performance. After running "sql_examples.Rmd", the 
# file may grow to 1.9 GB or more.

# Attach packages, installing as needed
if(!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(haven, purrr, dplyr, duckdb, tictoc)

# Define function to download and import data for a given year
get_data <- function(yr, con) {
  # Download ZIP file and extract XPT file
  temp_file <- tempfile(fileext = ".zip")
  temp_dir <- file.path(tempdir(), "brfss_data")
  url_tmpl <- "https://www.cdc.gov/brfss/annual_data/%s/files/LLCP%sXPT.zip"
  url <- sprintf(url_tmpl, yr, yr)
  download.file(url, temp_file, mode = "wb", quiet = TRUE)
  on.exit(unlink(temp_file))
  unzip(temp_file, exdir = temp_dir)
  
  # Read XPT file(s) into a dataframe
  files <- list.files(temp_dir, pattern = ".XPT", full.names = TRUE)
  df <- map_df(files, read_xpt)
  
  # Remove temporary files and folders
  unlink(temp_dir, recursive = TRUE)
  
  # Return dataframe
  return(df)
}

# Define function to store BRFSS data in DuckDB database
store_data <- function(yr, con, tbl_name = "brfss") {
  # Store data in database, unless this year has already been stored
  if (tbl_name %in% dbListTables(con)) {
    # Check to make sure this year has not already been stored, noting that
    # each data file will usually include several rows for the following year
    sql_tmpl <- 'SELECT COUNT(*) as N FROM %s WHERE IYEAR = %s;'
    sql <- sprintf(sql_tmpl, tbl_name, yr)
    rs <- dbGetQuery(con, sql) %>% pull(N)
    # Years 2012-2021 should have >100K rows each, so import if less than this
    if (rs < 100000) {
      # Download and append data to DuckDB file, restricting to common columns
      df <- get_data(yr, con) %>% select(any_of(dbListFields(con, tbl_name)))
      dbWriteTable(con, tbl_name, df, append = TRUE)
    } else { warning(paste("Data for", yr, "has already been stored.")) }
  } else {
    # Download, import and store data as new DuckDB table
    df <- get_data(yr, con)
    dbWriteTable(con, tbl_name, df)
  }
}

# Define a function to create a database index
create_index <- function(dbcols, uniq = FALSE, con, tbl_name = "brfss") {
  idx <- sprintf("%s_%s_idx", tbl_name, tolower(paste(dbcols, collapse = "_")))
  dbc <- paste(dbcols, collapse = ", ")
  uni <- ifelse(uniq == TRUE, "UNIQUE", "")
  sql <-sprintf('DROP INDEX IF EXISTS %s; CREATE %s INDEX %s ON %s (%s);',
          idx, uni, idx, tbl_name, dbc)
  dbExecute(con, sql)
}

# Open database connection
dir.create(file.path("data"), recursive = TRUE, showWarnings = FALSE)
duckdb_path <- file.path("data", "brfss_data.duckdb")
con <- dbConnect(duckdb(), duckdb_path)

# Start timer
tic()

# Define years of BRFSS data to download
years <- 2012:2021

# Get and store data for a vector of years
result <- map(years, store_data, con = con)

# Stop timer
toc()

# Create index for improved performance and to prevent duplication
result <- create_index(c("SEQNO", "_STATE", "IYEAR"), uniq = TRUE, con = con)

# Import data for 2021 as a separate table to get the latest set of variables
result <- map(2021, store_data, con = con, tbl_name = "brfss2021")

# Close database connection
dbDisconnect(con, shutdown = TRUE)
