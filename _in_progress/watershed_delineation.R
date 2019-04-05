
# Watershed Delineation ---------------------------------------------------

# see here for NHD data:
# https://viewer.nationalmap.gov/basic/?basemap=b1&category=nhd&title=NHD%20View

# Thu Apr  4 23:18:40 2019 ------------------------------
# following this post
# follow this: http://matthewrvross.com/active.html


# Load Libraries ----------------------------------------------------------

library(sf)
library(mapview)
library(mapedit)
library(rayshader)
library(tidyverse)
library(elevatr)
library(raster)
#devtools::install_github("giswqs/whiteboxR")
library(whitebox)
library(stars)
library(rgl)
library(here)

# Create Points -----------------------------------------------------------

# these are nfa tribs
sites <- tibble(site=c('indian','robbers','shirttail'),
                lat=c(39.05698, 39.10451, 39.03994),
                long=c(-120.90772,-120.92630, -120.90095)) %>%
  #Convert to spatial object
  st_as_sf(coords=c('long','lat'),crs=4326, remove=FALSE) %>%
  #transform to NAD83 
  st_transform(3310) %>% 
  mutate(X_utm = st_coordinates(geometry)[,1],
         Y_utm = st_coordinates(geometry)[,2])


# GET DEM -----------------------------------------------------------------

# Use elevatr::get_elev_raster to download data. 
# Z sets the resolution 14 is highest resolution, 1 is lowest
nfa_dem <- get_elev_raster(sites,z=12, expand = 1400)

# generate a box and check topo basemap for full watershed capture
nfa_box <- st_bbox(nfa_dem) %>% st_as_sfc()

# plot box:
mapview(nfa_box, alpha.regions=0.2) + mapview(sites)

# plot DEM
mapview(nfa_dem, alpha.regions=0.6) + mapview(sites)

# Save files so that whitebox can call the data
writeRaster(nfa_dem, filename=paste0(here::here(),'/_in_progress/dem_dat/nfa_dem.tif'), overwrite=T)

# save pts
st_write(sites,paste0(here::here(),'/_in_progress/dem_dat/sites.shp'),
         delete_layer=T)


# Clean Raster ------------------------------------------------------------

# Breach filling
dem_white <- paste0(here(),'/_in_progress/dem_dat/nfa_dem.tif')


# Fill single cell pits (for hydrologic correctness)
fill_single_cell_pits(dem = dem_white,
                      output = paste0(here(),'/_in_progress/dem_dat/breach2.tif'),
                      verbose_mode = TRUE)

# Breach depressions (better option that pit filling according to whitebox documentation) 
# The flat_increment bit may need tuning.
breach_depressions(dem = paste0(here(),'/_in_progress/dem_dat/breach2.tif'), 
                   output =paste0(here(),'/_in_progress/dem_dat/breached.tif'), 
                   flat_increment=.02, verbose_mode = TRUE)


# Create D8 Pointer and Flow Grid -----------------------------------------

# There are eight possible output directions relating to the eight adjacent grid cells into which flow could travel. This approach is commonly referred to as a D8 flow model (following Jenson and Domingue (1988))
# see here for overview: https://pro.arcgis.com/en/pro-app/tool-reference/spatial-analyst/how-flow-direction-works.htm

# D8 pointer (the flow directions in the 8-cell grid)
d8_pointer(dem = '_in_progress/dem_dat/breached.tif',
           output = '_in_progress/dem_dat/d8_pntr.tif')


# D8 flow: can specify "catchment area", "cells", or "specific contributing area"
d8_flow_accumulation('_in_progress/dem_dat/breached.tif', 
                     '_in_progress/dem_dat/d8_flow.tif', out_type='catchment area')


# Snap Pour Points
snap_pour_points(pour_pts = '_in_progress/dem_dat/sites.shp',
                 flow_accum = '_in_progress/dem_dat/d8_flow.tif',
                 output = '_in_progress/dem_dat/snapped_sites.shp', snap_dist = 20,
                 verbose_mode = TRUE)

