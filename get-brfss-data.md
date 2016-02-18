# Get BRFSS Data
Brian High  
02/17/2016  

## Overview

Get the 2012-2014 datasets from http://www.cdc.gov/brfss, load into a data 
table, report file sizes and memory use, and save the data to a single TSV 
file.

## Configure the time range in years


```r
datayears <- as.character(seq(2012, 2014))
```

## Load packages


```r
## Install packages (if necessary)
for (pkg in c("foreign", "data.table", "plyr")) {
    if (! suppressWarnings(require(pkg, character.only=TRUE)) ) {
        install.packages(pkg, repos="http://cran.fhcrc.org", dependencies=TRUE)
        if (! suppressWarnings(require(pkg, character.only=TRUE)) ) {
            stop(paste(c("Can't load package: ", pkg, "!"), sep = ""))
        }
    }
}
```

## Set up data folder


```r
# Create the data folder if it does not already exist
datadir <- "./data"
dir.create(file.path(datadir), showWarnings=FALSE, recursive=TRUE)

# Enter data folder, first saving location of current folder
projdir <- getwd()
setwd(datadir)
datadir <- getwd()
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
    setwd(datadir)
    dataurl <- getDataURL(datayear)
    datafile <- paste("LLCP", datayear, "XPT.ZIP", sep="")
    
    if (! file.exists(datafile)) {
        cat("Downloading data file for year", datayear, "...\n")
        download.file(dataurl, datafile, mode='wb')
        cat("Completed at", format(Sys.time()), "\n")
    }
    
    # Report file size of downloaded file
    retval <- reportFileSize(datafile)
    
    # Return to project folder
    setwd(projdir)
}

retval <- sapply(datayears, function(x) downloadDataFile(datadir, x))
```

```
## Downloading data file for year 2012 ...
## Completed at 2016-02-18 07:17:00 
## Size of file LLCP2012XPT.ZIP is 91 MB 
## Downloading data file for year 2013 ...
## Completed at 2016-02-18 07:17:02 
## Size of file LLCP2013XPT.ZIP is 123 MB 
## Downloading data file for year 2014 ...
## Completed at 2016-02-18 07:17:03 
## Size of file LLCP2014XPT.ZIP is 68.9 MB
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
    setwd(datadir)
    sasfile <- getSASFileName(datayear)
    datafile <- paste("LLCP", datayear, "XPT.ZIP", sep="")
    
    if (! file.exists(sasfile)) {
        cat("Extracting SAS data file ", sasfile, "...", "\n")
        unzip(datafile)
        # Remove the space character at the end of filename if necessary.
        # This found to be an issue in the 2014 data file.
        if (file.exists(paste(sasfile, " ", sep=""))) {
            file.rename(from = paste(sasfile, " ", sep=""), to = sasfile)
        }
    }
    
    # Report file size of extracted file
    retval <- reportFileSize(sasfile)
    
    # Return to project folder
    setwd(projdir)
}

retval <- sapply(datayears, function(x) extractDataFile(datadir, x))
```

```
## Extracting SAS data file  LLCP2012.XPT ... 
## Size of file LLCP2012.XPT is 832.5 MB 
## Extracting SAS data file  LLCP2013.XPT ... 
## Size of file LLCP2013.XPT is 851.7 MB 
## Extracting SAS data file  LLCP2014.XPT ... 
## Size of file LLCP2014.XPT is 645.2 MB
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
    setwd(datadir)
    options(digits=2)
    sasfile <- getSASFileName(datayear)
    dt <- as.data.table(read.xport(sasfile))
    retval <- reportSize(dt, datayear)
    
    # Return to project folder
    setwd(projdir)
    return(dt)
}

brfss <- as.data.table(adply(.data=datayears, .margins=c(1),
                       .fun=function(x) importDataFile(datadir, x)))
```

```
## Size of data table for 2012 is:
## 1281.6 Mb
## Data table for 2012 contains 475687 observations and 359 variables 
## Size of data table for 2013 is:
## 1239 Mb
## Data table for 2013 contains 491773 observations and 336 variables 
## Size of data table for 2014 is:
## 975.6 Mb
## Data table for 2014 contains 464664 observations and 279 variables
```

```r
retval <- reportSize(brfss, "all years")
```

```
## Size of data table for all years is:
## 5557.8 Mb
## Data table for all years contains 1432124 observations and 518 variables
```

## Write data to a TSV file


```r
tsvfile <- paste(datadir, "brfss_data.tsv", sep="/")
write.table(x=brfss, file=tsvfile, row.names=FALSE, fileEncoding="UTF-8", 
            sep="\t", quote=FALSE, na="\\N", eol="\n")

# Report file size of TSV file
retval <- reportFileSize(tsvfile)
```

```
## Size of file ./data/brfss_data.tsv is 2087.5 MB
```
