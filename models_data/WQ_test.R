##########################################################################################
#
#     ~ ~ ~ Simple Water Quality Model (WQ) based on the total area and distance of intensive land use ~ ~ ~
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
#    Objective: Maximize water quality
#
##########################################################################################

# set working directory CHANGED BB
setwd("C:\\Users\\bartkows\\Documents\\Papers\\2019 Social ecological optimization IP\\Model")

# load required package
library(raster)
require(sp)

# read in ascii files
lu.map <- read.asciigrid("landuse_final.asc", as.image = FALSE, plot.image = FALSE, colname = "lu",
                         proj4string = CRS(as.character(NA)))

# (just for testing) visualize map
# plot(lu.map)

# for distance function convert non-river grid cells to NA and use the raster format
lu.map.tmp <- lu.map
lu.map.tmp$lu[which(lu.map$lu <= 2)] <- NA
lu.map.r <- raster(lu.map.tmp)

# calculate distance to river for each cell
dist2river <- distance(lu.map.r)

# save as numeric list for further calculations
dist2river.v <- as.numeric(t(as.matrix(dist2river)))

# convert all grid cells to NA except for intensive land use
dist2river.v[which(lu.map$lu != 2)] <- NA

# invert the distance
dist2river.v <- 1/dist2river.v

# with 1 minus the normalized sum of inverted distances, water quality (wq) can range 
# between 0 (worst; intensive GL everywhere) to 100 (best; no intensive GL at all)
# the value of 2.302688 refers to the sum of distances for the 'intensive GL everywhere' case
wq <- round((1 - sum(dist2river.v, na.rm=T) / 2.302688) * 100, 2)

# write model output...
