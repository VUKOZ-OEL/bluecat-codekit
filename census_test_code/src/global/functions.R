# LIBS
library(sf)
source("src/global/variables.R", encoding="utf-8", verbose = F)
#------------------------------------------------------------------
# GLOBAL FUNCTIONS
# ERROR STRING HANDLING
appendError <- function(x,y){
  
  xy <- paste(x,y)
  xy <- ifelse(xy == "NA NA",NA,xy)
  xy <- gsub("NA ","",xy)
  xy <- gsub(" NA","",xy)
  
  return(xy)
}
#------------------------------------------------------------------
# GPKG IO
read_from_gpkg <- function(gpkg.file, layer.name){
  return(st_read(dsn = gpkg.file,layer = layer.name, stringsAsFactors = FALSE, fid_column_name = FID.COL))
}
insert_in_gpkg <- function(layer.data, gpkg.file, layer.name){
  st_write(layer.data, gpkg.file, layer = layer.name, driver = "GPKG", append = FALSE,fid_column_name = FID.COL)
}
#------------------------------------------------------------------
# READ WRITE INTERIM RESULTS
get_standing_trees <- function(){
  return(readRDS(STANDING.PATH))
}
overwrite_standing_trees <- function(trees){
  saveRDS(trees,STANDING.PATH)
}
get_lying_trees <- function(){
  return(readRDS(LYING.PATH))
}
overwrite_lying_trees <- function(lying){
  saveRDS(lying,LYING.PATH)
}
get_plot_boundary <- function(){
  # read boundary, cast to polygon 
  boundary <- st_read(PROJECT.PATH,BOUNDARY.LAYER.NAME)
  return(st_polygonize(boundary))
}
#------------------------------------------------------------------
# RECORD AUTHOR HANDLING
assign_authorship_by_date <- function(trees){
  # preserve original collumns
  keep.cols <- names(trees)
  # unify text string
  trees[[EDIT_BY.COL]] <- iconv(trees[[EDIT_BY.COL]], "UTF-8", "ASCII//TRANSLIT")
  trees[[EDIT_BY.COL]] <- gsub("[[:punct:]]", "", trees[[EDIT_BY.COL]])
  trees[[EDIT_BY.COL]] <- gsub(" ", "", trees[[EDIT_BY.COL]])
  # Assign author to records collected in same day
  # initiate scratch cols for date without time and for week_number
  trees$date <- substr(trees[[EDIT_DATE.COL]],1,10)
  trees$week_num <- strftime(trees$date, format = "%V")
  # extract signed records 
  signed.records <- trees[!is.na(trees[[EDIT_BY.COL]]), ]
  # create author + date table from signed records
  author.date <- as.data.frame(signed.records)
  author.date <- author.date[,c(EDIT_BY.COL,"date")]
  # remove duplicated dates
  author.date <- author.date[!duplicated(author.date$date),]
  # assign authorship by day
  for(i in 1:nrow(author.date)){
    # IF date == day && EDIT_BY.COL == NA than EDIT_BY.COL update
    trees[[EDIT_BY.COL]] <- ifelse(trees$date == author.date[i,"date"] & is.na(trees[[EDIT_BY.COL]]),author.date[i,EDIT_BY.COL],trees[[EDIT_BY.COL]])
  }
  
  # init week number & remove duplicated weeks
  author.date$week_num <- strftime(author.date$date, format = "%V")
  author.date <- author.date[!duplicated(author.date$week_num),]
  
  # assign authorship by week
  for(i in 1:nrow(author.date)){
    # IF week_no == week_no && EDIT_BY.COL == NA than EDIT_BY.COL update
    trees[[EDIT_BY.COL]] <- ifelse(trees$week_num == author.date[i,"week_num"] & is.na(trees[[EDIT_BY.COL]]),author.date[i,EDIT_BY.COL],trees[[EDIT_BY.COL]])
  }
  
  # assign authorship for rest (NAs)
  trees[[EDIT_BY.COL]] <- ifelse(is.na(trees[[EDIT_BY.COL]]), "unknown_mapper",trees[[EDIT_BY.COL]])
  
  # keep only original cols
  trees <- trees[,keep.cols]

  return(trees)
}




