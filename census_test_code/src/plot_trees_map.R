
source("src/global/functions.R", encoding="utf-8", verbose = F)
# Plot tree map 

boundary.poly <- get_plot_boundary()

tiles <- st_read("data/permanent_layers/vec/ZH_census_2024_geopackage.gpkg","ZH_grid")

trees <- get_standing_trees()
visited <- trees[!is.na(trees[[DBH_NEW.COL]]),]

tree.counts <- as.data.frame(table(visited[[EDIT_BY.COL]]), stringsAsFactors = FALSE)
tree.counts$color <- heat.colors(nrow(tree.counts))
visited <- merge(visited,tree.counts,by.x = EDIT_BY.COL,by.y = "Var1")

jpeg(file="data/assets/overall_progress_map.jpeg",width = 22, height = 22, units = "cm", res = 600)
plot(trees$geom, col = "grey80", pch = 16, cex = 0.5)
plot(visited$geom, col = visited$color,pal = colors, add = T, pch = 16, cex = 0.6)
plot(boundary.poly, add = T)
plot(tiles, add = T, color = "white", lty = 3)
xy <- st_coordinates(st_centroid(tiles))
text(xy[,1], xy[,2], tiles$kolik_id, cex = 0.75)
dev.off()
#--------------------------------------------------------------
#Plot tree counts by group
#tree.counts <- as.data.frame(table(visited$crew))
print("2")
jpeg(file="data/assets/visited_counts_barplot.jpeg",width = 10, height = nrow(tree.counts)*0.75, units = "cm", res = 300)
par(mar = c(1, 3, 0.5, 0.5))
#par(mar=c(1,1,1,1))
barplot(tree.counts$Freq, main="", horiz=TRUE,beside = TRUE, names.arg = tree.counts$Var1,cex.names = 0.5, las = 1,
        col = tree.counts$color, cex.axis = 0.6 )
dev.off()
#-------------------------------------------------------------






