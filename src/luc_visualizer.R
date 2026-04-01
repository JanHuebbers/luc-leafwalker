source("./src/package_loader.R")
config_path <- "./config/20260209_AtMLO_AtEXO70.yml"  # change if needed
source("./src/config_loader.R")
source("./src/ggplot_theme.R")

# Specify the path to your Excel file
file_path <- "./Data/lum_long_MLOEXO70.csv"

# A helper that converts a triangular data set to a matrix.
# Important for "multicomp_letters", which converts p-values into letters.
tri.to.squ <- function(x) {
  rn <- row.names(x)
  cn <- colnames(x)
  an <- unique(c(cn, rn))
  myval <- x[!is.na(x)]
  mymat <- matrix(1, nrow = length(an), ncol = length(an), dimnames = list(an, an))
  for (ext in 1:length(cn)) {
    for (int in 1:length(rn)) {
      if (is.na(x[row.names(x) == rn[int], colnames(x) == cn[ext]])) next
      mymat[row.names(mymat) == rn[int], colnames(mymat) == cn[ext]] <- x[row.names(x) == rn[int], colnames(x) == cn[ext]]
      mymat[row.names(mymat) == cn[ext], colnames(mymat) == rn[int]] <- x[row.names(x) == rn[int], colnames(x) == cn[ext]]
    }
  }
  return(mymat)
}

# Read .csv with luminescence values
remove_outliers_range <- function(df, col = "value", low = -0.05, high = 2.0) {
  df %>% dplyr::filter(dplyr::between(.data[[col]], low, high))
}

data <- read.csv(file_path, check.names = FALSE) %>%
  dplyr::select(-dplyr::matches("^Unnamed")) %>% 
  dplyr::mutate(value = VpA_norm) %>%
  dplyr::filter(!is.na(value)) %>%
  dplyr::relocate(value, .after = CLuc) %>%
  dplyr::filter(
    NLuc %in% NLuc_levels,
    CLuc %in% CLuc_levels
  ) %>%
  dplyr::mutate(
    NLuc_Sample = purrr::map_chr(as.character(NLuc), ~ nluc_letter_map[[.x]] %||% default_smp),
    CLuc_Sample = purrr::map_chr(as.character(CLuc), ~ cluc_letter_map[[.x]] %||% default_smp)
  ) %>%
  remove_outliers_range(col = "value", low = -0.05, high = 2.0) %>%
  dplyr::group_by(NLuc, CLuc) %>%
  tidyr::nest() %>%
  dplyr::mutate(ypos = purrr::map_dbl(data, ~ max(.x$value, na.rm = TRUE))) %>%
  tidyr::unnest(data) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(ID = dplyr::row_number()) %>%
  dplyr::mutate(value = as.numeric(value)) %>%
  dplyr::relocate(ID, .before = NLuc)

print(data)
print(sapply(data, class))
print(unique(data$NLuc))
print(unique(data$CLuc_Sample))


# E (CLuc per NLuc) = number of unique (col2, col3) combos; S (number of different samples) = unique values in col3
E <- data %>% distinct(across(2:3))   %>% nrow()
S <- data %>% distinct(across(3))     %>% nrow()

readr::write_csv(data, file.path(out_dir, "lum_curated.csv"))

