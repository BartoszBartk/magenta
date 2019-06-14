##########################################################################################
#
#     ~ ~ ~ Simple Agricultural Yield Model (AY) ~ ~ ~
#     ~ ~ ~ this is just a toy model ~ ~ ~
#     ~ ~ ~ Input data ~ ~ ~
#    land_use.asc        |land use map containing the following classes
#                        |1 = extensive grassland
#                        |2 = intensive grassland
#                        |3 = river
#                        |-2 = no data
#
#    soil_fertility.asc  |map on soil fertility which can range from 0.07 to 1
#
#    Objective: Maximize agricultural yield
#
##########################################################################################

# load required package (here just for plotting)
library(raster)
require(sp)

# set working directory
setwd("C:\\Users\\bartkows\\Documents\\Papers\\2019 Social ecological optimization IP\\Model")

# read in ascii files as tables
lu.map <- read.table("landuse_final.asc", h=F, skip=6, sep=" ")
fert.map <- read.table("soil_fertility.asc", h=F, skip=6, sep=" ")

# (just for testing) visualize maps
# lu.map_ <- read.asciigrid("landuse_rand.asc", as.image = FALSE, plot.image = FALSE, colname = "lu",
#                         proj4string = CRS(as.character(NA)))

# fert.map_ <- read.asciigrid("soil_fertility.asc", as.image = FALSE, plot.image = FALSE, colname = "lu",
#                         proj4string = CRS(as.character(NA)))

# plot(lu.map_)
# plot(fert.map_)

# array index for grassland
grassland.idx <- which(lu.map <= 2, arr.ind=T)

# calculate agricultural yield (ay) as a function of total area of intensive grassland and soil fertility
# ay can range between 163.1 (worst; no intensive GL at all) to 220.64 (best; intensive GL everywhere)

lu.map[which(lu.map == 1, arr.ind=T)] <- 1.5
ay <- log(lu.map[grassland.idx] * (1 + fert.map[grassland.idx]))
ay[is.na(ay)] <- 0

# summarize over whole area and normalize ay to a range from 0 to 100 
ay.sum <- (round(sum(ay),2) - 163.1) / (220.64 - 163.1) * 100

# write model output...