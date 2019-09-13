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
library(sp)
library(raster)
library(igraph)

# read in ascii files
lu.map <- read.asciigrid("landuse_final.asc", as.image = FALSE, plot.image = FALSE, colname = "lu",
                         proj4string = CRS(as.character(NA)))

# for the patch number calculation, convert all grid cells except extensive grassland to NA
# and use the raster format
lu.map$lu[which(lu.map$lu != 1)] <- NA
lu.map.r <- raster(lu.map)

# in case there is some extensive land use
if(sum(lu.map$lu, na.rm=T) > 0){
  # the habitat index (hi) is the total area of the two largest patches of extensive grassland divided by two
  # hi can range between 0 (worst; no extensive grassland at all) to 100 (best; extensive grassland everywhere))
  # calculate the number of patches considering 4 neighbors (King's case)
  n.patches <- clump(lu.map.r, directions=4)
  
  # sum up cells of the two largest patches
  patch.df <- as.data.frame(as.integer(as.matrix(n.patches)))
  patch.cells <- table(na.omit(patch.df))
  hi <- sum(sort(patch.cells, decreasing = T)[c(1,2)],na.rm = T)/2
  
} else {
  # otherwise habitat quality is 0
  hi <- 0
}

# write model output...

