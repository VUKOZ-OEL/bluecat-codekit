source("src/global/functions.R", encoding="utf-8", verbose = F)

# WRITE TREES INTO GPKG
# read trees
date.limit <- c("2024-04-02","2024-04-03","2023-07-19","2023-07-20","2023-07-21")

trees <- get_standing_trees()
trees$date <- as.character(as.Date(trees[[EDIT_DATE.COL]]))

trees$solved <- FALSE

# APPLY DATE LIMIT
#trees <- trees[ !is.na(trees[[EDIT_DATE.COL]]) & trees$date %in% date.limit, ]


trees <- trees[!is.na(trees[[DBH_NEW.COL]]) & !is.na(trees[[STATUS_NEW.COL]]),]
trees$err2 <-gsub(" ","",trees[[ERROR.COL]])
errors <- trees[nchar(trees$err2) > 4,c("error","solved","geom")]

data.path <- "data/EDITED_FIELD_DATA"
all.geopackages <- list.files(path = data.path, pattern = "\\.(gpkg)$", recursive = TRUE)

for(file in all.geopackages){
  # make path to file & read data
  gpkg.file <- paste(data.path,file, sep = "/")
  insert_in_gpkg(errors,gpkg.file,"ERRORS")
}

print("ERRORS saved INDIVIDUALLY into GPKG")


