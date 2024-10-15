# CONTROLLING SCRIPT OF THE WORKFLOW
# If running locally set working directory manually to plot directory
# setwd("/Zakova_hora")
# setwd("..")


print(paste("Workfolw root directory:",getwd()))

# LINK GLOBAL FUNCTIONS AND VARIABLES
source("src/global/functions.R", encoding="utf-8", verbose = F)
source("src/global/variables.R", encoding="utf-8", verbose = F)

# MANDATORY SCRIPTS
# failing of these cause crashes of whole workflow
  source("src/merge_field_data.R")
  source("src/renumber_fid_id_line.R")

# OPTIONAL SCRIPTS
# each script is independent, crash does not affect the others or the data flow
error.log <- c()

error <- try( source("src/geometry_check_xy_field.R") )  # ERROR CODE 10x
if(!is.list(error)) error.log <- append(error.log,paste("src/geometry_check_xy_field.R",error))

error <- try( source("src/check_tree_ids.R")  )          # ERROR CODE 40x 
if(!is.list(error)) error.log <- append(error.log,paste("src/check_tree_ids.R",error))

error <- try( source("src/species_test.R")  )            # ERROR CODE 20x
if(!is.list(error)) error.log <- append(error.log,paste("src/species_test.R",error))

error <- try( source("src/verify_record_standing.R")  )  # ERROR CODE 30x
if(!is.list(error)) error.log <- append(error.log,paste("src/verify_record_standing.R",error))

error <- try( source("src/verify_record_lying.R") )      # ERROR CODE 50x
if(!is.list(error)) error.log <- append(error.log,paste("src/verify_record_lying.R",error))

error <- try( source("src/validate_tags_SuchaBela.R") )     
#error <- try( source("src/validate_tags.R") )            # ERROR CODE 60x
if(!is.list(error)) error.log <- append(error.log,paste("src/validate_tags.R",error))

error <- try( source("src/verify_collisions.R") )     
if(!is.list(error)) error.log <- append(error.log,paste("src/verify_record_lying.R",error))

# MANDATORY
source("src/create_final_gpkg.R")

# OPTIONAL 
# generate report
ROOT.DIR <- getwd()
error <- try( rmarkdown::render("src/create_report.Rmd",output_format = "html_document" ,output_file = "Report.html", output_dir = getwd(), knit_root_dir = getwd() ) )
# if(!is.list(error)) error.log <- append(error.log,paste("src/validate_tags.R",error))
# 
# 




?rmarkdown::render












