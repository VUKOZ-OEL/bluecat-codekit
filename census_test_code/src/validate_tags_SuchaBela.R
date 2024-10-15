source("src/global/functions.R", encoding="utf-8", verbose = F)

# ------------------------------------------------------------------------------
# MODIFY ACCORDING TO OPEN BOXES
groupA.start <- 1
groupA.end <- 500

groupB.start <- 501
groupB.end <- 1000

groupC.start <- 1001
groupC.end <- 1500
# MANUAL MOD END
# ------------------------------------------------------------------------------

# create valid tags vector
valid.tags <- c(groupA.start:groupA.end, groupB.start:groupB.end, groupC.start:groupC.end )
# LOAD TEES DATA
trees <- get_standing_trees()
# Get all col names
col.names <- names(trees)

# ONLY APPLY TEST IF TAG PREFIX & TAG_NO ARE PRESENTED
if(TAG.NO.COL %in% col.names){



  # check if tag no is in valid range
  chyba_tag1 <- ifelse(!trees[[TAG_NO.COL]] %in% valid.tags, "606_TAG_mimo_rozsah_povolených_hodnot", "")
  trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],chyba_tag1)
  
  # check if all alive trees have tag
  chyba_tag2 <- ifelse(is.na(trees[[TAG_NO.COL]]) & trees[[STATUS_NEW.COL]] %in% ALIVE.STATUSES, "607_Zivy_strom_bez_stitku", "")
  trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],chyba_tag2)
  
  # check for duplicated tags
  duplicated.tags <- trees[[TAG_NO.COL]][duplicated(trees[[TAG_NO.COL]], incomparables = "NA")]
  
  chyba_tag1 <- ifelse(trees[[TAG_NO.COL]] %in% duplicated.tags, "608_Duplicitni_TAG", "")
  trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],chyba_tag1)
  
  
  
}else print("TAG FIELD NOT FOUND.")

# OVERWRITE TREES
overwrite_standing_trees(trees)

