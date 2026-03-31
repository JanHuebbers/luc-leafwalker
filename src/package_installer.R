# src/R/install_r_packages.R

# Set CRAN mirror explicitly
options(repos = c(CRAN = "https://cloud.r-project.org"))

# CRAN packages not included in r-essentials
# CRAN packages not included in r-essentials
cran_pkgs <- c(
  "ggdist", "gtools", "multcompView", "openxlsx", "patchwork", "pheatmap", "psych", "rstatix"
)

for (pkg in cran_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
}
