# ==============================================================================
# PROJECT: AQI TrustLens - Chennai Air Quality & Data Reliability Dashboard
# SCRIPT: R/data_import.R
# PURPOSE: Import and harmonize raw multi-year CPCB/OpenCity Chennai AQI data.
# ==============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
  library(lubridate)
})

#' Helper to parse messy date strings found in CPCB Chennai bulletin files
#' Examples in raw data:
#'  - "01 January" / "01 JANUARY" -> "2023-01-01" / "2024-01-01"
#'  - "02May "                   -> "2023-05-02"
#'  - "16July 2023"              -> "2023-07-16"
parse_chennai_dates <- function(date_vec, default_year) {
  # Clean whitespace and standardize
  cleaned <- str_trim(as.character(date_vec))
  
  # Remove trailing explicit 4-digit year if already embedded (e.g. "16July 2023")
  cleaned <- str_replace(cleaned, "\\s*\\d{4}$", "")
  
  # If digits and letters are stuck together like "02May", insert space -> "02 May"
  cleaned <- str_replace(cleaned, "^(\\d{1,2})([A-Za-z]+)$", "\\1 \\2")
  
  # Attach default year
  with_year <- paste(cleaned, default_year)
  
  # Parse with lubridate day-month-year
  parsed <- dmy(with_year, quiet = TRUE)
  return(parsed)
}

#' Load raw dataset for a specific year
load_raw_year <- function(file_path, year) {
  if (!file.exists(file_path)) {
    warning(paste("File not found:", file_path))
    return(NULL)
  }
  
  # Read all columns as character first to prevent silent coercion of text errors
  df_raw <- read_csv(
    file_path,
    col_types = cols(.default = col_character()),
    show_col_types = FALSE,
    trim_ws = TRUE
  )
  
  # Add metadata tracking original source
  df_raw <- df_raw %>%
    filter(!if_all(everything(), is.na)) %>%
    mutate(
      Source_Year = as.integer(year),
      Raw_Date = Date,
      Parsed_Date = parse_chennai_dates(Date, year),
      Station = str_trim(Station)
    )
  
  return(df_raw)
}

#' Master Import Function: Ingests 2023 & 2024 raw datasets and harmonizes schema
import_all_raw_data <- function(raw_dir = "data/raw") {
  path_2023 <- file.path(raw_dir, "chennai_aqi_2023.csv")
  path_2024 <- file.path(raw_dir, "chennai_aqi_2024.csv")
  
  df_2023 <- load_raw_year(path_2023, 2023)
  df_2024 <- load_raw_year(path_2024, 2024)
  
  combined <- bind_rows(df_2023, df_2024)
  
  # Standardize Station names (just in case of trailing spaces or case differences)
  combined <- combined %>%
    mutate(
      Station = str_to_title(str_trim(Station)),
      Date = Parsed_Date
    ) %>%
    arrange(Date, Station)
  
  return(combined)
}
