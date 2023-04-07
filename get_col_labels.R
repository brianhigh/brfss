# Get column labels from XPT file and save as CSV file (for reference)

# Attach packages, installing as needed
if(!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(haven, purrr, dplyr)

# Download a zipped XPT file from BRFSS website
datadir <- file.path("data")
zipurl <- "https://www.cdc.gov/brfss/annual_data/2021/files/LLCP2021XPT.zip"
zipfile <- file.path(datadir, basename(zipurl))
download.file(zipurl, destfile = zipfile)

# Extract XPT from ZIP file, read first line, then extract attributes and save
if (file.exists(zipfile)) {
  unzip(zipfile, exdir = datadir)
  xptfile <- file.path(datadir, gsub('xpt\\.zip', '.XPT', basename(zipurl), 
                                     ignore.case = TRUE))
  
  # Rename if XPT file contains extra space at end of name
  xptfile_ <- paste0(xptfile, ' ')
  if (file.exists(xptfile_)) file.rename(xptfile_, xptfile)
  
  # Read XPT file, extract column names and labels and save in a CSV file
  if (file.exists(xptfile)) {
    df <- read_xpt(xptfile, n_max = 1)
    
    # Cleanup files
    if (nrow(df) > 0) {
      unlink(zipfile)
      unlink(xptfile)
    }
    
    # Create a label lookup dataframe
    label_lookup <- tibble(
      col_name = df %>% names(),
      label = df %>% map_chr(attr_getter("label"))
    )
    
    # Save label lookup as CSV file
    csvfile <- file.path(datadir, "label_lookup_2021.csv")
    write.csv(label_lookup, csvfile, row.names = FALSE)
  }
}
