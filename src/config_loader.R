# config_loader.R
# ----------------
# Reads the (trimmed) config.yml and exposes clean R objects used across scripts.
#
# This version is tailored for the luciferase complementation workflow:
# - Keeps your existing directory + figure size settings
# - Builds BOTH protein-keyed and letter-keyed axis label expressions
#   * Use Lx_letter/Ly_letter if your plotting x/y variables are letters (A..J, etc.)
#   * Use Lx_protein/Ly_protein if your plotting variables are full protein IDs
# - Provides optional on-demand color mapping (AF3-style) if config$Colors exists
#
# Assumptions about YAML structure:
#   NLuc: { <LETTER>: "<protein>", ... }  e.g. B: "AtMLO1"
#   CLuc: { <LETTER>: "<protein>", ... }  e.g. A: "AtEXO70A1"
# Optional:
#   Colors:
#     Box: { default: "#FFFFFF" }
#     Point:  { A: "#...", B: "#...", ... }   # keys are letters
#     MPoint: { A: "#...", B: "#...", ... }   # keys are letters
# Optional:
#   Filter:
#     enforce_config_only: true/false
#
# NOTE: config_path must be defined in the calling script.

suppressPackageStartupMessages({
  library(yaml)
  library(rlang)
})

`%||%` <- rlang::`%||%`

# ────────────────────────────────────────────────────────────────────────────────
# 1) Read YAML
# ────────────────────────────────────────────────────────────────────────────────
config <- yaml::read_yaml(config_path)

# ────────────────────────────────────────────────────────────────────────────────
# 2) Directories (base R only)
# ────────────────────────────────────────────────────────────────────────────────
# Output directory
out_dir <- normalizePath(
  config$Directories$Output_directory,
  winslash = "/",
  mustWork = FALSE
)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Optional data directory (falls back to out_dir)
data_dir <- config$Directories$Data_directory %||% out_dir
data_dir <- normalizePath(data_dir, winslash = "/", mustWork = FALSE)

# ────────────────────────────────────────────────────────────────────────────────
# 3) Core settings
# ────────────────────────────────────────────────────────────────────────────────
sep   <- config$Sep   %||% ","
alpha <- config$Alpha %||% 0.01

# Optional filter switch
enforce_config_only <- config$Filter$enforce_config_only %||% FALSE

# ────────────────────────────────────────────────────────────────────────────────
# 4) Figure dimensions [cm]
# ────────────────────────────────────────────────────────────────────────────────
SLw <- config$Figures$Violin$w
SLh <- config$Figures$Violin$h
wHM <- config$Figures$Heatmap$w
hHM <- config$Figures$Heatmap$h

# ────────────────────────────────────────────────────────────────────────────────
# 5) REQUIRED: ordering from NLuc / CLuc letter maps
#    YAML provides: LETTER -> PROTEIN
# ────────────────────────────────────────────────────────────────────────────────
NLuc_map <- config$NLuc
CLuc_map <- config$CLuc

# Defensive checks (helpful early errors)
stopifnot(!is.null(NLuc_map), !is.null(CLuc_map))
stopifnot(!is.null(names(NLuc_map)), !is.null(names(CLuc_map)))

# Letter order (alphabetical by letter)
NLuc_letters <- names(NLuc_map)[order(names(NLuc_map))]
CLuc_letters <- names(CLuc_map)[order(names(CLuc_map))]

# Protein order (values sorted by letter order)
NLuc_levels <- unname(unlist(NLuc_map[NLuc_letters]))  # e.g. "AtMLO1", "AtMLO2", ...
CLuc_levels <- unname(unlist(CLuc_map[CLuc_letters]))  # e.g. "AtEXO70A1", ...

# Convenience aliases (legacy names you already use)
NLuc_proteins <- NLuc_levels
CLuc_proteins <- CLuc_levels

# Reverse maps: PROTEIN -> LETTER
nluc_letter_map <- setNames(NLuc_letters, NLuc_levels) # AtMLO3 -> "E"
cluc_letter_map <- setNames(CLuc_letters, CLuc_levels) # AtEXO70H7 -> "J"

