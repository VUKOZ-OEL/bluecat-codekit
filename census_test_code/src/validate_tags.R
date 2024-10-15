source("src/global/functions.R", encoding="utf-8", verbose = F)
# LOAD TEES DATA
trees <- get_standing_trees()

# Get all col names
col.names <- names(trees)

# ONLY APPLY TEST IF TAG STATUS & TAG_NO ARE PRESENTED
if(TAG.STATUS.COL %in% col.names & TAG.NO.COL %in% col.names){
  
  print("TAG STATUS AND TAG NO PRESENTED")
  print("VALIDATING.")
  
  # 601 Check if tag is in acceptable tags
  tag_range <- ifelse(trees[[TAG.NO.COL]] %in% tag.list, "", "601_cislo_stitku_mimo_povoleny_rozsah")
  trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],tag_range)
  
  # 602 exit stitku  pri smrti stromu 
  exit_tag <- ifelse( trees[[STATUS_OLD.COL]] %in% ALIVE.STATUSES & trees[[STATUS_NEW.COL]] %in% DEAD.STATUSES & !trees[[TAG.STATUS.COL]] %in% c(300,400), "602_umrel_nepripustny_TAG_STAV_nebo_spatne_STATUS", "") 
  trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],exit_tag)
  
  # 603 stitek odebran (Tag_stav 300 = 	stitek odebran)
  stitek_odebran <- ifelse( trees[[TAG.STATUS.COL]] == 300 & !trees[[STATUS_NEW.COL]] %in% DEAD.STATUSES, "603_Stitek_nemel_byt_odebran_nebo_spatne_STATUS", "")
  trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],stitek_odebran)
  
  # 604 rekruti
  neni_rekrut <- ifelse( trees[[TAG.STATUS.COL]] == 200 & !is.na(trees[[DBH_OLD.COL]]) & trees[[DBH_OLD.COL]] != 0, "604_Chyba_TAG_STAV_rekrut_nesmi_mit_stare_DBH", "")
  trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],neni_rekrut)
  
  # 605 opozdenci
  neni_opozden <- ifelse( !is.na(trees[[DBH_OLD.COL]]) & trees[[DBH_OLD.COL]] != 0 & trees[[TAG.STATUS.COL]] %in% c(700,800), "605_Chyba_TAG_STAV_neni_opozdene_zameren_ma_stare_DBH", "")
  trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],neni_opozden) 
  
}else print("TAG_STATUS AND TAG_NO NOT FOUND.")

# ONLY APPLY TEST IF TAG PREFIX & TAG_NO ARE PRESENTED
if(TAG.PREFIX.COL %in% col.names & TAG.NO.COL %in% col.names){

  # # 606 tag_komplet musi obsahovat tag_cislo
  # tag_no_char <- as.character(trees[[TAG.NO.COL]])
  # tag_no <- substr(trees[[TAG.COMPLET_COL]],nchar(trees[[TAG.COMPLET_COL]])-nchar(tag_no_char)+1,nchar(trees[[TAG.COMPLET_COL]]) )
  # chyba_tag1 <- ifelse(tag_no_char != tag_no, "606_Chyba_TAG_CISLO_se_lisi_od_TAG_KOMPLET_over_v_lese", "")
  # trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],chyba_tag1)
  
  # LOAD ACCEPTABLE TAG VALUES
  tag.table <- read.table(TAG.TABLE.PATH,header = T)
  tag.table <- tag.table[tag.table$QuadratID == 13,]
  acceptable.tags <- paste(tag.table$QuadratID,tag.table$TagID,sep = "-")
  acceptable.tags <- append(acceptable.tags,"13-NA")
  
  complete.tags <- paste(trees[[TAG.PREFIX.COL]],trees[[TAG.NO.COL]],sep = "-")
  
  chyba_tag1 <- ifelse(!complete.tags %in% acceptable.tags, "606_Chyba_TAG_mimo_rozsah_povolených_hodnot", "")
  trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],chyba_tag1)
  
  
  complete.tags <- paste(complete.tags,trees[[STEM_ID.COL]],sep = "-")
  duplicated.tags <- complete.tags[duplicated(complete.tags, incomparables = "13-NA-1")]
  
  chyba_tag1 <- ifelse(complete.tags %in% duplicated.tags, "607_Chyba_duplicitni_TAG", "")
  trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],chyba_tag1)
  
  
  
}else print("TAG_COMPLETE NOT FOUND.")

# OVERWRITE TREES
overwrite_standing_trees(trees)

print(trees$error)