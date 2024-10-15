library(FNN)

source("src/global/functions.R", encoding="utf-8", verbose = F)

#READ DATA & STORE PERMANENT COL NAMES
trees <- get_standing_trees()
keep.cols <- names(trees)

# CHECK FOR DUPLICATED TREES
# set threshold for trees to be considered duplicated
threshold <- 0.01
xy.matrix <- st_coordinates(trees)
xy.matrix <- ifelse(is.na(xy.matrix),0,xy.matrix)
k.nn <- get.knn(xy.matrix, k = 1)

# 000 - GEOMETRY CHECK
#-------------------------------------------
# # CHECK IF POINT IS IN WIDE EXTENT OF PLOT
# polygon <- get_plot_boundary()
# # Create buffered polygon for test
# buffer <- 5 # m
# buffered_polygon <- st_buffer(polygon, buffer)
# # Initiate row.id field
# trees$row.id <- c(1:nrow(trees))
# # test if trees are inside buffered polygon, returns row.id of trees inside
# inside <- as.data.frame(st_within(trees, buffered_polygon))
# # Append error for trees outside the buffered polygon
# # 001 - bod_za_hranici_plochy
# trees$error <- ifelse(trees$row.id %in% inside$row.id, trees$error, paste(trees$error,"001_bod_za_hranici_plochy",sep = " - "))
# trees$error <- gsub("NA - ", "",trees$error)
# # Drop temp cols 
# trees <- trees[,keep.cols]
#-------------------------------------------
# SELECT FEATURES WITH "IDENTICAL" GEOMETRY
# 002 - duplicitni_geometrie_bodu
trees$duplicated_xy <- c(ifelse(k.nn$nn.dist < threshold, TRUE, FALSE))
trees$error <- ifelse(trees$duplicated_xy == TRUE, paste(trees$error,"002_duplicitni_geometrie_bodu",sep = " - "), trees$error)
trees$error <- gsub("NA - ", "",trees$error)
#-------------------------------------------
# Overwrite data
overwrite_standing_trees(trees)
