require(lubridate)

# Function to Make Water Year column from date/time column (Oct 1 through Sep 30)
wtr_yr <- function(dates, start_month=10) {
  # Convert dates into POSIXlt
  dates.posix = as.POSIXlt(dates)
  # Year offset
  offset = ifelse(dates.posix$mon >= start_month - 1, 1, 0)
  # Water year
  adj.year = dates.posix$year + 1900 + offset
  # Return the water year
  return(adj.year)
}


# add Water Year Day (Day 1 starting Oct 1)
dowy<-function(YYYYMMDD_HMS) {   # Dates must be POSIXct
  YYYYMMDD_HMS<-YYYYMMDD_HMS
  #wy<-wtr_yr(YYYYMMDD_HMS)
  doy<-yday(YYYYMMDD_HMS)
  
  # make DOWY
  offsetday = ifelse(month(YYYYMMDD_HMS) > 9, -273, 92)
  DOWY = doy + offsetday
  
  # adjust for leap year
  offsetyr = ifelse(lubridate::leap_year(YYYYMMDD_HMS), 1, 0) # Leap Year offset
  adj.wyd = ifelse(offsetyr==1 & doy > 274, DOWY - 1, DOWY)
  
  return(adj.wyd)
}


# add DOY to df
add_WYD <- function(df, datecolumn){ # provide either number or quoted name for date POSIXct col
  datecolumn=datecolumn
  df["DOY"] <- as.integer(sapply(df[,c(datecolumn)], yday))
  df["WY"] <- as.integer(sapply(df[,c(datecolumn)], wtr_yr))
  df["DOWY"] <- as.integer(sapply(df[,c(datecolumn)], dowy))
  return(df)
  
}


# example: 
# data <- add_WYD(data, "datetime")
# data <- add_WYD(data, 1)