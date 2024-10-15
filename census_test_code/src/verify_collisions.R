
source("src/global/functions.R", encoding="utf-8", verbose = F)

# Collisions
# hardcoded related to error string
collisions <- c("Species","Revive","Shrinking","Increase")
colliding.errors <- c("203_zmena_dreviny","308_Strom_obzivl","313_hubnuti_stromu","314_prirust_nad_150mm")
# LOAD TREE DATA
trees <- get_standing_trees()
#check for omitted elements 
if(length(collisions) == length(colliding.errors)){
  # Remove error strings for verified collision
  for(i in c(1:length(collisions))){
    
    collision <- collisions[i]
    error.str <- colliding.errors[i]
    
    trees[[ERROR.COL]] <- ifelse(!is.na(trees[[IS.ERROR.COL]]) & trees[[IS.ERROR.COL]] == collision,
                                 gsub( error.str,"",trees[[ERROR.COL]] ),
                                 trees[[ERROR.COL]] )
    
  }
}else print("ERROR in hardcoded vectors, number of elements does not match.")


# VERIFYIED ERRORS 22-04-2024 !!!!!     TEMPORARY SOLUTION

ff <- "src/permanent_layers/UUID_errors_1st.csv"
if(file.exists(ff)){
  
  verified <- read.csv(ff)
  trees[[ERROR.COL]] <- ifelse(trees$uuid %in% verified$uuid, "", trees[[ERROR.COL]])

}

# Overwrite tree data
overwrite_standing_trees(trees)


