
source("src/global/functions.R", encoding="utf-8", verbose = F)

###---------------------------------------
### FUNCTIONs
# SELECT LAST RECORD FOR EACH UUID, used in lapply
select_last_record <- function(x) {
  if(nrow(x) == 1){
    return(x)
  }else if(all(is.na(x[[EDIT_DATE.COL]])) & all(duplicated(x)) ){
    return(x[1])
  }else if(all(is.na(x[[EDIT_DATE.COL]])) & !all(duplicated(x)) ) {
    
    x2 <- x[!is.na(x[[STATUS_NEW.COL]]),]
    if(nrow(x2) == 1) return(x2)
    else{
      n.cols <- ncol(x)
      x$count_na <- rowSums(is.na(x))
      x <- x[order(x$count_na),]
      return(x[1,1:n.cols])
    }
  }else{
    last.date <- max(x[[EDIT_DATE.COL]])
    last.records <- x[x[[EDIT_DATE.COL]] == last.date,]
    return(last.records[1,])
  }
}
###---------------------------------------

### STANDING TREES
# READ DEVICE NAMES (folders)
# list all .gpkg files in data.path
data.path <- "EDITED_FIELD_DATA"
all.geopackages <- list.files(path = data.path, pattern = "\\.(gpkg)$", recursive = TRUE)

# INIT EMPTY DF
all.standing <- data.frame()
all.lying <- data.frame()

fid.max <- 0
# COMBINE DATA FROM ALL DEVICES
for(file in all.geopackages){
  # make path to file & read data
  gpkg.file <- paste(data.path,file, sep = "/")
  standing <- read_from_gpkg(gpkg.file, STANDING.LAYER.NAME)
  lying <- read_from_gpkg(gpkg.file, LYING.LAYER.NAME)
  
   # ---------------------- TEMP
  nm <- names(lying)
  nm <- nm[nm != "count_na"]
  lying <- lying[,nm]

  
  # increment FID & ID_bod_line by max(FID) from previous device
  # For standing
  standing[[FID.COL]] <- as.numeric(standing[[FID.COL]]) + fid.max
  
  # For lying
  lying[[FID.COL]] <- as.numeric(lying[[FID.COL]]) + fid.max
  # For lying increment also RM_ID.COL to match STANDING
  lying[[RM_ID.COL]] <- as.numeric(lying[[RM_ID.COL]])
  lying[[RM_ID.COL]] <- lying[[RM_ID.COL]] + fid.max
  
  
  
  
# populate crew field by device name  
  device.name <- gsub(GPKG.NAME,"",file)
  device.name <- gsub("/","",device.name)
  #standing[[EDIT_BY.COL]] <- ifelse(is.na(standing[[EDIT_BY.COL]]),device.name,standing[[EDIT_BY.COL]])
  standing[[EDIT_BY.COL]] <- device.name
# Assign authorship by date if possible
  # if(all(is.na(standing[[EDIT_BY.COL]]))){
  #   standing[[EDIT_BY.COL]] <- Sys.Date()
  # }else standing <- assign_authorship_by_date(standing)
  # update increment value
  fid.max <- max(standing[[FID.COL]])
# if first file replace all.x else rbind all with device
  if(file == all.geopackages[1]){
      all.standing <- standing
      all.lying <- lying
  }else {
    all.standing <- rbind(all.standing,standing)
    all.lying <- rbind(all.lying,lying)
  }
}

# SELECT LAST RECORD FOR EACH UUID
#####################################
# FOR STANDING TREES ONLY:
# GROUP BY UUID, SELECT RECENTLY EDITED RECORD, RETURN DF OF UNIQUE RECORDS
# group.list <- split(all.standing, as.factor(all.standing[[UUID.COL]]))
# last.records <- lapply(group.list,select_last_record)
# unique.standing <- do.call(rbind, last.records)

standing.edited <- all.standing[!is.na(all.standing[[EDIT_DATE.COL]]), ]
standing.edited <- standing.edited[order(standing.edited[[EDIT_DATE.COL]], decreasing = TRUE), ]
standing.edited <- standing.edited[!duplicated(standing.edited[[UUID.COL]]), ]

standing.na.time <- all.standing[!all.standing[[UUID.COL]] %in% standing.edited[[UUID.COL]] ,]
standing.na.time <- standing.na.time[order(standing.na.time[[DBH_NEW.COL]], decreasing = FALSE), ]
standing.na.time <- standing.na.time[!duplicated(standing.na.time[[UUID.COL]]), ]

unique.standing <- rbind(standing.edited,standing.na.time)
# Initiate field for error message 
unique.standing$error <- NA
# Initiate field to indicate recruit
unique.standing$is.new.record <- ifelse(is.na(unique.standing[[DBH_OLD.COL]]), TRUE, FALSE)

#Save dataset
overwrite_standing_trees(unique.standing)

# FOR LYING ONLY:
# GROUP BY UUID, SELECT RECENTLY EDITED RECORD, RETURN DF OF UNIQUE RECORDS
# group.list <- split(all.lying, all.lying[[UUID.COL]])
# last.records <- lapply(group.list,select_last_record)
# unique.lying <- do.call(rbind, last.records)

all.lying <- all.lying[order(all.lying[[EDIT_DATE.COL]],decreasing = TRUE),]

unique.lying <- all.lying[!duplicated(all.lying[[UUID.COL]]), ]
unique.lying <- unique.lying[!duplicated(unique.lying$geom), ]

# Initiate field for error message 
unique.lying$error <- NA
# Save dataset
overwrite_lying_trees(unique.lying)



print("ALL DATA MERGED")



