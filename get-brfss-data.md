---
title: "Get BRFSS Data"
author: "Brian High"
date: "04/04/2023"
output:
  html_document:
    keep_md: yes
---

## Overview

Get the 2012-2021 datasets from http://www.cdc.gov/brfss, load into a data 
table, report file sizes and memory use, and save the data to a single TSV 
file and a single RDS file.

## Configure the time range in years


```r
datayears <- as.character(seq(2012, 2021))
```

## Load packages


```r
# Attach packages, installing as needed
if(!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(foreign, data.table)
```

## Set up data folder


```r
# Create the data folder if it does not already exist
datadir <- file.path("data")
if (!dir.exists(datadir)) dir.create(path = datadir, recursive = TRUE)
```

## Download data files


```r
getDataURL <- function(datayear) {
    # Correct for change in URLs after the year 2010
    if (as.numeric(datayear) > 2010) {
        dataurl <- paste("http://www.cdc.gov/brfss/annual_data/", datayear, 
                         "/files/LLCP", datayear, "XPT.ZIP", sep="")
    } else {
        dataurl <- paste("http://www.cdc.gov/brfss/annual_data/", datayear, 
                         "/files/CDBRFS", substr(datayear, 3, 4), "XPT.ZIP", 
                         sep="")        
    }
    return(dataurl)
}

reportFileSize <- function(filename) {
    # Report file size in MB. file.size() does not work in Windows.
    if (Sys.info()[['sysname']] != "Windows") {
        cat(paste(c("Size of file", filename, "is", 
                round(file.size(filename) / 1024 /1024, 1), "MB", "\n")))
    }
}

downloadDataFile <- function(datadir, datayear) {
    dataurl <- getDataURL(datayear)
    datafile <- file.path(datadir, paste("LLCP", datayear, "XPT.ZIP", sep=""))
    
    if (! file.exists(datafile)) {
        cat("Downloading data file for year", datayear, "...\n")
        download.file(dataurl, datafile, mode = 'wb')
        cat("Completed at", format(Sys.time()), "\n")
    }
    
    # Report file size of downloaded file
    retval <- reportFileSize(datafile)
}

retval <- sapply(datayears, function(x) downloadDataFile(datadir, x))
```

```
## Downloading data file for year 2012 ...
## Completed at 2023-04-04 11:50:50 
## Size of file data/LLCP2012XPT.ZIP is 91 MB 
## Downloading data file for year 2013 ...
## Completed at 2023-04-04 11:50:52 
## Size of file data/LLCP2013XPT.ZIP is 123 MB 
## Downloading data file for year 2014 ...
## Completed at 2023-04-04 11:50:53 
## Size of file data/LLCP2014XPT.ZIP is 68.9 MB 
## Downloading data file for year 2015 ...
## Completed at 2023-04-04 11:50:55 
## Size of file data/LLCP2015XPT.ZIP is 94.3 MB 
## Downloading data file for year 2016 ...
## Completed at 2023-04-04 11:50:56 
## Size of file data/LLCP2016XPT.ZIP is 79.5 MB 
## Downloading data file for year 2017 ...
## Completed at 2023-04-04 11:50:58 
## Size of file data/LLCP2017XPT.ZIP is 101.8 MB 
## Downloading data file for year 2018 ...
## Completed at 2023-04-04 11:50:59 
## Size of file data/LLCP2018XPT.ZIP is 69.5 MB 
## Downloading data file for year 2019 ...
## Completed at 2023-04-04 11:51:01 
## Size of file data/LLCP2019XPT.ZIP is 93.4 MB 
## Downloading data file for year 2020 ...
## Completed at 2023-04-04 11:51:02 
## Size of file data/LLCP2020XPT.ZIP is 64.4 MB 
## Downloading data file for year 2021 ...
## Completed at 2023-04-04 11:51:03 
## Size of file data/LLCP2021XPT.ZIP is 77.8 MB
```

## Extract data files


```r
getSASFileName <- function(datayear) {
    # Correct for change in filenames after the year 2010
    if (as.numeric(datayear) > 2010) {
        sasfile <- paste("LLCP", datayear, ".XPT", sep="")
    } else {
        sasfile <- paste("CDBRFS", substr(datayear, 3, 4), ".XPT", sep="")
    }
    
    return(sasfile)
}

extractDataFile <- function (datadir, datayear) {
    sasfile <- file.path(datadir, getSASFileName(datayear))
    datafile <- file.path(datadir, paste("LLCP", datayear, "XPT.ZIP", sep=""))
    
    if (! file.exists(sasfile)) {
        cat("Extracting SAS data file ", sasfile, "...", "\n")
        unzip(datafile, exdir = datadir)
        # Remove the space character at the end of filename if necessary.
        # This found to be an issue in the 2014 data file.
        if (file.exists(paste(sasfile, " ", sep=""))) {
            file.rename(from = paste(sasfile, " ", sep=""), to = sasfile)
        }
    }
    
    # Report file size of extracted file
    retval <- reportFileSize(sasfile)
}

retval <- sapply(datayears, function(x) extractDataFile(datadir, x))
```

