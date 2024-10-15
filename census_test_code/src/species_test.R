source("src/global/functions.R", encoding="utf-8", verbose = F)

trees <- get_standing_trees()
keep.cols <- names(trees)

#species <- read.table("data/permanent_layers/SPECIES_LIST.txt")
#names(species) <- c("species","condition")

# # 200 - SPECIES CHECK
# species.ok <- species[species$condition == "OK",1]
# species.warn <- species[species$condition == "WARNING",1]
# # 201 - cybna drevina nebo prvni vyskyt
# trees$species_error <- "201_chybna_drevina_nebo_prvni_vyskyt"
# trees$species_error <- ifelse(trees[[SPECIES.COL]] %in% species.ok,NA,trees$species_error)
# # 202 - varovani_malocetna_drevina
# trees$species_error <- ifelse(trees[[SPECIES.COL]] %in% species.warn,"202_varovani_malocetna_drevina",trees$species_error)
# # Append error string
# trees$error <- ifelse(is.na(trees$species_error),trees$error, paste(trees$error,trees$species_error, sep = " - "))
# trees$error <- gsub("NA - ", "",trees$error)
# # Drop temp cols
# trees <- trees[,keep.cols]

# 203 Zmena dreviny
species_change <- ifelse( trees[[SPECIES.COL]] != trees[[SPECIES.OLD.COL]] & !is.na(trees[[IS.NEW.RECORD]]) , "203_zmena_dreviny", "")
trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],species_change)


# Overwrite tree data
overwrite_standing_trees(trees)



