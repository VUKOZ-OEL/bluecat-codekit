
#setwd("/Users/martinkrucek/Documents/GitHub/milesice")
#setwd("C:/Users/krucek/Documents/GitHub/VUKOZ-OEL/milesice")
#source("src/global/functions.R", encoding="utf-8", verbose = F)

source("src/merge_field_data.R")
source("src/renumber_fid_id_line.R")
source("src/geometry_check_xy_field.R")   # ERROR CODE 00x
source("src/species_test.R")              # ERROR CODE 20x
source("src/verify_record_standing.R")    # ERROR CODE 30x
source("src/check_tree_ids.R")            # ERROR CODE 40x
source("src/verify_record_lying.R")       # ERROR CODE 50x
source("src/verify_collisions.R") 
source("src/plot_trees_map.R")
source("src/create_final_gpkg.R")
source("src/update_errors_individuall_gpkg.R")
source("src/update_readme_md.R")
 


trees <- get_standing_trees()

dw <- get_lying_trees()

s











