##########################################################################################
#
#     ~ ~ ~ Simple Habitat Index Model (HI) based on the total area of extensive grassland and its fragmentation into isolated patches ~ ~ ~
#     ~ ~ ~ this is just a toy model ~ ~ ~
#
#
#     ~ ~ ~ Input data ~ ~ ~
#    land_use.asc        |land use map containing the following classes
#                        |1 = extensive grassland
#                        |2 = intensive grassland
#                        |3 = river
#                        |-2 = no data
#
#    Objective: Maximize habitat area and connectivity
##########################################################################################

# set working directory CHANGED BB
setwd("C:\\Users\\bartkows\\Documents\\Papers\\2019 Social ecological optimization IP\\Model")

# load required packages
library(raster)
require(sp)
require(igraph)

# read in ascii files
lu.map <- read.asciigrid("landuse_final.asc", as.image = FALSE, plot.image = FALSE, colname = "lu",
                         proj4string = CRS(as.character(NA)))

# (just for testing) visualize map
# plot(lu.map)

# for the patch number calculation, convert all grid cells except extensive grassland to NA
# and use the raster format
lu.map$lu[which(lu.map$lu != 1)] <- NA
lu.map.r <- raster(lu.map)

# calculate the number of patches considering 8 neighbors (Queen's case)
n.patches <- clump(lu.map.r, directions=8)

# in case there is some extensive land use
if(sum(lu.map$lu, na.rm=T) > 0){
  # the habitat index (hi) is the total area of extensive grassland divided by the number of extensive grassland patches
  # hi can range between 0 (worst; no extensive grassland at all) to 100 (best; extensive grassland everywhere))
  hi <- round(sum(lu.map$lu, na.rm=T) / cellStats(n.patches, max), 2)
} else {
  # otherwise habitat quality is 0
  hi <- 0
}

# write model output...
