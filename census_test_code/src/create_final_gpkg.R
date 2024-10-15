source("src/global/functions.R", encoding="utf-8", verbose = F)

# WRITE TREES INTO GPKG
# read trees
trees <- get_standing_trees()

# drop error collumn
out.cols <- names(trees)
out.cols <- out.cols[! out.cols %in% c('error',IS.NEW.RECORD,"duplicated_xy")]
trees.out <- trees[,out.cols] 
# overwrite layer in gpkg file
insert_in_gpkg(trees.out,PROJECT.PATH,STANDING.LAYER.NAME)
print("Standing trees saved into GPKG")

# WRITE ERRORS INTO GPKG
trees <- trees[!is.na(trees[[DBH_NEW.COL]]) & !is.na(trees[[STATUS_NEW.COL]]),]
trees$err2 <-gsub(" ","",trees[[ERROR.COL]])
errors <- trees[nchar(trees$err2) > 4,c("error","geom")]

if(nrow(errors) > 0){
  errors$solved <- FALSE
}

insert_in_gpkg(errors,PROJECT.PATH,"ERRORS")
print("ERRORS saved into GPKG")
# insert_in_gpkg(errors,"data/permanent_layers/vec/ERRORS.gpkg","ERRORS")
# print("ERRORS saved separately into GPKG")

# WRITE LYING INTO GPKG
 lying <- get_lying_trees()
 keep.cols <- names(lying)
 
 # remove duplicet records with differet uuid
 lying$count_na <- rowSums(is.na(lying))
 lying <- lying[order(lying$count_na),]
 lying <- lying[!duplicated(lying[[FID.COL]]),]
 
 keep.cols <- keep.cols[! keep.cols %in% c('error','count_na')]
 lying <- lying[,keep.cols]
 
 insert_in_gpkg(lying,PROJECT.PATH,LYING.LAYER.NAME)
 print("Deadwoods saved into GPKG")