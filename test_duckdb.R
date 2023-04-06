# Check that database contains data from years 2012-2021

# Attach packages, installing as needed
if(!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(dplyr, duckdb, tictoc)

# Open database connection
duckdb_path <- file.path("data", "brfss_data.duckdb")
con <- dbConnect(duckdb(), duckdb_path)

# Show stats on Respondents per year
tic()
brfss_data <- tbl(con, "brfss")
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
toc()

# Close database connection
dbDisconnect(con, shutdown = TRUE)
