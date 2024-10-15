source("src/global/functions.R", encoding="utf-8", verbose = F)

#---------------------------------------------------------------
# Function to check if a variable is a whole 6-digit number
isSixDigitNumber <- function(variable) {
  return(grepl("^\\d{6}$", variable))
}
#---------------------------------------------------------------

# FOR LYING
# load
deadwooods <- get_lying_trees()

# CHECK IF TREE_ID OF DEADWOOD HAS 6 DIGITS
has.six.digits <- ifelse(!isSixDigitNumber(deadwooods[[TREE_ID.COL]]) , "401_chybne_strom_id", "") 
deadwooods[[ERROR.COL]] <- appendError(deadwooods[[ERROR.COL]],has.six.digits)

# CHECK DUPLICATED IDs
# select duplicated ids
complete.id.strings <- paste(deadwooods[[TREE_ID.COL]], deadwooods[[STEM_ID.COL]], toupper(deadwooods[[LOG_ID.COL]]), sep = "-")
duplicated.ids <- complete.id.strings[duplicated(complete.id.strings)]
# assign error string to duplicated ids
duplicit.id.error <- ifelse( complete.id.strings %in% duplicated.ids, "402_lezici_duplicita_STROM_ID-KMEN_ID-KUS_ID", "") 
deadwooods[[ERROR.COL]] <- appendError(deadwooods[[ERROR.COL]],duplicit.id.error)
# OVERWRITE DATA
overwrite_lying_trees(deadwooods)

# FOR STANDING
# load
trees <- get_standing_trees()
# select duplicated ids
complete.id.strings <- paste(trees[[TREE_ID.COL]], trees[[STEM_ID.COL]], sep = "-")
duplicated.ids <- complete.id.strings[duplicated(complete.id.strings, incomparables = c("NA-1","NA-NA") )]
# assign error string to duplicated ids
duplicit.id.error <- ifelse( complete.id.strings %in% duplicated.ids & (!is.na(trees[[TREE_ID.COL]]) | trees[[TREE_ID.COL]] != 0), "403_stojici_duplicita_STROM_ID-KMEN_ID", "") 
trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],duplicit.id.error)
# OVERWRITE DATA
overwrite_standing_trees(trees)



