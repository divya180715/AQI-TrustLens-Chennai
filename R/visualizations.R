# ==============================================================================
# PROJECT: AQI TrustLens - Chennai Air Quality & Data Reliability Dashboard
# SCRIPT: R/visualizations.R
# PURPOSE: Modular ggplot2 visualizations for Chennai pollution patterns,
#          data-quality / reliability auditing, and category distributions.
#          Styled for a clean, professional, high-contrast light theme with
#          teal & dark navy palette suitable for MCA academic evaluation.
# ==============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(scales)
  library(readr)
})

# Refined station color palette: High contrast on light background
STATION_PALETTE <- c(
  "Kodungaiyur" = "#0284C7", # Ocean Blue
  "Koyambedu"   = "#D97706", # Warm Amber
  "Manali"      = "#DC2626", # Industrial Crimson
  "Perungudi"   = "#0D9488", # Deep Teal
  "Royapuram"   = "#7C3AED"  # Royal Violet
)

# CPCB Standard AQI Category Palette (National Standard Colors)
AQI_CATEGORY_PALETTE <- c(
  "Good"         = "#16A34A", # Green (0-50)
  "Satisfactory" = "#65A30D", # Light Green (51-100)
  "Moderate"     = "#EAB308", # Yellow (101-200)
  "Poor"         = "#F97316", # Orange (201-300)
  "Very Poor"    = "#DC2626", # Red (301-400)
  "Severe"       = "#7F1D1D"  # Dark Maroon (401-500)
)

# Professional academic light theme
theme_trustlens_light <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = base_size + 2, color = "#0F172A", margin = margin(b = 6)),
      plot.subtitle = element_text(size = base_size - 1, color = "#475569", margin = margin(b = 12)),
      plot.caption = element_text(size = base_size - 3, color = "#64748B", margin = margin(t = 10)),
      axis.title = element_text(face = "bold", size = base_size, color = "#1E293B"),
      axis.text = element_text(size = base_size - 1, color = "#334155"),
      legend.title = element_text(face = "bold", size = base_size - 1, color = "#0F172A"),
      legend.text = element_text(size = base_size - 1, color = "#334155"),
      legend.position = "bottom",
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "#E2E8F0", linewidth = 0.6),
      panel.background = element_rect(fill = "#FFFFFF", color = NA),
      plot.background = element_rect(fill = "#FFFFFF", color = NA),
      plot.margin = margin(12, 16, 12, 12)
    )
}

# Standard alias
theme_trustlens <- theme_trustlens_light

# ==============================================================================
# 1. Pollution Trends Over Time
# ==============================================================================
plot_pollution_trend <- function(df_data, pollutant_col = "AQI_Numeric", 
                                 pollutant_label = "AQI (Index Value)", 
                                 selected_stations = NULL) {
  df_plot <- df_data
  if (!is.null(selected_stations) && length(selected_stations) > 0) {
    df_plot <- df_plot %>% filter(Station %in% selected_stations)
  }
  
  df_plot <- df_plot %>%
    filter(!is.na(Date), !is.na(.data[[pollutant_col]]))
  
  p <- ggplot(df_plot, aes(x = as.Date(Date), y = .data[[pollutant_col]], color = Station)) +
    geom_line(alpha = 0.85, linewidth = 0.85) +
    scale_color_manual(values = STATION_PALETTE) +
    scale_x_date(date_breaks = "2 month", date_labels = "%b %Y") +
    labs(
      title = paste("Chennai Ambient Air Quality:", pollutant_label, "Timeline (2023–2024)"),
      subtitle = "Continuous multi-station historical telemetry. Nov/Dec elevated periods coincide with post-monsoon weather patterns and festival activities.",
      x = "Date of Observation",
      y = pollutant_label,
      color = "Monitoring Station",
      caption = "Source: CPCB / OpenCity Chennai Historical Archive. Deduplicated observations. Meteorological and source factors require further investigation."
    ) +
    theme_trustlens_light() +
    theme(axis.text.x = element_text(angle = 25, hjust = 1))
  
  return(p)
}

# ==============================================================================
# 2. Station-Wise Pollution Comparison (Box Plot & Outlier Spread)
# ==============================================================================
plot_station_comparison <- function(df_data, pollutant_col = "AQI_Numeric",
                                    pollutant_label = "AQI (Index Value)") {
  df_plot <- df_data %>%
    filter(!is.na(Station), !is.na(.data[[pollutant_col]]))
  
  station_order <- df_plot %>%
    group_by(Station) %>%
    summarise(med = median(.data[[pollutant_col]], na.rm = TRUE), .groups = "drop") %>%
    arrange(desc(med)) %>%
    pull(Station)
  
  df_plot$Station <- factor(df_plot$Station, levels = station_order)
  
  p <- ggplot(df_plot, aes(x = Station, y = .data[[pollutant_col]], fill = Station)) +
    geom_boxplot(outlier.alpha = 0.6, outlier.size = 2, outlier.color = "#DC2626", width = 0.55, color = "#1E293B", alpha = 0.85) +
    stat_summary(fun = mean, geom = "point", shape = 18, size = 4, color = "#0F172A") +
    scale_fill_manual(values = STATION_PALETTE) +
    labs(
      title = paste("Station-Wise Distribution of", pollutant_label),
      subtitle = "Boxes show Median (solid line) & IQR; Black diamonds denote Mean; Red points represent statistical outliers.",
      x = "Continuous Monitoring Station (Ranked by Median)",
      y = pollutant_label,
      fill = "Station",
      caption = "Variations illustrate localized environmental contexts. Distribution differences do not establish direct causation."
    ) +
    theme_trustlens_light() +
    guides(fill = "none")
  
  return(p)
}

