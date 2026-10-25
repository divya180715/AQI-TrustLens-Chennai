# ==============================================================================
# PROJECT: AQI TrustLens - Chennai Air Quality & Data Reliability Dashboard
# SCRIPT: R/data_cleaning.R
# PURPOSE: Non-destructive data validation, suspicious-value checks, 
#          auditing, and documented cleaning pipeline.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(readr)
})

# Known realistic thresholds for Indian urban air quality (CPCB / WHO guidelines)
# Values exceeding these are flagged as extreme anomalies or spikes
THRESHOLDS <- list(
  SO2 = list(min = 0, max = 500),
  NO2 = list(min = 0, max = 500),
  CO  = list(min = 0, max = 50),
  PM2.5 = list(min = 0, max = 999),
  PM10 = list(min = 0, max = 1000),
  AQI = list(min = 0, max = 500)
)

#' Non-destructive data cleaning and audit pipeline
#' Preserves all raw text columns while creating clean numeric versions and flags
clean_and_audit_data <- function(df_raw) {
  
  df_audit <- df_raw %>%
    mutate(
      # 1. Duplicate Detection: Check for duplicate Station + Date combinations
      Is_Duplicate = duplicated(select(., Date, Station)) | duplicated(select(., Date, Station), fromLast = TRUE),
      
      # 2. Flag hardware/power/cyclone issues explicitly recorded in notes
      # (e.g. "PC Issue", "EB Issue", "Cyclone effect", "Michaung Cyclone")
      Hardware_Issue_Flag = if_any(
        c(SO2, NO2, CO, PM2.5, PM10, `AQI Index`),
        ~ str_detect(coalesce(., ""), regex("PC Issue|P/C Problem|EB Issue|Power cut|Maintenance|Cyclone", ignore_case = TRUE))
      ),
      
      # 3. Clean and parse individual pollutants into numeric
      # Helper regex to clean typos like "`34" or "0..6"
      SO2_Clean_Str = str_trim(SO2),
      NO2_Clean_Str = str_trim(NO2),
      CO_Clean_Str  = str_replace_all(str_trim(CO), "0\\.\\.6", "0.6"),
      PM25_Clean_Str = str_trim(`PM2.5`),
      PM10_Clean_Str = str_replace_all(str_trim(PM10), "^`", ""),
      AQI_Clean_Str  = str_trim(`AQI Value`)
    ) %>%
    mutate(
      # Parse numerics (invalid strings become NA gracefully)
      SO2_Numeric = suppressWarnings(as.numeric(SO2_Clean_Str)),
      NO2_Numeric = suppressWarnings(as.numeric(NO2_Clean_Str)),
      CO_Numeric  = suppressWarnings(as.numeric(CO_Clean_Str)),
      PM25_Numeric = suppressWarnings(as.numeric(PM25_Clean_Str)),
      PM10_Numeric = suppressWarnings(as.numeric(PM10_Clean_Str)),
      AQI_Numeric  = suppressWarnings(as.numeric(AQI_Clean_Str)),
      
      # Standardize AQI Category
      AQI_Category = case_when(
        str_detect(`AQI Index`, regex("Good", ignore_case = TRUE)) ~ "Good",
        str_detect(`AQI Index`, regex("Satisfactory", ignore_case = TRUE)) ~ "Satisfactory",
        str_detect(`AQI Index`, regex("Moderate", ignore_case = TRUE)) ~ "Moderate",
        str_detect(`AQI Index`, regex("Poor", ignore_case = TRUE)) & !str_detect(`AQI Index`, regex("Very", ignore_case = TRUE)) ~ "Poor",
        str_detect(`AQI Index`, regex("Very Poor", ignore_case = TRUE)) ~ "Very Poor",
        str_detect(`AQI Index`, regex("Severe", ignore_case = TRUE)) ~ "Severe",
        TRUE ~ NA_character_
      )
    ) %>%
    mutate(
      # 4. Physical Plausibility Checks & Anomaly Flags
      # Negative values or extreme physical violations
      Flag_SO2_Anomaly = !is.na(SO2_Numeric) & (SO2_Numeric < THRESHOLDS$SO2$min | SO2_Numeric > THRESHOLDS$SO2$max),
      Flag_NO2_Anomaly = !is.na(NO2_Numeric) & (NO2_Numeric < THRESHOLDS$NO2$min | NO2_Numeric > THRESHOLDS$NO2$max),
      Flag_CO_Anomaly  = !is.na(CO_Numeric) & (CO_Numeric < THRESHOLDS$CO$min | CO_Numeric > THRESHOLDS$CO$max),
      Flag_PM25_Anomaly = !is.na(PM25_Numeric) & (PM25_Numeric < THRESHOLDS$PM2.5$min | PM25_Numeric > THRESHOLDS$PM2.5$max),
      Flag_PM10_Anomaly = !is.na(PM10_Numeric) & (PM10_Numeric < THRESHOLDS$PM10$min | PM10_Numeric > THRESHOLDS$PM10$max),
      Flag_AQI_Anomaly  = !is.na(AQI_Numeric) & (AQI_Numeric < THRESHOLDS$AQI$min | AQI_Numeric > THRESHOLDS$AQI$max),
      
      # PM Ratio check: PM2.5 is a physical subset of PM10; in ambient air PM2.5 cannot realistically exceed PM10 + measurement noise
      Flag_PMRatio_Inversion = !is.na(PM25_Numeric) & !is.na(PM10_Numeric) & (PM25_Numeric > PM10_Numeric * 1.05),
      
      # Overall suspicious flag
      Is_Suspicious = Flag_SO2_Anomaly | Flag_NO2_Anomaly | Flag_CO_Anomaly | 
                      Flag_PM25_Anomaly | Flag_PM10_Anomaly | Flag_AQI_Anomaly | 
                      Flag_PMRatio_Inversion | Hardware_Issue_Flag
    ) %>%
    mutate(
      # Standard compatibility aliases
      SO2 = SO2_Numeric,
      NO2 = NO2_Numeric,
      CO  = CO_Numeric,
      `PM2.5` = PM25_Numeric,
      PM10 = PM10_Numeric,
      AQI  = AQI_Numeric,
      AQI_Cat = AQI_Category,
      Hardware_Issue = Hardware_Issue_Flag,
      PM_Inversion = Flag_PMRatio_Inversion
    )
  
  return(df_audit)
}

