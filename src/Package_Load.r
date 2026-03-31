library(renv)
# Ensure that all necessary packages are installed and loaded
libs <- c("ape", "cowplot", "dplyr", "extrafont", "ggbeeswarm", "ggbreak", "ggdist", "ggpattern", "ggpubr", "ggstar", "grid", "gtools", "multcompView", 
          "openxlsx", "pheatmap", "psych", "RColorBrewer", "readr", "readxl", "reshape2", "reticulate", "rmarkdown", "rstatix", "scales", "showtext", 
          "svglite", "tibble", "tidyverse", "vitae", "writexl", "yaml")

sapply(libs, function(lib) {
  tryCatch({
    if (!require(lib, character.only = TRUE)) {
      renv::install(lib)
      library(lib, character.only = TRUE)
    }
  }, error = function(e) {
    message(paste("Failed to load library:", lib, "with error:", e$message))
  })
})

# Configure showtext for using Arial font
showtext_auto()
font_add("Arial", regular = "arial.ttf", bold = "arialbd.ttf", italic = "ariali.ttf", bolditalic = "arialbi.ttf")


