# ==============================================================================
# PROJECT: AQI TrustLens - Chennai Air Quality & Data Reliability Dashboard
# SCRIPT: R/analysis.R
# PURPOSE: Statistical analysis, before-and-after cleaning comparison, and
#          summary reporting on raw vs clean Chennai air quality data.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(tibble)
})

# Source prerequisites if running standalone
if (!exists("import_all_raw_data")) {
  source("R/data_import.R")
}
if (!exists("clean_and_audit_data")) {
  source("R/data_cleaning.R")
}

#' Helper to compute summary statistics for a numeric vector
compute_metric_stats <- function(vec, total_n) {
  valid_vec <- vec[!is.na(vec)]
  n_valid <- length(valid_vec)
  n_missing <- total_n - n_valid
  pct_missing <- if (total_n > 0) round((n_missing / total_n) * 100, 2) else 0
  
  if (n_valid == 0) {
    return(tibble(
      Valid_Count = 0,
      Missing_Count = n_missing,
      Missing_Pct = pct_missing,
      Mean = NA_real_,
      Median = NA_real_,
      SD = NA_real_,
      IQR = NA_real_,
      P95 = NA_real_
    ))
  }
  
  tibble(
    Valid_Count = n_valid,
    Missing_Count = n_missing,
    Missing_Pct = pct_missing,
    Mean = round(mean(valid_vec), 2),
    Median = round(median(valid_vec), 2),
    SD = round(sd(valid_vec), 2),
    IQR = round(IQR(valid_vec), 2),
    P95 = round(quantile(valid_vec, 0.95, names = FALSE), 2)
  )
}

#' Generate overall descriptive statistics per station & pollutant
calculate_station_pollutant_stats <- function(df_data) {
  pollutants <- c("SO2_Numeric", "NO2_Numeric", "CO_Numeric", "PM25_Numeric", "PM10_Numeric", "AQI_Numeric")
  display_names <- c("SO2", "NO2", "CO", "PM2.5", "PM10", "AQI")
  
  results <- list()
  stations <- sort(unique(df_data$Station))
  
  for (st in stations) {
    st_df <- df_data %>% filter(Station == st)
    total_n <- nrow(st_df)
    
    for (i in seq_along(pollutants)) {
      p_col <- pollutants[i]
      p_name <- display_names[i]
      
      stats <- compute_metric_stats(st_df[[p_col]], total_n)
      stats <- stats %>%
        mutate(
          Station = st,
          Pollutant = p_name,
          .before = 1
        )
      results[[length(results) + 1]] <- stats
    }
  }
  
  bind_rows(results)
}

#' Compare statistics BEFORE vs AFTER justified data cleaning
#' Justified Cleaning Rules:
#'  1. Before Cleaning (Raw Ingest):
#'     - Includes duplicate date+station entries
#'     - Textual errors / hardware issue strings were coerced to NA during numeric conversion
#'  2. After Cleaning:
#'     - Excludes verified duplicate Date+Station observations
#'     - Preserves physical spikes and inversions for audit, but filters out duplicate rows
compare_before_after <- function(df_audited) {
  pollutants <- c("SO2_Numeric", "NO2_Numeric", "CO_Numeric", "PM25_Numeric", "PM10_Numeric", "AQI_Numeric")
  display_names <- c("SO2", "NO2", "CO", "PM2.5", "PM10", "AQI")
  
  # Dataset 1: Before Cleaning (Raw uncurated rows, including duplicates)
  df_before <- df_audited
  
  # Dataset 2: After Justified Cleaning (Deduplicated, retaining non-duplicate valid observations)
  # Keeping duplicates out because duplicate entries double-count specific days
  df_after <- df_audited %>%
    filter(!Is_Duplicate | !duplicated(select(., Date, Station)))
  
  comparison_list <- list()
  
  for (i in seq_along(pollutants)) {
    p_col <- pollutants[i]
    p_name <- display_names[i]
    
    stats_before <- compute_metric_stats(df_before[[p_col]], nrow(df_before)) %>%
      mutate(Stage = "Before Cleaning (Raw Ingest)", Pollutant = p_name, Records = nrow(df_before))
    
    stats_after <- compute_metric_stats(df_after[[p_col]], nrow(df_after)) %>%
      mutate(Stage = "After Cleaning (Deduplicated)", Pollutant = p_name, Records = nrow(df_after))
    
    # Calculate absolute and percent shifts
    delta_mean <- round(stats_after$Mean - stats_before$Mean, 3)
    delta_median <- round(stats_after$Median - stats_before$Median, 3)
    
    comp_row <- bind_rows(stats_before, stats_after) %>%
      mutate(
        Delta_Mean = c(NA, delta_mean),
        Delta_Median = c(NA, delta_median)
      )
    
    comparison_list[[length(comparison_list) + 1]] <- comp_row
  }
  
  bind_rows(comparison_list)
}

#' Run full analysis pipeline and export results to data/processed and outputs/
run_full_analysis <- function() {
  # 1. Ingest
  df_raw <- import_all_raw_data("data/raw")
  
  # 2. Clean & Audit
  df_audited <- clean_and_audit_data(df_raw)
  
  # 3. Save processed curated data
  dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
  dir.create("outputs/reports", showWarnings = FALSE, recursive = TRUE)
  
  write_csv(df_audited, "data/processed/chennai_aqi_audited.csv")
  
  # 4. Compute station-level pollutant statistics
  station_stats <- calculate_station_pollutant_stats(df_audited)
  write_csv(station_stats, "outputs/reports/station_pollutant_statistics.csv")
  
  # 5. Compute before-and-after comparison
  before_after_stats <- compare_before_after(df_audited)
  write_csv(before_after_stats, "outputs/reports/before_after_cleaning_comparison.csv")
  
  # 6. Quality flag breakdown report
  flags_summary <- tibble(
    Metric = c(
      "Total Ingested Records",
      "Total Duplicate Entries",
      "Hardware / Maintenance Notes",
      "PM Inversions (PM2.5 > PM10 * 1.05)",
      "Total Flagged Suspicious Records",
      "Distinct Stations",
      "Date Range Start",
      "Date Range End"
    ),
    Value = c(
      as.character(nrow(df_audited)),
      as.character(sum(df_audited$Is_Duplicate, na.rm = TRUE)),
      as.character(sum(df_audited$Hardware_Issue_Flag, na.rm = TRUE)),
      as.character(sum(df_audited$Flag_PMRatio_Inversion, na.rm = TRUE)),
      as.character(sum(df_audited$Is_Suspicious, na.rm = TRUE)),
      as.character(n_distinct(df_audited$Station)),
      as.character(min(df_audited$Date, na.rm = TRUE)),
      as.character(max(df_audited$Date, na.rm = TRUE))
    )
  )
  write_csv(flags_summary, "outputs/reports/data_quality_flags_summary.csv")
  
  message("Stage 3 Analysis complete. Reports generated in outputs/reports/ and data/processed/")
  return(list(
    audited_data = df_audited,
    station_stats = station_stats,
    before_after = before_after_stats,
    quality_summary = flags_summary
  ))
}

# If executed directly via Rscript
if (!interactive()) {
  run_full_analysis()
}
