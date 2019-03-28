# save all to geopackage

library(sf)
library(tidyverse)

# SHAPES ------------------------------------------------------------------

# check layers
st_layers("data/streamgages_06.kml")

# read in shps
rivs <- st_read("data/rivs_CA_OR_hydroshed.shp")
cdec_snow_stations <- st_read("data/cdec_snow_stations.shp")
h8_tahoe <- st_read("data/h8_tahoe.shp")
h8_centroids <- st_read("data/huc12_centroids/huc12_centroids.shp") %>% st_transform(4326) # from 3310
st_crs(h8_centroids)
lakes <- st_read("data/lakes_CA_OR_hydroshed.shp")

# WRITE TO GEOPACKAGE -----------------------------------------------------

st_write(rivs, dsn="data/mapping_in_R_data.gpkg", layer='rivs_CA_OR_hydroshed')
st_write(cdec_snow_stations, dsn="data/mapping_in_R_data.gpkg", layer='cdec_snow_stations')
st_write(h8_tahoe, dsn="data/mapping_in_R_data.gpkg", layer='h8_tahoe')
st_write(lakes, dsn="data/mapping_in_R_data.gpkg", layer='lakes_CA_OR_hydroshed')
# to overwrite add: ( layer_options = "OVERWRITE=YES" )
st_write(h8_centroids, dsn="data/mapping_in_R_data.gpkg", layer='h8_centroids', layer_options = "OVERWRITE=YES" )


# READ GEOPACKAGE:: SF -----------------------------------------------------

st_layers("data/mapping_in_R_data.gpkg")
tst1 <- st_read("data/mapping_in_R_data.gpkg", layer="h8_tahoe")
tst2 <- st_read("data/mapping_in_R_data.gpkg", layer="h8_centroids")
mapview::mapview(tst1) + mapview::mapview(tst2)

# READ GEOPACKAGE:: SQLITE/DB ---------------------------------------------

library(RSQLite)

# using dplyr
dbcon <- src_sqlite("data/mapping_in_R_data.gpkg", create = F) 
src_tbls(dbcon) # see tables in DB

# need to collect each table
lakes <- tbl(dbcon, "lakes_CA_OR_hydroshed") %>%  collect %>% 
  st_sf %>% st_set_crs(4326) # so need to tell it everything because it's a flat df
class(lakes)