# view
#snapped_sites <- st_read("_in_progress/dem_dat/snapped_sites.shp")
#mapview(snapped_sites) + mapview(sites, col.regions="red") + mapview(nfa_dem)

# Watershed Delineation ---------------------------------------------------

# Watershed delineation as "whole watersheds'
unnest_basins(d8_pntr = '_in_progress/dem_dat/d8_pntr.tif',
              pour_pts = '_in_progress/dem_dat/snapped_sites.shp',
              output = '_in_progress/dem_dat/basins/nfa_sheds.tif')

# Check Wateshed Delineation ----------------------------------------------

# Read in flow accumulation algorithm
fac <- raster('_in_progress/dem_dat/d8_flow.tif')

# Get a list of the watershed created by `unnest_basins`
sheds <- list.files('_in_progress/dem_dat/basins',full.names=T)

# Create a function that uses the stars package to transform
# the raster watershed outlines into shapefiles
shed_stacker <- function(x){
  read_stars(sheds[x]) %>%
    st_as_sf(merge=T,use_integer = T) %>%
    rename(id=1) %>%
    group_by(id) %>%
    summarize()
}

## Use purrr::map to apply the raster-shapefile transformation to all
## rasters to a list of shapefiles (map_dfr doesn't play nice with sf for 
## unknown reasons)
s <- purrr::map(1:length(sheds),shed_stacker)

# Use do.call to bind these sf objects into a single one
shape_sheds <- do.call('rbind',s) %>% arrange(id)

# Map Final Watershed Delineation -----------------------------------------

# subset flow accumulation by the shape of the watersheds
fac_sub <- crop(fac,shape_sheds)

# THIS IS FOR STATIC PLOT WITH STARS
# # or use stars:
# fac_stars <- st_as_stars(fac_sub)
# # transform to same crs:
# shape_sheds <- st_transform(shape_sheds, st_crs(fac))
# # crop:
# fac_crop <- st_crop(fac_stars, shape_sheds)
# # PLOT
# plot(fac_stars[shape_sheds], reset = FALSE)
# plot(shape_sheds$geometry, add=TRUE, col = NA, lwd=2, border = 'skyblue')

# dynamic MAP!
mapview(fac_sub) + 
  mapview(shape_sheds) + mapview(sites)


# 3D Plot -----------------------------------------------------------------

## Setup a matrix 

#crop and mask elevatr DEM
nfa_only <- nfa_dem %>%
  crop(.,shape_sheds) %>%
  mask(.,shape_sheds)

#Convert to matrix so rayshader is happy
pmat <- matrix(raster::extract(nfa_only,raster::extent(nfa_only),buffer=300),
               nrow=ncol(nfa_only),ncol=nrow(nfa_only))

#Generate a hillshade
raymat = ray_shade(pmat,sunangle=330)

#use rayshader commands to generate map
#rglwidget embeds output in html
pmat %>%
  sphere_shade(texture='desert') %>%
  add_shadow(raymat) %>%
  plot_3d(pmat,zscale=10,fov=0,theta=135,zoom=0.75,phi=45,
          windowsize=c(750,750))
rglwidget()



# Stream Stats ------------------------------------------------------------

# https://streamstats.usgs.gov/ss/

# calculate area (sqkm) of Indian Ck
st_area(shape_sheds[1,])/1000000 # 23.79 sq km


ind_ss_cent <- st_read("_in_progress/dem_dat/indianck/centroid.shp")
ind_ss <- st_read("_in_progress/dem_dat/indianck/globalwatershed.shp")
# stream stats for Indian was 23.83!


mapview(ind_ss, col.regions="blue2", alpha.regions=0.4) + 
  mapview(shape_sheds[1,], layer.name="Shed", col.regions="yellow2", alpha.regions=0.4) +
  mapview(ind_ss_cent) +
mapview(st_centroid(shape_sheds[1,]), col.region="black")