#' Generate a summary of data quality metrics
calculate_quality_summary <- function(df_audited) {
  total_records <- nrow(df_audited)
  total_duplicates <- sum(df_audited$Is_Duplicate, na.rm = TRUE)
  total_hardware_issues <- sum(df_audited$Hardware_Issue_Flag, na.rm = TRUE)
  
  # Calculate missing percentage across all core pollutants
  pollutant_cols <- c("SO2_Numeric", "NO2_Numeric", "CO_Numeric", "PM25_Numeric", "PM10_Numeric", "AQI_Numeric")
  total_cells <- total_records * length(pollutant_cols)
  missing_cells <- sum(sapply(df_audited[pollutant_cols], function(x) sum(is.na(x))))
  missing_pct <- round((missing_cells / total_cells) * 100, 2)
  
  stations_count <- n_distinct(df_audited$Station)
  date_min <- min(df_audited$Date, na.rm = TRUE)
  date_max <- max(df_audited$Date, na.rm = TRUE)
  
  list(
    total_records = total_records,
    stations_count = stations_count,
    date_range = paste(date_min, "to", date_max),
    date_min = date_min,
    date_max = date_max,
    missing_pct = missing_pct,
    total_duplicates = total_duplicates,
    hardware_issues = total_hardware_issues,
    suspicious_count = sum(df_audited$Is_Suspicious, na.rm = TRUE)
  )
}
