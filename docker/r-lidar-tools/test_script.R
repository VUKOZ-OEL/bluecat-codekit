# Vektor názvů všech balíčků, které byly instalovány v kontejneru
packages <- c(
  "lidR",
  "ggplot2",
  "raster",
  "terra",
  "viridis",
  "sf",
  "data.table",
  "stars",
  "RColorBrewer",
  "dplyr",
  "sp"
)

# Funkce pro testování načtení balíčku
check_package <- function(pkg) {
  suppressPackageStartupMessages({
    res <- require(pkg, character.only = TRUE)
  })
  if (res) {
    message(sprintf("Balíček '%s' načten úspěšně.", pkg))
  } else {
    message(sprintf("CHYBA: Balíček '%s' se nepodařilo načíst!", pkg))
  }
}

# Test načtení všech balíčků
invisible(lapply(packages, check_package))