# Descriptive statistics (e.g., mean, standard deviation)
# Input data frame for descriptive statistics
data_desc_01 <- data %>%
  dplyr::group_by(NLuc, CLuc_Sample, Experiment) %>%
  dplyr::summarise(
    mean = mean(value, na.rm = TRUE),
    sd = sd(value, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::mutate(ID = dplyr::row_number()) %>%
  dplyr::mutate(NLuc = forcats::fct_reorder(NLuc, ID)) %>%
  dplyr::relocate(ID, .before = NLuc) %>%
  tidyr::drop_na() %>%
  dplyr::arrange(NLuc)
print(data_desc_01)
# Input data frame for heat map
data_desc_02 <- data %>%
  dplyr::group_by(NLuc, CLuc_Sample) %>%
  dplyr::summarise(
    mean = mean(value, na.rm = TRUE),
    sd = sd(value, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::mutate(ID = dplyr::row_number()) %>%
  dplyr::mutate(NLuc = forcats::fct_reorder(NLuc, ID)) %>%
  dplyr::relocate(ID, .before = NLuc) %>%
  tidyr::drop_na() %>%
  dplyr::arrange(NLuc)

# Input data frame for 
data_desc_03 <- data %>%
  dplyr::group_by(NLuc, CLuc) %>%
  dplyr::summarise(
    mean = mean(value, na.rm = TRUE),
    sd = sd(value, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::mutate(ID = dplyr::row_number()) %>%
  dplyr::mutate(NLuc = forcats::fct_reorder(NLuc, ID)) %>%
  dplyr::relocate(ID, .before = NLuc) %>%
  tidyr::drop_na() %>%
  dplyr::arrange(NLuc)

readr::write_csv(data_desc_01, file.path(out_dir, "data_desc_01.csv"))
readr::write_csv(data_desc_02, file.path(out_dir, "data_desc_02.csv"))
readr::write_csv(data_desc_03, file.path(out_dir, "data_desc_03.csv"))

#Test for normal distribution and homogeneity of variances
data_para <- data_desc_01 %>%
      #Shapiro-Wilk-Test
      group_by(NLuc, CLuc_Sample) %>%
      nest() %>%
      mutate(Normal_dist = map(.x = data, ~shapiro_test(mean, data = .x) %>%  tibble())) %>%
      unnest(Normal_dist) %>% 
      unnest(data) %>%
      rename(p_shapiro = p) %>% 
      select(-c(variable, statistic)) %>%
      #Levene-Test
      group_by(NLuc) %>% 
      nest() %>%
      mutate(Equal_var = map(.x = data, ~levene_test(mean ~ CLuc_Sample, data = .x))) %>%
      unnest(Equal_var) %>% 
      select(NLuc, data, p) %>%
      unnest(data) %>% 
      rename(p_levene = p)
data_norm <- data_para %>% 
      group_by(NLuc, CLuc_Sample, p_shapiro, p_levene) %>% 
      nest %>%
      select(-c(data)) %>%
      tibble() %>%
      mutate(ID = row_number())
      
non_Norm <- data_norm %>% 
      filter(p_shapiro <= 0.05) %>%
      group_by(NLuc, CLuc_Sample, p_shapiro) %>% 
      nest()

# qqPlot
data_qq <- data_para %>%
  group_by(NLuc, CLuc_Sample) %>%
  nest()

qqplot_fun <- function(data = data, x, title, subtitle) {
  ggplot(data = data, aes(sample = .data[[x]])) +
    stat_qq() +
    stat_qq_line() +
    ggtitle(label = title, subtitle = subtitle)
}

plots <- data_qq %>%
  mutate(plots = map(.x = data, ~ qqplot_fun(x = "mean", title = NLuc, subtitle = CLuc_Sample, data = .x))) %>%
  mutate(aligned = map(.x = plots, ~ align_plots(align = "hv", axis = "tblr", data = .x)))

plot <- plots$plots

# Pairwise t-Test (~pairwise.t.test) or Mann Whitney U Test (~pairwise.wilcox.test)
posthoc_q <- data_desc_01 %>%
  group_by(NLuc) %>%
  nest() %>%
  mutate(posthoc = map(.x = data, ~ pairwise.t.test(
    x = .x$mean,
    g = .x$CLuc_Sample,
    p.adjust.method = "fdr",
    alternative = "two.sided",
    data = .x,
    paired = FALSE,
    exact = TRUE
  ))) %>%
  mutate(pV = map(.x = posthoc, ~ tri.to.squ(.x$p.value))) %>%
  mutate(pVal = map(.x = pV, ~ data.matrix(.x))) %>%
  mutate(q = map(.x = pVal, ~ as.tibble(.x, rownames = NA))) %>%
  mutate(q = map(.x = q, ~ rownames_to_column(.x, var = "CLuc_Sample")))

posthoc <- posthoc_q %>%
  mutate(letter = map(.x = pVal, ~ multcompLetters(.x, compare = "<", threshold = alpha, reversed = FALSE))) %>%
  mutate(letter = map(.x = letter, ~ data.frame(.x$Letters))) %>%
  select(NLuc, letter, data)

letters <- posthoc %>%
  select(NLuc, letter) %>%
  unnest(letter) %>%
  ungroup() %>%
  mutate(ID = row_number())

data_02 <- posthoc %>%
  select(NLuc, data) %>%
  unnest(data) %>%
  ungroup()

# A data frame that is used to combine letters and samples
asterisks <- data_02 %>%
  select(NLuc, CLuc_Sample, mean) %>%
  drop_na(mean) %>%
  group_by(NLuc, CLuc_Sample) %>%
  nest() %>%
  mutate(ypos = map(.x = data, ~ max(.x$mean, na.rm = FALSE))) %>%
  ungroup() %>%
  select(NLuc, CLuc_Sample, ypos) %>%
  mutate(ID = row_number()) %>%
  left_join(letters, by = "ID") %>%
  select(NLuc.x, CLuc_Sample, ypos, .x.Letters) %>%
  mutate(ypos = as.numeric(ypos)) %>%
  mutate(ID = row_number()) %>%
  rename(NLuc = NLuc.x) %>%
  add_column(Experiment = rep("1", E)) %>%
  mutate(Experiment = factor(Experiment)) %>%
  add_column(Replicate = rep("1", E)) %>%
  mutate(Replicate = factor(Replicate)) %>%
  group_by(CLuc_Sample) %>%
  nest() %>%
  add_column(CLuc_proteins) %>%
  unnest() %>%
  rename(CLuc = CLuc_proteins)

data_name <- data %>%
  group_by(NLuc, CLuc) %>%
  nest()

stats_sum <- data_norm %>%
  left_join(asterisks, by = c("NLuc", "CLuc_Sample")) %>%
  select(-c(ypos, ID.y)) %>%
  rename(c(Letters = .x.Letters, ID = ID.x)) %>%
  relocate(ID, .before = NLuc) %>%
  left_join(data_desc_02, by = c("NLuc", "CLuc_Sample")) %>%
  select(-c(Experiment, Replicate, ID.y)) %>%
  rename(c(ID = ID.x))

stats_sum$CLuc <- data_name$CLuc

stats_sum <- stats_sum %>%
  relocate(CLuc, .before = CLuc_Sample)

# Save as csv
write.table(stats_sum, file = file.path(out_dir, "06_stats_sum.csv"), row.names = FALSE, sep = sep)

# Loop through the list of tables and save each table
for (i in seq_len(nrow(posthoc_q))) {
  nested_df <- posthoc_q$q[[i]]
  file_name <- paste0(posthoc_q$NLuc[i], ".csv")
  file_path <- file.path(data_dir, file_name)
  write.table(nested_df, file = file_path, row.names = FALSE, quote = TRUE, sep = sep)
}

# Assumes you've sourced config_loader.R already
if (isTRUE(enforce_config_only)) {
  data <- data %>%
    dplyr::filter(
      NLuc %in% NLuc_levels,
      CLuc_Sample %in% CLuc_letters
    )
}

Data_plot <- data %>%
  dplyr::select(-dplyr::any_of("ID")) %>%
  dplyr::mutate(
    CLuc = gsub("\\..*", "", CLuc),
    Experiment = factor(Experiment),
    Replicate = factor(Replicate),
    Variable = factor(CLuc_Sample, levels = CLuc_letters)
  ) %>%
  dplyr::left_join(
    asterisks,
    by = c("NLuc", "CLuc_Sample", "Experiment", "Replicate", "CLuc")
  ) %>%
  dplyr::rename(asterisks = .x.Letters) %>%
  dplyr::mutate(
    Fill_box   = paste0("Box_", as.character(Variable)),
    Fill_point = paste0("Point_", as.character(Variable)),
    Fill_mean  = paste0("MPoint_", as.character(Variable))
  ) %>%
  dplyr::group_by(NLuc) %>%
  tidyr::nest()

plot_fun <- function(data, x, y, xlim, f, labs_x_expr, axis_title_expr) {
  ggplot(data = data, aes(x = .data[[x]], y = .data[[y]])) +
    geom_hline(yintercept = 1, linetype = "dashed", color = "#646567") +
    annotate(
      "text",
      x = xlim[1],
      y = 1.01,
      label = expression(paste(italic("At"), plain("CAM2"))),
      hjust = 0.4, vjust = -0.5, size = 2
    ) +
    geom_violin(
      alpha = 0.8, width = 0.75,
      position = position_dodge(width = 0.75),
      scale = "width",
      linewidth = 0.4, color = "#000000",
      aes(fill = Fill_box)
    ) +
    geom_star(
      aes(starshape = Experiment, size = Experiment, fill = Fill_point),
      alpha = 0.50, color = "#000000", stroke = 0.3,
      position = position_nudge(x = c(-0.20, -0.15, 0.15, 0.20))
    ) +
    stat_summary(
      color = "#000000",
      geom = "crossbar",
      linewidth = 0.5,
      fun = median,
      width = 0.70
    ) +
    stat_summary(
      aes(starshape = Experiment, fill = Fill_mean),
      color = "#000000",
      geom = "star",
      size = 1.6,
      stroke = 0.4,
      alpha = 0.95,
      fun = mean
    ) +
    geom_text(
      aes(label = asterisks, y = -0.15),
      size = 2.5
    ) +
    scale_x_discrete(
      labels = labs_x_expr,
      limits = xlim,
      name = axis_title_expr
    ) +
    scale_y_continuous(
      breaks = seq(0, 2.0, 0.2),
      limits = c(-0.15, 2.05),
      name = expression(paste(plain("Luminescence relative to "), italic("At"), bold("CAM2"))),
      expand = c(0.01, 0.01)
    ) +
    coord_cartesian(ylim = c(-0.20, 2.1)) +
    scale_color_manual(values = f) +
    scale_fill_manual(values = f) +
    scale_starshape_manual(
      limits = factor(1:12, levels = 1:12),
      values = setNames(c(15, 13, 28, 11, 23, 1, 2, 4, 5, 29, 24, 27), 1:12)
    ) +
    scale_size_manual(
      limits = factor(1:12, levels = 1:12),
      values = setNames(rep(0.8, 12), 1:12)
    ) +
    guides(fill = "none", color = "none", size = "none", shape = "none",
           starshape = "none", alpha = "none")
}

plots_tbl <- Data_plot %>%
  dplyr::mutate(
    axis_title_expr = purrr::map(NLuc, make_violin_axis_title),
    plot = purrr::map2(
      data, axis_title_expr,
      ~ plot_fun(
        data = .x,
        x = "Variable",
        y = "value",
        xlim = names(Lx),
        f = Fill,
        labs_x_expr = Lx_suf,
        axis_title_expr = .y
      )
    )
  )

plot_list <- plots_tbl$plot

# Save plots as .svg and .rds
save_dir <- out_dir
dir.create(save_dir, recursive = TRUE, showWarnings = FALSE)

safe_name <- function(x) gsub("[^A-Za-z0-9_\\-]+", "_", x)

for (i in seq_along(plot_list)) {
  n_raw <- as.character(plots_tbl$NLuc[i])
  n <- safe_name(n_raw)

  svg_name <- paste0("P10_Violin_", n, ".svg")
  ggplot2::ggsave(
    filename = file.path(save_dir, svg_name),
    plot = plot_list[[i]],
    width = SLw,
    height = SLh,
    units = "cm",
    limitsize = FALSE
  )

  rds_name <- paste0("P10_Violin_", n, ".rds")
  saveRDS(
    object = plot_list[[i]],
    file = file.path(save_dir, rds_name)
  )
}

# Heatmap from mean(value) for each NLuc × CLuc pair
data_hm <- data %>%
  dplyr::group_by(NLuc_Sample, CLuc_Sample) %>%
  dplyr::summarise(
    mean = mean(value, na.rm = TRUE),
    sd   = sd(value, na.rm = TRUE),
    n    = dplyr::n(),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    CLuc_Sample = factor(CLuc_Sample, levels = names(Lx)),
    NLuc_Sample = factor(NLuc_Sample, levels = names(Ly))
  )

plot_heatmap <- function(df, x = "CLuc", y = "NLuc") {
  ggplot2::ggplot(df, ggplot2::aes(x = .data[[x]], y = .data[[y]])) +
    ggplot2::geom_tile(ggplot2::aes(fill = mean), color = "#000000", linewidth = 0.25) +
    ggplot2::geom_text(
      ggplot2::aes(label = ifelse(is.na(mean), "", sprintf("%.2f", mean))),
      color = "white", size = 2.2
    ) +
    ggplot2::scale_x_discrete(
      labels = Lx,
      limits = names(Lx),
      expand = c(0, 0),
      name = NULL
    ) +
    ggplot2::scale_y_discrete(
      labels = Ly,
      limits = rev(names(Ly)),
      expand = c(0, 0),
      name = NULL
    ) +
    ggplot2::scale_fill_gradientn(
      colours = c("#0098A1", "#00B1B7", "#FABE50", "#F6A800"),
      values = c(0, 0.1, 0.5, 1.0),
      oob = scales::squish,
      na.value = "white"
    ) +
    ggplot2::coord_cartesian() +
    ggplot2::guides(fill = "none")
}

Heatmap_plot <- plot_heatmap(
  df = data_hm,
  x = "CLuc_Sample",
  y = "NLuc_Sample"
)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

saveRDS(
  object = Heatmap_plot,
  file = file.path(out_dir, "Heatmap_NLucXCLuc_mean.rds")
)

ggplot2::ggsave(
  filename = file.path(out_dir, "Heatmap_NLucXCLuc_mean.svg"),
  plot = Heatmap_plot,
  width = SLw,
  height = SLh,
  units = "cm",
  limitsize = FALSE
)