# ────────────────────────────────────────────────────────────────────────────────
# 6) Auto-generate plotmath labels (expressions) from protein IDs
# ────────────────────────────────────────────────────────────────────────────────
# This returns an *expression()* element suitable for ggplot2 discrete axis labels.
# IMPORTANT: we use `*` (not `~`) to concatenate without spaces.
#
# Supported inputs (examples):
#   - "AtMLO12"     -> italic("At")*plain("MLO")*bold("12")
#   - "HvMlo" / "HvMlo1" -> italic("Hv")*bold("Mlo" / "Mlo1")
#   - "AtEXO70H7"   -> italic("At")*plain("EXO70")*bold("H7")
# Everything else falls back to plain(x).
make_label_expr <- function(x) {
  
  # AtMLO12 -> AtMLO12 (At italic, MLO plain, number bold)
  if (grepl("^AtMLO\\d+$", x)) {
    num <- sub("^AtMLO", "", x)
    return(bquote(italic("At")*plain("MLO")*bold(.(num))))
  }
  
  # HvMlo / HvMlo1 -> HvMlo (Hv italic, rest bold)
  if (grepl("^HvMlo", x)) {
    rest <- sub("^Hv", "", x)  # "Mlo" or "Mlo1" etc.
    return(bquote(italic("Hv")*bold(.(rest))))
  }
  
  # AtEXO70H7 -> AtEXO70H7 (At italic, EXO70 plain, suffix bold)
  if (grepl("^AtEXO70", x)) {
    suf <- sub("^AtEXO70", "", x)  # "H7"
    return(bquote(italic("At")*plain("EXO70")*bold(.(suf))))
  }
  
  # Fallback: show as plain text
  bquote(plain(.(x)))
}

# ────────────────────────────────────────────────────────────────────────────────
# 7) Axis label vectors (protein-keyed and letter-keyed)
# ────────────────────────────────────────────────────────────────────────────────
# You typically plot either:
#   A) protein IDs on axes (AtMLO3 / AtEXO70H7)  -> use *_protein
#   B) letter codes on axes (A..J)              -> use *_letter
#
# These vectors are named; names must match the values in your plotting columns.

# Protein-keyed label vectors (names are full protein IDs)
Lx_protein <- setNames(
  do.call("expression", lapply(CLuc_levels, make_label_expr)),
  CLuc_levels
)
Ly_protein <- setNames(
  do.call("expression", lapply(NLuc_levels, make_label_expr)),
  NLuc_levels
)

# Letter-keyed label vectors (names are letters A..J; values are protein-formatted expressions)
# NOTE: cluc_letter_map maps protein -> letter, so indexing by CLuc_levels preserves your configured order.
Lx_letter <- setNames(
  do.call("expression", lapply(CLuc_levels, make_label_expr)),
  cluc_letter_map[CLuc_levels]
)
Ly_letter <- setNames(
  do.call("expression", lapply(NLuc_levels, make_label_expr)),
  nluc_letter_map[NLuc_levels]
)

# Backwards-compatible defaults (your violin plots use letters on axes)
Lx <- Lx_letter
Ly <- Ly_letter

# ────────────────────────────────────────────────────────────────────────────────
# 7b) Suffix-only axis labels for CLuc letters (A..J -> "A1", "B2", ...)
#     This is what you want for violin plots where x is CLuc_Sample / Variable (letters).
# ────────────────────────────────────────────────────────────────────────────────
make_exo70_suffix_expr <- function(pid) {
  if (grepl("^AtEXO70", pid)) {
    suf <- sub("^AtEXO70", "", pid)      # "A1", "H7", ...
    return(bquote(plain(.(suf))))        # or bold(.(suf))
  }
  bquote(plain(.(pid)))
}

# letter-keyed: names are letters A..J, values show only suffix
Lx_suf <- setNames(
  do.call("expression", lapply(CLuc_levels, make_exo70_suffix_expr)),
  cluc_letter_map[CLuc_levels]   # <- IMPORTANT: names become A..J
)