```
## Extracting SAS data file  data/LLCP2012.XPT ... 
## Size of file data/LLCP2012.XPT is 832.5 MB 
## Extracting SAS data file  data/LLCP2013.XPT ... 
## Size of file data/LLCP2013.XPT is 851.7 MB 
## Extracting SAS data file  data/LLCP2014.XPT ... 
## Size of file data/LLCP2014.XPT is 645.2 MB 
## Extracting SAS data file  data/LLCP2015.XPT ... 
## Size of file data/LLCP2015.XPT is 1111.5 MB 
## Extracting SAS data file  data/LLCP2016.XPT ... 
## Size of file data/LLCP2016.XPT is 1018 MB 
## Extracting SAS data file  data/LLCP2017.XPT ... 
## Size of file data/LLCP2017.XPT is 1228.8 MB 
## Extracting SAS data file  data/LLCP2018.XPT ... 
## Size of file data/LLCP2018.XPT is 917.4 MB 
## Extracting SAS data file  data/LLCP2019.XPT ... 
## Size of file data/LLCP2019.XPT is 1084.2 MB 
## Extracting SAS data file  data/LLCP2020.XPT ... 
## Size of file data/LLCP2020.XPT is 848.7 MB 
## Extracting SAS data file  data/LLCP2021.XPT ... 
## Size of file data/LLCP2021.XPT is 1006.6 MB
```

## Read data files into R data table


```r
reportSize <- function(dt, datayear) {
    # Report data table size and dimensions
    cat("Size of data table for", datayear, "is:\n")
    print(object.size(dt), units = "MB")
    cat("Data table for", datayear, "contains", 
        dim(dt)[1], "observations and", 
        dim(dt)[2], "variables", "\n")
    return(NULL)
}

importDataFile <- function(datadir, datayear) {
    # Read data file
    options(digits = 2)
    sasfile <- file.path(datadir, getSASFileName(datayear))
    dt <- as.data.table(read.xport(sasfile))
    retval <- reportSize(dt, datayear)
    return(dt)
}

brfss <- rbindlist(lapply(datayears, function(x) importDataFile(datadir, x)), 
                   fill = TRUE)
```

```
## Size of data table for 2012 is:
## 1303.4 Mb
## Data table for 2012 contains 475687 observations and 359 variables 
## Size of data table for 2013 is:
## 1261.5 Mb
## Data table for 2013 contains 491773 observations and 336 variables 
## Size of data table for 2014 is:
## 989.8 Mb
## Data table for 2014 contains 464664 observations and 279 variables 
## Size of data table for 2015 is:
## 1112.4 Mb
## Data table for 2015 contains 441456 observations and 330 variables 
## Size of data table for 2016 is:
## 1022.8 Mb
## Data table for 2016 contains 486303 observations and 275 variables 
## Size of data table for 2017 is:
## 1230.7 Mb
## Data table for 2017 contains 450016 observations and 358 variables 
## Size of data table for 2018 is:
## 920.2 Mb
## Data table for 2018 contains 437436 observations and 275 variables 
## Size of data table for 2019 is:
## 1092.5 Mb
## Data table for 2019 contains 418268 observations and 342 variables 
## Size of data table for 2020 is:
## 856.7 Mb
## Data table for 2020 contains 401958 observations and 279 variables 
## Size of data table for 2021 is:
## 1016.6 Mb
## Data table for 2021 contains 438693 observations and 303 variables
```

```r
retval <- reportSize(brfss, "all years")
```

```
## Size of data table for all years is:
## 28881.7 Mb
## Data table for all years contains 4506254 observations and 840 variables
```

## Write data to a TSV file


```r
tsvfile <- file.path(datadir, "brfss_data.tsv")
write.table(x = brfss, file = tsvfile, row.names = FALSE, fileEncoding = "UTF-8", 
            sep = "\t", quote = FALSE, na = "\\N", eol = "\n")

# Report file size of TSV file
retval <- reportFileSize(tsvfile)
```

```
## Size of file data/brfss_data.tsv is 10756.3 MB
```

## Write data to a RDS file


```r
rdsfile <- file.path(datadir, "brfss_data.rds")
saveRDS(brfss, rdsfile)

# Report file size of RDS file
retval <- reportFileSize(rdsfile)
```

```
## Size of file data/brfss_data.rds is 479.6 MB
```
