
source("src/global/functions.R", encoding="utf-8", verbose = F)



# LOAD TREE DATA
trees <- get_standing_trees()

# 300 KONTROLA KOMPLETNOSTI ZAZNAMU 
# ------------------------------------------------
# 301 kontrlola pahyl musi mit vysku
#pahyl_chybi_vyska <- ifelse( trees[[STATUS_NEW.COL]] == "P" & ( is.na(trees[[HEIGHT.COL]]) | trees[[HEIGHT.COL]] == 0) , "301_Pahyl_chybi_vyska", "") 
#trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],pahyl_chybi_vyska)

# 302 kontrlola pahyl musi mit rozklad
#pahyl_chybi_rozklad <- ifelse( trees[[STATUS_NEW.COL]] == "P" & is.na(trees[[DECAY.COL]]), "302_Pahyl_chybi_rozklad", "") 
#trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],pahyl_chybi_rozklad)

# 303 kontrlola pahyl musi mit DBH
#pahyl_chybi_DBH <- ifelse( trees[[STATUS_NEW.COL]] == "P" & is.na(trees[[DBH_NEW.COL]] ), "303_Pahyl_chybi_DBH", "") 
#trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],pahyl_chybi_DBH)

# 304 souse chybi rozklad 
#souse_chybi_rozklad <- ifelse( trees[[STATUS_NEW.COL]] == "O" &( is.na(trees[[DECAY.COL]] ) | trees[[DECAY.COL]] == 0 ) , "304_Souse_chybi_rozklad", "") 
#trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],souse_chybi_rozklad)

# 305 Chybi vyska zlomu
#vyska_zlomu <- ifelse( trees[[STATUS_NEW.COL]] == "Z" & ( is.na(trees[[HEIGHT.COL]]) | trees[[HEIGHT.COL]] == 0 ) , "305_Chybi_vyska_zlomu_nebo_neni_zlom", "") 
#trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],vyska_zlomu)

# 306 Rozklad je navic u parezu
#rozklad_navic <- ifelse( trees[[STATUS_NEW.COL]] == "EZ" & ( !is.na(trees[[DECAY.COL]]) | trees[[DECAY.COL]] == 0 ), "306_Rozklad_je_navic_mozny_pahyl", "")
#trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],rozklad_navic)

# 307 PAHYL musi byt vyssi nez 1.3m
#pahyl_nizky <- ifelse( trees[[STATUS_NEW.COL]] == "P" & trees[[HEIGHT.COL]] > 0 & trees[[HEIGHT.COL]] < 1.3, "307_PAHYL_vyska_nesplnuje_limit_mozny_PAREZ", "") 
#trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],pahyl_chybi_vyska)

# 308 obzivnuti
obzivnuti <- ifelse( is.element(trees[[STATUS_NEW.COL]],ALIVE.STATUSES) & is.element(trees[[STATUS_OLD.COL]],DEAD.STATUSES), "308_Strom_obzivl", "")
trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],obzivnuti)

# 309 jama po parezu
#parezova_jama <- ifelse( trees[[STATUS_NEW.COL]] == "JE", "309_Opravdu_status_JE_potvrd", "")
#trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],parezova_jama)

# 310 vicecetnost
chyba_cetnost <- ifelse( trees[[MULTIPLICITY.COL]] == "SGL" & trees[[STEM_ID.COL]] > 1, "310_Chyba_v_cetnosti_kmene_nebo_KMEN_ID", "")
trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],chyba_cetnost)

# 311 zmena P na O
p.to.o <- ifelse( trees[[STATUS_NEW.COL]] == "DI" & trees[[STATUS_OLD.COL]] == "DB", "311_Z_pahylu_se_stala_souse_zkontroluj_STATUS", "")
trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],p.to.o)

# 312 reverzni status
reverzni.status <- ifelse( trees[[STATUS_OLD.COL]] %in% c("DU" ,"SH" ,"DP" ,"BLS") & trees[[STATUS_NEW.COL]] %in% c("DI","DB"), "312_Reverzni_vyvoj_Statusu_Zkontroluj_STATUS", "")
trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],reverzni.status)

# 313 hubnuti stromu
hubnuti <- ifelse(trees[[STATUS_NEW.COL]] %in% ALIVE.STATUSES & trees[[DBH_OLD.COL]] > trees[[DBH_NEW.COL]] , "313_hubnuti_stromu", "")
trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],hubnuti)

# 314 velky prirust
increase <- ifelse(trees[[STATUS_NEW.COL]] %in% ALIVE.STATUSES & !is.na(trees[[DBH_NEW.COL]]) & !is.na(trees[[DBH_OLD.COL]]) & trees[[DBH_NEW.COL]] - trees[[DBH_OLD.COL]] > 150, "314_prirust_nad_150mm", "")
trees[[ERROR.COL]] <- appendError(trees[[ERROR.COL]],increase)

# Overwrite tree data
overwrite_standing_trees(trees)


trees$dbh_diff <- trees[[DBH_NEW.COL]] - trees[[DBH_OLD.COL]]