# ==============================================================================
# 3. Data Quality Heatmap: Missingness & Hardware Failure Auditing
# ==============================================================================
plot_data_quality_heatmap <- function(station_stats_file = "outputs/reports/station_pollutant_statistics.csv") {
  df_stats <- read_csv(station_stats_file, show_col_types = FALSE)
  
  p <- ggplot(df_stats, aes(x = Pollutant, y = Station, fill = Missing_Pct)) +
    geom_tile(color = "#FFFFFF", linewidth = 1.2) +
    geom_text(aes(label = paste0(Missing_Pct, "%\n(", Missing_Count, " NA)")), size = 3.6, fontface = "bold", color = ifelse(df_stats$Missing_Pct > 35, "#FFFFFF", "#0F172A")) +
    scale_fill_gradient(
      low = "#F1F5F9", 
      high = "#DC2626", 
      limits = c(0, 100),
      name = "Missing Data %"
    ) +
    labs(
      title = "Data Quality Audit: Missingness by Station & Pollutant",
      subtitle = "Identifies systematic monitoring blindspots (e.g., prolonged CO sensor downtime at Koyambedu at 45.0% NA / 268 days).",
      x = "Monitored Criteria Pollutant",
      y = "Continuous Monitoring Station",
      caption = "Audit based on 2,975 station-day records. Source: OpenCity / CPCB Archive."
    ) +
    theme_trustlens_light() +
    theme(
      axis.text.x = element_text(face = "bold", color = "#0F172A", size = 11),
      axis.text.y = element_text(face = "bold", color = "#0F172A", size = 11),
      legend.position = "right"
    )
  
  return(p)
}

# ==============================================================================
# 4. Before-and-After Cleaning Comparison
# ==============================================================================
plot_before_after_comparison <- function(comp_file = "outputs/reports/before_after_cleaning_comparison.csv") {
  df_comp <- read_csv(comp_file, show_col_types = FALSE) %>%
    filter(Pollutant %in% c("PM2.5", "PM10", "AQI"))
  
  p <- ggplot(df_comp, aes(x = Pollutant, y = Mean, fill = Stage)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.7), width = 0.58, color = "#1E293B", linewidth = 0.4) +
    geom_text(
      aes(label = paste0("Mean: ", Mean, "\nMed: ", Median)),
      position = position_dodge(width = 0.7),
      vjust = -0.3,
      size = 3.4,
      fontface = "bold",
      color = "#0F172A"
    ) +
    scale_fill_manual(values = c("Before Cleaning (Raw Ingest)" = "#94A3B8", "After Cleaning (Deduplicated)" = "#0284C7")) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.2))) +
    labs(
      title = "Metric Comparison: Before vs. After Documented Deduplication",
      subtitle = "Shows empirical stability after removing 16 duplicate records (Overall Mean AQI shifted from 67.09 to 66.97).",
      x = "Pollutant Parameter",
      y = "Mean Concentration / Index Value",
      fill = "Dataset State",
      caption = "Deduplication corrects statistical double-counting. It does not certify that remaining observations are noise-free."
    ) +
    theme_trustlens_light()
  
  return(p)
}

# ==============================================================================
# 5. CPCB AQI Category Breakdown by Station (Stacked Bar)
# ==============================================================================
plot_aqi_category_distribution <- function(df_data) {
  cat_levels <- c("Good", "Satisfactory", "Moderate", "Poor", "Very Poor", "Severe")
  
  df_cat <- df_data %>%
    filter(!is.na(AQI_Category), AQI_Category %in% cat_levels) %>%
    mutate(AQI_Category = factor(AQI_Category, levels = cat_levels)) %>%
    count(Station, AQI_Category) %>%
    group_by(Station) %>%
    mutate(Pct = round((n / sum(n)) * 100, 1)) %>%
    ungroup()
  
  p <- ggplot(df_cat, aes(x = Station, y = Pct, fill = AQI_Category)) +
    geom_bar(stat = "identity", position = "stack", width = 0.62, color = "#FFFFFF", linewidth = 0.6) +
    scale_fill_manual(values = AQI_CATEGORY_PALETTE, name = "CPCB Health Band") +
    scale_y_continuous(labels = function(x) paste0(x, "%"), expand = c(0, 0)) +
    labs(
      title = "CPCB Air Quality Category Breakdown by Monitoring Station",
      subtitle = "Proportion of days classified under each National Air Quality Index health tier (2023–2024).",
      x = "Monitoring Station",
      y = "Proportion of Observed Days (%)",
      caption = "Satisfactory (51-100) and Moderate (101-200) days account for the vast majority of Chennai observations."
    ) +
    theme_trustlens_light() +
    theme(legend.position = "right")
  
  return(p)
}