# ────────────────────────────────────────────────────────────────────────────────
# 8) Axis title helper for violin plots (returns a plotmath *expression*)
#   - AtMLO#:  italic("At")*plain("MLO")*bold(#)
#   - HvMlo:   italic("Hv")*bold("Mlo")
#   - no spaces (uses *)
#   - right side fixed to "AtEXO70-"
# ────────────────────────────────────────────────────────────────────────────────
make_violin_axis_title <- function(nluc_full) {
  
  left_expr <- if (grepl("^AtMLO\\d+$", nluc_full)) {
    num <- sub("^AtMLO", "", nluc_full)
    bquote(italic("At")*plain("MLO")*bold(.(num)))
  } else if (grepl("^HvMlo", nluc_full)) {
    rest <- sub("^Hv", "", nluc_full)
    bquote(italic("Hv")*bold(.(rest)))
  } else {
    bquote(plain(.(nluc_full)))
  }
  
  # IMPORTANT: wrap as.expression() so ggplot stores it robustly (incl. in .rds)
  as.expression(
    bquote(
      .(left_expr)*
        plain("-NLuc/CLuc-")*
        italic("At")*plain("EXO70-")
    )
  )
}

# ────────────────────────────────────────────────────────────────────────────────
# 9) Optional: on-demand color mapping (AF3-style)
#    Creates a single named palette "Fill" that you can feed into:
#      scale_fill_manual(values = Fill) + scale_color_manual(values = Fill)
#
#    Convention:
#      Fill_box  in data should be "Box_<LETTER>"     (e.g. "Box_A")
#      Fill_point in data should be "Point_<LETTER>"  (e.g. "Point_A")
#      Fill_mean  in data should be "MPoint_<LETTER>" (e.g. "MPoint_A")
#
#    If config$Colors is missing, we fall back to reasonable defaults.
# ────────────────────────────────────────────────────────────────────────────────
Colors <- config$Colors %||% list()

# Box: default can be a single value used for all
box_default <- Colors$Box$default %||% "#FFFFFF"

# Helper: create a letter-keyed vector from either:
# - a named mapping (preferred): list(A="#..", B="#..", ...)
# - an unnamed vector/list: recycled in letter order
make_letter_palette <- function(x, letters, default = NA_character_) {
  if (is.null(x)) {
    return(setNames(rep(default, length(letters)), letters))
  }
  x_un <- unname(unlist(x))
  
  # named mapping
  if (!is.null(names(x))) {
    out <- x[letters]
    out <- unname(unlist(out))
    names(out) <- letters
    # fill missing with default
    out[is.na(out)] <- default
    return(out)
  }
  
  # unnamed vector/list recycled
  out <- rep(x_un, length.out = length(letters))
  setNames(out, letters)
}

col_box    <- setNames(rep(box_default, length(CLuc_letters)), CLuc_letters)
col_point  <- make_letter_palette(Colors$Point,  CLuc_letters, default = "#CCCCCC")
col_mpoint <- make_letter_palette(Colors$MPoint, CLuc_letters, default = "#777777")

# Combined palette used by ggplot manual scales
Fill <- c(
  setNames(unname(col_box),    paste0("Box_",    names(col_box))),
  setNames(unname(col_point),  paste0("Point_",  names(col_point))),
  setNames(unname(col_mpoint), paste0("MPoint_", names(col_mpoint)))
)

# ────────────────────────────────────────────────────────────────────────────────
# End of config_loader.R
# Objects exported into the calling script environment include:
#   out_dir, data_dir, sep, alpha, enforce_config_only
#   SLw, SLh, wHM, hHM
#   NLuc_map, CLuc_map, NLuc_letters, CLuc_letters, NLuc_levels, CLuc_levels
#   nluc_letter_map, cluc_letter_map
#   make_label_expr, Lx, Ly, Lx_letter, Ly_letter, Lx_protein, Ly_protein
#   violin_right_partner, make_violin_axis_title
#   Fill
# ────────────────────────────────────────────────────────────────────────────────
