source("src/global/functions.R", encoding="utf-8", verbose = F)


# Load data
standing <- get_standing_trees()
lying <- get_lying_trees()

print( paste("1 LYING count:", nrow(lying)) )
print( paste("1 standing count:", nrow(standing)) )

# store collumns names
keep.cols.s <- names(standing)
keep.cols.l <- names(lying)
# Generate new q_fid for standing
standing$fid_new <- c(1:nrow(standing))
# Create hash table
map.id <- as.data.frame(standing[,c(FID.COL,"fid_new")])



# drop geometry
map.id <- map.id[-c(3)]
# rename cols
names(map.id) <- c(RM_ID.COL,"fid_new")

print( paste("1 map.id count:", nrow(map.id)) )
print( paste("1.1 LYING count:", nrow(lying)) )

# Merge hash table to lying by old ID
# !!!  for some reason geom col is renamed to geometry at following line
lying <- merge(lying, map.id, by = RM_ID.COL,all.x = T)

print( paste("2 LYING count:", nrow(lying)) )

# !!! rename geometry col back to geom to not change col names unnecessarily
st_geometry(lying) <- "geom"
print( paste("3 LYING count:", nrow(lying)) )

# overwrite old q_fid values by appropriate new ones
lying[[RM_ID.COL]] <- lying$fid_new
print( paste("4 LYING count:", nrow(lying)) )
standing[[FID.COL]] <- standing$fid_new
# Drop excessive collumns
lying <- lying[,keep.cols.l]
print( paste("5 LYING count:", nrow(lying)) )
standing <- standing[,keep.cols.s]
# Save modified data

overwrite_standing_trees(standing)



# SPECIAL CHECK FOR DUPLICIT FID

if(TRUE %in% duplicated(lying[[FID.COL]])){

  lying <- lying[order(lying[[EDIT_DATE.COL]]),]
  
  unique.fid <- lying[!duplicated(lying[[FID.COL]]),]
  duplicated.fid <- lying[duplicated(lying[[FID.COL]]),]
  
  
  new.fid <- c(1:nrow(duplicated.fid))
  duplicated.fid[[FID.COL]] <- new.fid + 5000
  
  lying <- rbind(unique.fid,duplicated.fid)
  print(nrow(lying))
}

print("END, NROW LYING:")
print(nrow(lying))
print("print(table(duplicated(lying$fid))) :")
print(table(duplicated(lying$fid)))
overwrite_lying_trees(lying)


print(trees$geom)

