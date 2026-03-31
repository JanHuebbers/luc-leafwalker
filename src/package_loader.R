PKG_VERBOSE <- FALSE

libs <- c(
  "cowplot",
  "dplyr",
  "forcats",
  "ggplot2",
  "ggstar",
  "multcompView",
  "psych",
  "purrr",
  "readr",
  "rstatix",
  "scales",
  "showtext",
  "tibble",
  "tidyr",
  "yaml"
)

missing <- character(0)

suppressPackageStartupMessages({
  invisible(lapply(libs, function(pkg) {
    ok <- suppressWarnings(
      require(pkg, character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE)
    )
    if (!ok) {
      missing <<- c(missing, pkg)
    } else if (PKG_VERBOSE) {
      message("Loaded: ", pkg)
    }
  }))
})

if (length(missing) > 0) {
  stop(
    "The following packages are missing: ",
    paste(missing, collapse = ", ")
  )
}

message("All required packages loaded successfully.")