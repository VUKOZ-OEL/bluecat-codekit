source("src/global/functions.R", encoding="utf-8", verbose = F)

trees <- get_standing_trees()

standing.count <- nrow(trees)
visited.count <- nrow(trees[!is.na(trees[[DBH_NEW.COL]]),])
prog.perc <- round(visited.count/standing.count*100,2)

trees <- get_standing_trees()
trees <- trees[!is.na(trees[[DBH_NEW.COL]]) & !is.na(trees[[STATUS_NEW.COL]]),]
trees$err2 <-gsub(" ","",trees[[ERROR.COL]])
errors <- trees[nchar(trees$err2) > 4,]
error.count <- nrow(errors)
# ------------------------------------------------------------------------------
#READ TEMPLATE FILE
lines <- readLines("data/permanent_layers/readme_template.md")

lines <- gsub("progess_percentage", paste(prog.perc), lines)
lines <- gsub("error_count", paste(error.count), lines)
lines <- gsub("visited_standing", paste(visited.count), lines)
lines <- gsub("total_standing", paste(standing.count), lines)

#SAVE UPDATED README.md
write.table(lines,"README.md",col.names = F, row.names = F, quote = F)
