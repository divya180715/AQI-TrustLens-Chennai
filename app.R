# ==============================================================================
# PROJECT: AQI TrustLens
# TITLE: Chennai Air Quality & Data Reliability Dashboard
# SCRIPT: app.R
# ==============================================================================

suppressPackageStartupMessages({
  library(shiny)
  library(ggplot2)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(scales)
})

# Detect optional visualization packages
has_plotly  <- suppressWarnings(requireNamespace("plotly", quietly = TRUE))
has_leaflet <- suppressWarnings(requireNamespace("leaflet", quietly = TRUE))

if (has_plotly)  library(plotly)
if (has_leaflet) library(leaflet)

source("R/visualizations.R")

# ------------------------------------------------------------------------------
# 1. Data Ingestion & Pre-computation
# ------------------------------------------------------------------------------
data_path  <- "data/processed/chennai_aqi_audited.csv"
stats_path <- "outputs/reports/station_pollutant_statistics.csv"
comp_path  <- "outputs/reports/before_after_cleaning_comparison.csv"

if (file.exists(data_path)) {
  df_audited <- read_csv(data_path, show_col_types = FALSE)
  df_audited$Date <- as.Date(df_audited$Date)
} else {
  stop("Missing processed data! Please run R/analysis.R first.")
}

df_station_stats <- if (file.exists(stats_path)) read_csv(stats_path, show_col_types = FALSE) else NULL
df_comparison    <- if (file.exists(comp_path)) read_csv(comp_path, show_col_types = FALSE) else NULL

# Defensive schema normalization
if (!"Hardware_Issue_Flag" %in% names(df_audited) && "Hardware_Issue" %in% names(df_audited)) {
  df_audited$Hardware_Issue_Flag <- as.logical(df_audited$Hardware_Issue)
}
if (!"Is_Suspicious" %in% names(df_audited)) df_audited$Is_Suspicious <- FALSE
if (!"Is_Duplicate"  %in% names(df_audited)) df_audited$Is_Duplicate  <- FALSE

if (!"SO2_Numeric"  %in% names(df_audited) && "SO2" %in% names(df_audited)) df_audited$SO2_Numeric  <- as.numeric(df_audited$SO2)
if (!"NO2_Numeric"  %in% names(df_audited) && "NO2" %in% names(df_audited)) df_audited$NO2_Numeric  <- as.numeric(df_audited$NO2)
if (!"CO_Numeric"   %in% names(df_audited) && "CO" %in% names(df_audited)) df_audited$CO_Numeric   <- as.numeric(df_audited$CO)
if (!"PM25_Numeric" %in% names(df_audited) && "PM2.5" %in% names(df_audited)) df_audited$PM25_Numeric <- as.numeric(df_audited$`PM2.5`)
if (!"PM10_Numeric" %in% names(df_audited) && "PM10" %in% names(df_audited)) df_audited$PM10_Numeric <- as.numeric(df_audited$PM10)
if (!"AQI_Numeric"  %in% names(df_audited) && "AQI" %in% names(df_audited)) df_audited$AQI_Numeric  <- as.numeric(df_audited$AQI)

# Geographic Coordinates for Chennai Monitoring Stations (Verified Official Locations)
STATION_METADATA <- tibble(
  Station   = c("Kodungaiyur", "Koyambedu", "Manali", "Perungudi", "Royapuram"),
  Lat       = c(13.1362, 13.0694, 13.1667, 12.9654, 13.1147),
  Lng       = c(80.2524, 80.1948, 80.2633, 80.2461, 80.2972),
  Zone_Type = c("Residential / Landfill Interface", "Transit Hub / Commercial Junction", 
                "Petrochemical Industrial Corridor", "IT Expressway / Pallikaranai Wetland", 
                "Coastal Port & Dense Urban Corridor")
)

station_medians <- df_audited %>%
  group_by(Station) %>%
  summarise(
    Median_AQI  = round(median(AQI_Numeric, na.rm = TRUE), 1),
    Mean_AQI    = round(mean(AQI_Numeric, na.rm = TRUE), 1),
    Median_PM25 = round(median(PM25_Numeric, na.rm = TRUE), 1),
    Median_PM10 = round(median(PM10_Numeric, na.rm = TRUE), 1),
    Valid_Days  = sum(!is.na(AQI_Numeric)),
    .groups     = "drop"
  )

station_map_data <- left_join(STATION_METADATA, station_medians, by = "Station")

stations_available <- sort(unique(df_audited$Station))
min_date <- min(df_audited$Date, na.rm = TRUE)
max_date <- max(df_audited$Date, na.rm = TRUE)

pollutant_choices <- c(
  "AQI (Air Quality Index)"   = "AQI_Numeric",
  "PM2.5 (Fine Particulate)"  = "PM25_Numeric",
  "PM10 (Coarse Particulate)" = "PM10_Numeric",
  "NO2 (Nitrogen Dioxide)"    = "NO2_Numeric",
  "SO2 (Sulfur Dioxide)"      = "SO2_Numeric",
  "CO (Carbon Monoxide)"      = "CO_Numeric"
)

# ------------------------------------------------------------------------------
# 2. UI Definition: Clean Light Academic Theme with Dark Navy Header
# ------------------------------------------------------------------------------
ui <- navbarPage(
  title = div(
    style = "display: flex; align-items: center; gap: 10px; font-weight: 800; font-size: 1.25rem;",
    icon("shield-halved", style = "color: #38BDF8; font-size: 1.4rem;"),
    span(style = "color: #FFFFFF;", "AQI TrustLens"),
    span(style = "font-size: 0.78rem; font-weight: 500; color: #94A3B8; background: #1E293B; padding: 3px 10px; border-radius: 999px; margin-left: 6px; border: 1px solid #334155;", "Chennai CAAQMS Historical Audit")
  ),
  id = "nav_tabs",
  windowTitle = "AQI TrustLens | Chennai Air Quality & Reliability Dashboard",
  collapsible = TRUE,
  position = "static-top",
  
  header = tags$head(
    tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap"),
    tags$style(HTML("
      /* --- Global Clean Light Workspace --- */
      body {
        font-family: 'Plus Jakarta Sans', -apple-system, sans-serif !important;
        background-color: #F8FAFC !important;
        color: #0F172A !important;
        font-size: 14px;
        line-height: 1.5;
      }
      
      /* --- Dark Navy Top Navigation --- */
      .navbar {
        background-color: #0F172A !important;
        border: none !important;
        border-bottom: 2px solid #0284C7 !important;
        box-shadow: 0 4px 16px rgba(15, 23, 42, 0.15) !important;
        margin-bottom: 24px !important;
        padding: 4px 16px !important;
      }
      .navbar-default .navbar-nav > li > a {
        color: #94A3B8 !important;
        font-weight: 600 !important;
        font-size: 0.95rem !important;
        padding: 16px 18px !important;
        transition: all 0.2s ease !important;
      }
      .navbar-default .navbar-nav > li > a:hover {
        color: #FFFFFF !important;
        background-color: #1E293B !important;
      }
      .navbar-default .navbar-nav > .active > a,
      .navbar-default .navbar-nav > .active > a:hover,
      .navbar-default .navbar-nav > .active > a:focus {
        color: #FFFFFF !important;
        background-color: #0284C7 !important;
        border-radius: 6px !important;
      }
      
      /* --- Layout & Card Containers --- */
      .container-fluid {
        max-width: 1440px !important;
        margin: 0 auto !important;
        padding: 0 24px !important;
      }
      .app-card {
        background: #FFFFFF !important;
        border: 1px solid #E2E8F0 !important;
        border-radius: 12px !important;
        padding: 24px !important;
        margin-bottom: 24px !important;
        box-shadow: 0 1px 3px rgba(0,0,0,0.05), 0 10px 15px -3px rgba(0,0,0,0.02) !important;
      }
      .app-card-header {
        border-bottom: 1px solid #F1F5F9;
        padding-bottom: 14px;
        margin-bottom: 18px;
      }
      .app-card-title {
        font-size: 1.15rem;
        font-weight: 700;
        color: #0F172A;
        margin: 0;
        display: flex;
        align-items: center;
        gap: 8px;
      }
      .app-card-subtitle {
        font-size: 0.85rem;
        color: #64748B;
        margin-top: 4px;
        margin-bottom: 0;
      }
      
      /* --- Persistent Filter Panel --- */
      .filter-panel {
        background: #FFFFFF !important;
        border: 1px solid #CBD5E1 !important;
        border-radius: 12px !important;
        padding: 18px 22px !important;
        margin-bottom: 24px !important;
        box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05) !important;
      }
      
      /* --- Metric KPI Badges --- */
      .kpi-card {
        background: #FFFFFF !important;
        border: 1px solid #E2E8F0 !important;
        border-left: 4px solid #0284C7 !important;
        border-radius: 10px !important;
        padding: 16px 18px !important;
        margin-bottom: 22px !important;
        box-shadow: 0 2px 4px rgba(0,0,0,0.04) !important;
        transition: transform 0.15s ease, box-shadow 0.15s ease;
      }
      .kpi-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 8px 16px rgba(2, 132, 199, 0.1) !important;
      }
      .kpi-card.warning-card { border-left-color: #F59E0B !important; }
      .kpi-card.danger-card { border-left-color: #EF4444 !important; }
      .kpi-card.success-card { border-left-color: #10B981 !important; }
      
      .kpi-label {
        font-size: 0.76rem !important;
        font-weight: 700 !important;
        color: #64748B !important;
        text-transform: uppercase !important;
        letter-spacing: 0.05em !important;
      }
      .kpi-val {
        font-size: 1.85rem !important;
        font-weight: 800 !important;
        color: #0F172A !important;
        margin: 4px 0 !important;
        line-height: 1.2 !important;
      }
      .kpi-sub {
        font-size: 0.8rem !important;
        color: #64748B !important;
      }
      
      /* --- Form Controls --- */
      .form-control, .selectize-input {
        border-color: #CBD5E1 !important;
        border-radius: 8px !important;
        font-size: 0.92rem !important;
        color: #0F172A !important;
        box-shadow: none !important;
      }
      .form-control:focus, .selectize-input.focus {
        border-color: #0284C7 !important;
        box-shadow: 0 0 0 3px rgba(2, 132, 199, 0.15) !important;
      }
      
      /* --- Action & Download Buttons --- */
      .btn-download-primary {
        background: #0284C7 !important;
        color: #FFFFFF !important;
        font-weight: 700 !important;
        border: none !important;
        border-radius: 8px !important;
        padding: 10px 18px !important;
        width: 100% !important;
        display: block !important;
        text-align: center !important;
        box-shadow: 0 2px 4px rgba(2, 132, 199, 0.25) !important;
        transition: background-color 0.2s ease !important;
      }
      .btn-download-primary:hover {
        background: #0369A1 !important;
        color: #FFFFFF !important;
      }
      
      /* --- Clean Tables --- */
      .table {
        margin-bottom: 0 !important;
        font-size: 0.9rem !important;
      }
      .table > thead > tr > th {
        background: #F8FAFC !important;
        color: #1E293B !important;
        font-weight: 700 !important;
        border-bottom: 2px solid #E2E8F0 !important;
        padding: 10px 12px !important;
      }
      .table > tbody > tr > td {
        padding: 10px 12px !important;
        vertical-align: middle !important;
        border-top: 1px solid #F1F5F9 !important;
      }
      .table-striped > tbody > tr:nth-of-type(odd) {
        background-color: #F8FAFC !important;
      }
      
      /* --- Alert Info Box --- */
      .insight-box {
        background: #F0F9FF;
        border-left: 4px solid #0284C7;
        border-radius: 0 8px 8px 0;
        padding: 14px 18px;
        color: #0369A1;
        font-size: 0.9rem;
        margin-top: 16px;
      }
    "))
  ),
  
  # ============================================================================
  # TAB 1: EXECUTIVE OVERVIEW & GEOGRAPHIC NETWORK
  # ============================================================================
  tabPanel(
    title = tagList(icon("chart-pie"), " Executive Overview"),
    value = "tab_overview",
    
    div(class = "container-fluid",
      # Global Reactive Controls
      div(class = "filter-panel",
        fluidRow(
          column(4,
            dateRangeInput("filter_dates", "Observation Window Filter:", 
                           start = min_date, end = max_date, min = min_date, max = max_date, width = "100%")
          ),
          column(3,
            selectInput("filter_pollutant", "Primary Evaluated Parameter:", 
                        choices = pollutant_choices, selected = "AQI_Numeric", width = "100%")
          ),
          column(3,
            selectizeInput("filter_stations", "Active Stations (Filter):", 
                           choices = stations_available, selected = stations_available, multiple = TRUE, width = "100%")
          ),
          column(2,
            div(style = "padding-top: 25px;",
              actionButton("btn_reset", "Reset All Filters", icon = icon("rotate"), class = "btn btn-default", style = "width: 100%; font-weight: 600;")
            )
          )
        )
      ),
      
      # Auto-Updating Dynamic KPI Cards
      fluidRow(
        column(2,
          div(class = "kpi-card",
            div(class = "kpi-label", "Observations"),
            div(class = "kpi-val", textOutput("kpi_obs")),
            div(class = "kpi-sub", "In active filter")
          )
        ),
        column(2,
          div(class = "kpi-card success-card",
            div(class = "kpi-label", "Mean Parameter Value"),
            div(class = "kpi-val", style = "color: #0284C7;", textOutput("kpi_mean")),
            div(class = "kpi-sub", textOutput("kpi_median"))
          )
        ),
        column(2,
          div(class = "kpi-card warning-card",
            div(class = "kpi-label", "Peak Spike"),
            div(class = "kpi-val", style = "color: #D97706;", textOutput("kpi_max")),
            div(class = "kpi-sub", textOutput("kpi_max_loc"))
          )
        ),
        column(2,
          div(class = "kpi-card",
            div(class = "kpi-label", "Missingness Rate"),
            div(class = "kpi-val", textOutput("kpi_missing")),
            div(class = "kpi-sub", "In active filter")
          )
        ),
        column(2,
          div(class = "kpi-card",
            div(class = "kpi-label", "Duplicate Records"),
            div(class = "kpi-val", textOutput("kpi_dups")),
            div(class = "kpi-sub", textOutput("kpi_dups_sub"))
          )
        ),
        column(2,
          div(class = "kpi-card danger-card",
            div(class = "kpi-label", "Audit Flagged"),
            div(class = "kpi-val", style = "color: #DC2626;", textOutput("kpi_flags")),
            div(class = "kpi-sub", "Outages + Inversions")
          )
        )
      ),
      
      # Main Map and Narrative Layout
      fluidRow(
        column(7,
          div(class = "app-card",
            div(class = "app-card-header",
              h3(class = "app-card-title", icon("map-location-dot", style="color:#0284C7;"), " Chennai Ambient Monitoring Stations"),
              p(class = "app-card-subtitle", "Interactive map of CAAQMS stations showing geographic placement, microclimate zone, and baseline median AQI.")
            ),
            uiOutput("map_container", style = "height: 440px; border-radius: 8px; overflow: hidden;")
          )
        ),
        column(5,
          div(class = "app-card",
            div(class = "app-card-header",
              h3(class = "app-card-title", icon("circle-info", style="color:#0284C7;"), " About AQI TrustLens"),
              p(class = "app-card-subtitle", "Objective academic evaluation of urban air monitoring reliability.")
            ),
            p(style = "color: #334155; line-height: 1.6;",
              "Municipal environmental health policies rely heavily on Continuous Ambient Air Quality Monitoring Stations (CAAQMS). However, real-world monitoring networks suffer from power interruptions, hardware sensor communication timeouts, duplicate entries, and calibration drift."
            ),
            p(style = "color: #334155; line-height: 1.6;",
              strong("AQI TrustLens"), " audits historical data from Chennai (2023–2024) across 5 primary stations. Rather than deleting missing records or applying silent imputation, the engine exposes data quality transparently alongside pollution patterns."
            ),
            hr(style = "border-color: #F1F5F9;"),
            h4(style = "font-size: 0.95rem; font-weight: 700; color: #0F172A; margin-bottom: 10px;", "Station Baseline Historical Summary:"),
            tableOutput("table_station_medians")
          )
        )
      )
    )
  ),
  
  # ============================================================================
  # TAB 2: POLLUTION TRENDS
  # ============================================================================
  tabPanel(
    title = tagList(icon("chart-line"), " Pollution Trends"),
    value = "tab_trends",
    
    div(class = "container-fluid",
      div(class = "app-card",
        div(class = "app-card-header",
          fluidRow(
            column(8,
              h3(class = "app-card-title", icon("chart-line", style="color:#0284C7;"), " Multi-Station Continuous Pollution Timeline"),
              p(class = "app-card-subtitle", "High-resolution historical time series. Hover over points to examine daily concentrations, dates, and station identifiers.")
            ),
            column(4,
              div(style = "text-align: right; padding-top: 6px;",
                checkboxInput("enable_rolling_mean", "Overlay 7-Day Trend Smoothing (LOESS)", value = FALSE)
              )
            )
          )
        ),
        uiOutput("trend_chart_ui", style = "min-height: 500px;"),
        div(class = "insight-box",
          strong(icon("circle-info"), " Methodological Interpretation: "),
          "Nov/Dec peaks coincide with post-monsoon seasonal cooling and regional festival events. While synchronous peaks across all stations suggest broader atmospheric conditions rather than isolated sensor failures, confirming specific mechanisms (such as fireworks or boundary-layer inversions) requires co-analyzing meteorological telemetry like wind and boundary layer height."
        )
      )
    )
  ),
  
  # ============================================================================
  # TAB 3: STATION COMPARISON & HEALTH BANDS
  # ============================================================================
  tabPanel(
    title = tagList(icon("sliders"), " Station Comparison"),
    value = "tab_comparison",
    
    div(class = "container-fluid",
      div(class = "app-card",
        div(class = "app-card-header",
          fluidRow(
            column(6,
              h3(class = "app-card-title", icon("sliders", style="color:#0284C7;"), " Comparative Pollution Distributions"),
              p(class = "app-card-subtitle", "Evaluate variations in median exposure, spread (IQR), and national health category proportions.")
            ),
            column(6,
              div(style = "text-align: right; padding-top: 4px;",
                radioButtons("comp_view_type", label = NULL, 
                             choices = c("Distribution Boxplot & Outliers" = "box", 
                                         "CPCB National Health Category Breakdown" = "category"), 
                             selected = "box", inline = TRUE)
              )
            )
          )
        ),
        uiOutput("comp_chart_ui", style = "min-height: 480px;"),
        div(class = "insight-box",
          strong(icon("circle-info"), " Environmental Interpretation: "),
          "Stations exhibit distinct distribution spreads (e.g., Manali exhibits higher IQR and upper extremes than coastal Royapuram). While these patterns align with Manali's industrial zoning and Royapuram's coastal ventilation, distribution differences alone do not prove direct industrial causation without atmospheric dispersion modeling."
        )
      )
    )
  ),
  
  # ============================================================================
  # TAB 4: DATA QUALITY & RELIABILITY AUDIT
  # ============================================================================
  tabPanel(
    title = tagList(icon("clipboard-check"), " Data Quality & Reliability"),
    value = "tab_quality",
    
    div(class = "container-fluid",
      div(class = "app-card",
        div(class = "app-card-header",
          h3(class = "app-card-title", icon("clipboard-check", style="color:#0284C7;"), " Monitoring Network Reliability & Missingness Audit"),
          p(class = "app-card-subtitle", "Exposing systematic monitoring blindspots and equipment outage patterns across all 30 station-pollutant pairs.")
        ),
        plotOutput("plot_heatmap", height = "440px"),
        hr(style = "border-color: #F1F5F9; margin: 24px 0;"),
        fluidRow(
          column(6,
            h4(style = "font-size: 1rem; font-weight: 700; color: #0F172A;", "Key Empirical Reliability Findings:"),
            tags$ul(style = "color: #334155; line-height: 1.7; font-size: 0.92rem;",
              tags$li(strong("Koyambedu CO Monitor Blindspot: "), "Suffered 45.04% missingness (268 missing days out of 595 observations) due to an extended sensor replacement cycle. Without TrustLens, citywide CO averages would be distorted."),
              tags$li(strong("Particulate Matter Completeness: "), "PM2.5 and PM10 maintained >97% data completeness across remaining stations."),
              tags$li(strong("Explicit Hardware Annotations: "), "45 records contained explicit text logs such as 'N/A (PC Issue)' and 'EB Power supply issue' during Cyclone Michaung.")
            )
          ),
          column(6,
            h4(style = "font-size: 1rem; font-weight: 700; color: #0F172A;", "Non-Destructive Audit Taxonomy:"),
            tags$ul(style = "color: #334155; line-height: 1.7; font-size: 0.92rem;",
              tags$li(strong("Valid Observations: "), "Numerically intact measurements within physically verified limits."),
              tags$li(strong("Duplicate Records (32 records / 16 pairs): "), "Redundant Date + Station telemetry transmissions."),
              tags$li(strong("Aerosol Inversions (6 records): "), "Anomalous readings where PM2.5 > 1.05 * PM10, tagged non-destructively for optical calibration review.")
            )
          )
        )
      )
    )
  ),
  
  # ============================================================================
  # TAB 5: BEFORE & AFTER CLEANING ANALYSIS
  # ============================================================================
  tabPanel(
    title = tagList(icon("scale-balanced"), " Before & After Cleaning"),
    value = "tab_cleaning",
    
    div(class = "container-fluid",
      div(class = "app-card",
        div(class = "app-card-header",
          h3(class = "app-card-title", icon("scale-balanced", style="color:#0284C7;"), " Quantifying the Impact of Justified Deduplication"),
          p(class = "app-card-subtitle", "Direct statistical comparison proving how removing 16 duplicate records affects empirical parameters (2,975 raw vs. 2,959 clean).")
        ),
        plotOutput("plot_before_after", height = "400px"),
        hr(style = "border-color: #F1F5F9; margin: 24px 0;"),
        h4(style = "font-size: 1rem; font-weight: 700; color: #0F172A; margin-bottom: 12px;", "Summary Statistics Shift Table:"),
        tableOutput("table_before_after"),
        div(class = "insight-box",
          strong(icon("triangle-exclamation"), " Critical Scientific Nuance: "),
          "Deduplication corrects statistical double-counting (Mean AQI shifts from 67.09 to 66.97; median remains stable at 62.0). However, TrustLens never implies that deduplication certifies that all remaining readings are noise-free."
        )
      )
    )
  ),
  
  # ============================================================================
  # TAB 6: DATA EXPORT & REPORTS
  # ============================================================================
  tabPanel(
    title = tagList(icon("file-arrow-down"), " Data Export & Reports"),
    value = "tab_export",
    
    div(class = "container-fluid",
      div(class = "app-card",
        div(class = "app-card-header",
          h3(class = "app-card-title", icon("file-arrow-down", style="color:#0284C7;"), " Export Validated Observations & Audit Ledgers"),
          p(class = "app-card-subtitle", "Download active filtered subsets or precomputed statistical summaries in CSV format for academic reports.")
        ),
        fluidRow(
          column(4,
            div(style = "background: #F8FAFC; border: 1px solid #E2E8F0; padding: 20px; border-radius: 10px;",
              h4(style = "font-size: 0.98rem; font-weight: 700; color: #0F172A; margin-top:0;", "Export Active Filter Subset"),
              p(style = "font-size: 0.83rem; color: #64748B;", "Exports all observations matching your current active dates and station selections."),
              downloadButton("download_filtered_data", "Download Filtered CSV", class = "btn-download-primary")
            )
          ),
          column(4,
            div(style = "background: #F8FAFC; border: 1px solid #E2E8F0; padding: 20px; border-radius: 10px;",
              h4(style = "font-size: 0.98rem; font-weight: 700; color: #0F172A; margin-top:0;", "Station Statistics Report"),
              p(style = "font-size: 0.83rem; color: #64748B;", "Complete descriptive parameters across all 5 stations and 6 monitored pollutants."),
              downloadButton("download_station_stats", "Download Station Stats CSV", class = "btn-download-primary")
            )
          ),
          column(4,
            div(style = "background: #F8FAFC; border: 1px solid #E2E8F0; padding: 20px; border-radius: 10px;",
              h4(style = "font-size: 0.98rem; font-weight: 700; color: #0F172A; margin-top:0;", "Before/After Cleaning Audit"),
              p(style = "font-size: 0.83rem; color: #64748B;", "Detailed delta shift ledger quantifying the exact impact of deduplication."),
              downloadButton("download_before_after", "Download Comparison CSV", class = "btn-download-primary")
            )
          )
        ),
        hr(style = "border-color: #F1F5F9; margin: 24px 0;"),
        h4(style = "font-size: 1rem; font-weight: 700; color: #0F172A; margin-bottom: 12px;", "Active Selection Preview (First 15 Rows):"),
        tableOutput("table_export_preview")
      )
    )
  )
)

# ------------------------------------------------------------------------------
# 3. Server Logic
# ------------------------------------------------------------------------------
server <- function(input, output, session) {
  
  # Reset Filters Observer
  observeEvent(input$btn_reset, {
    updateDateRangeInput(session, "filter_dates", start = min_date, end = max_date)
    updateSelectInput(session, "filter_pollutant", selected = "AQI_Numeric")
    updateSelectizeInput(session, "filter_stations", selected = stations_available)
  })
  
  # Dynamic reactive subset
  r_filtered_data <- reactive({
    req(input$filter_dates, input$filter_stations)
    
    df_audited %>%
      filter(
        Station %in% input$filter_stations,
        Date >= input$filter_dates[1],
        Date <= input$filter_dates[2]
      )
  })
  
  # Auto-updating dynamic KPIs
  output$kpi_obs <- renderText({
    format(nrow(r_filtered_data()), big.mark = ",")
  })
  
  output$kpi_mean <- renderText({
    vals <- r_filtered_data()[[input$filter_pollutant]]
    vals <- vals[!is.na(vals)]
    if (length(vals) > 0) sprintf("%.1f", mean(vals)) else "N/A"
  })
  
  output$kpi_median <- renderText({
    vals <- r_filtered_data()[[input$filter_pollutant]]
    vals <- vals[!is.na(vals)]
    if (length(vals) > 0) paste("Median:", round(median(vals), 1)) else "Median: N/A"
  })
  
  output$kpi_max <- renderText({
    vals <- r_filtered_data()[[input$filter_pollutant]]
    vals <- vals[!is.na(vals)]
    if (length(vals) > 0) sprintf("%.1f", max(vals)) else "N/A"
  })
  
  output$kpi_max_loc <- renderText({
    df <- r_filtered_data() %>% filter(!is.na(.data[[input$filter_pollutant]]))
    if (nrow(df) > 0) {
      top_row <- df %>% arrange(desc(.data[[input$filter_pollutant]])) %>% slice(1)
      paste("At", top_row$Station)
    } else {
      "No observations"
    }
  })
  
  output$kpi_missing <- renderText({
    df <- r_filtered_data()
    n_total <- nrow(df)
    if (n_total == 0) return("0.0%")
    n_na <- sum(is.na(df[[input$filter_pollutant]]))
    sprintf("%.1f%%", (n_na / n_total) * 100)
  })
  
  output$kpi_dups <- renderText({
    as.character(sum(as.logical(r_filtered_data()$Is_Duplicate), na.rm = TRUE))
  })
  
  output$kpi_dups_sub <- renderText({
    dups_df <- r_filtered_data() %>% filter(as.logical(Is_Duplicate))
    n_pairs <- if (nrow(dups_df) > 0) n_distinct(paste(dups_df$Date, dups_df$Station)) else 0
    paste0("Involves ", n_pairs, " duplicate pairs")
  })
  
  output$kpi_flags <- renderText({
    as.character(sum(as.logical(r_filtered_data()$Is_Suspicious), na.rm = TRUE))
  })
  
  # ---------------- TAB 1: MAP & TABLE ----------------
  output$map_container <- renderUI({
    if (has_leaflet) {
      leafletOutput("station_map", height = "440px")
    } else {
      plotOutput("fallback_station_map", height = "440px")
    }
  })
  
  if (has_leaflet) {
    output$station_map <- renderLeaflet({
      pal <- colorNumeric(palette = c("#10B981", "#EAB308", "#F97316", "#DC2626"), domain = station_map_data$Median_AQI)
      
      leaflet(station_map_data) %>%
        addProviderTiles(providers$CartoDB.Positron) %>%
        setView(lng = 80.24, lat = 13.08, zoom = 11) %>%
        addCircleMarkers(
          lng = ~Lng, lat = ~Lat,
          radius = 12,
          color = ~pal(Median_AQI),
          fillColor = ~pal(Median_AQI),
          fillOpacity = 0.85,
          weight = 2,
          popup = ~paste0(
            "<div style='font-family: sans-serif; font-size: 13px; color: #0F172A;'>",
            "<strong style='font-size: 14px;'>", Station, " CAAQMS</strong><br/>",
            "<em>", Zone_Type, "</em><hr style='margin: 4px 0;'/>",
            "<strong>Median AQI:</strong> ", Median_AQI, "<br/>",
            "<strong>Mean AQI:</strong> ", Mean_AQI, "<br/>",
            "<strong>Median PM2.5:</strong> ", Median_PM25, " ug/m3<br/>",
            "<strong>Median PM10:</strong> ", Median_PM10, " ug/m3<br/>",
            "<strong>Valid Observations:</strong> ", Valid_Days, " days",
            "</div>"
          )
        ) %>%
        addLegend("bottomright", pal = pal, values = ~Median_AQI, title = "Median AQI", opacity = 1)
    })
  } else {
    output$fallback_station_map <- renderPlot({
      ggplot(station_map_data, aes(x = Lng, y = Lat, color = Median_AQI)) +
        geom_point(size = 8) +
        geom_text(aes(label = paste(Station, "\nAQI:", Median_AQI)), vjust = -0.5, fontface = "bold", size = 3.8, color = "#0F172A") +
        scale_color_gradient(low = "#10B981", high = "#DC2626", name = "Median AQI") +
        labs(title = "Chennai CAAQMS Monitoring Station Locations", x = "Longitude", y = "Latitude") +
        theme_trustlens_light()
    })
  }
  
  output$table_station_medians <- renderTable({
    station_map_data %>%
      select(Station, Zone_Type, Median_AQI, Median_PM25, Median_PM10) %>%
      rename(`Station` = Station, `Microclimate Zone` = Zone_Type, `Med AQI` = Median_AQI, `Med PM2.5` = Median_PM25, `Med PM10` = Median_PM10)
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%")
  
  # ---------------- TAB 2: TRENDS ----------------
  output$trend_chart_ui <- renderUI({
    if (has_plotly) {
      plotlyOutput("plotly_trend", height = "500px")
    } else {
      plotOutput("plot_trend", height = "500px")
    }
  })
  
  output$plot_trend <- renderPlot({
    data <- r_filtered_data()
    validate(need(nrow(data) > 0, "No observations match the current filter selection."))
    label <- names(pollutant_choices)[pollutant_choices == input$filter_pollutant]
    p <- plot_pollution_trend(data, pollutant_col = input$filter_pollutant, pollutant_label = label, selected_stations = input$filter_stations)
    
    if (isTRUE(input$enable_rolling_mean)) {
      p <- p + geom_smooth(se = FALSE, method = "loess", span = 0.15, linewidth = 1.1, linetype = "dashed", color = "#0F172A")
    }
    p
  })
  
  if (has_plotly) {
    output$plotly_trend <- renderPlotly({
      data <- r_filtered_data()
      validate(need(nrow(data) > 0, "No observations match the current filter selection."))
      label <- names(pollutant_choices)[pollutant_choices == input$filter_pollutant]
      p <- plot_pollution_trend(data, pollutant_col = input$filter_pollutant, pollutant_label = label, selected_stations = input$filter_stations)
      
      if (isTRUE(input$enable_rolling_mean)) {
        p <- p + geom_smooth(se = FALSE, method = "loess", span = 0.15, linewidth = 1.1, linetype = "dashed", color = "#0F172A")
      }
      
      ggplotly(p, tooltip = c("x", "y", "color")) %>%
        layout(
          paper_bgcolor = "#FFFFFF",
          plot_bgcolor = "#FFFFFF",
          font = list(color = "#0F172A"),
          legend = list(orientation = "h", y = -0.2)
        )
    })
  }
  
  # ---------------- TAB 3: COMPARISON ----------------
  output$comp_chart_ui <- renderUI({
    if (has_plotly) {
      plotlyOutput("plotly_comp", height = "480px")
    } else {
      plotOutput("plot_station_comp", height = "480px")
    }
  })
  
  output$plot_station_comp <- renderPlot({
    data <- r_filtered_data()
    validate(need(nrow(data) > 0, "No observations match the current filter selection."))
    if (input$comp_view_type == "box") {
      label <- names(pollutant_choices)[pollutant_choices == input$filter_pollutant]
      plot_station_comparison(data, pollutant_col = input$filter_pollutant, pollutant_label = label)
    } else {
      plot_aqi_category_distribution(data)
    }
  })
  
  if (has_plotly) {
    output$plotly_comp <- renderPlotly({
      data <- r_filtered_data()
      validate(need(nrow(data) > 0, "No observations match the current filter selection."))
      if (input$comp_view_type == "box") {
        label <- names(pollutant_choices)[pollutant_choices == input$filter_pollutant]
        p <- plot_station_comparison(data, pollutant_col = input$filter_pollutant, pollutant_label = label)
        ggplotly(p) %>% layout(paper_bgcolor = "#FFFFFF", plot_bgcolor = "#FFFFFF", font = list(color = "#0F172A"))
      } else {
        p <- plot_aqi_category_distribution(data)
        ggplotly(p) %>% layout(paper_bgcolor = "#FFFFFF", plot_bgcolor = "#FFFFFF", font = list(color = "#0F172A"), legend = list(orientation = "h", y = -0.2))
      }
    })
  }
  
  # ---------------- TAB 4: QUALITY HEATMAP ----------------
  output$plot_heatmap <- renderPlot({
    plot_data_quality_heatmap(stats_path)
  })
  
  # ---------------- TAB 5: BEFORE / AFTER ----------------
  output$plot_before_after <- renderPlot({
    plot_before_after_comparison(comp_path)
  })
  
  output$table_before_after <- renderTable({
    if (!is.null(df_comparison)) {
      df_comparison %>%
        select(Stage, Pollutant, Records, Valid_Count, Missing_Pct, Mean, Median, SD, Delta_Mean) %>%
        rename(
          `Dataset Stage` = Stage,
          `Total Records` = Records,
          `Valid Count`   = Valid_Count,
          `Missing %`     = Missing_Pct,
          `Mean Shift`    = Delta_Mean
        )
    }
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%")
  
  # ---------------- TAB 6: DATA EXPORT ----------------
  output$table_export_preview <- renderTable({
    r_filtered_data() %>%
      mutate(Date = format(as.Date(Date), "%Y-%m-%d")) %>%
      select(Date, Station, SO2_Numeric, NO2_Numeric, CO_Numeric, PM25_Numeric, PM10_Numeric, AQI_Numeric, AQI_Category, Hardware_Issue_Flag, Is_Duplicate) %>%
      rename(
        `Date` = Date, `Station` = Station, `SO2` = SO2_Numeric, `NO2` = NO2_Numeric,
        `CO` = CO_Numeric, `PM2.5` = PM25_Numeric, `PM10` = PM10_Numeric,
        `AQI` = AQI_Numeric, `Category` = AQI_Category, `Hardware Issue` = Hardware_Issue_Flag,
        `Is Duplicate` = Is_Duplicate
      ) %>%
      head(15)
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%")
  
  output$download_filtered_data <- downloadHandler(
    filename = function() { paste0("chennai_aqi_filtered_", Sys.Date(), ".csv") },
    content = function(file) {
      export_df <- r_filtered_data() %>%
        mutate(Date = format(as.Date(Date), "%Y-%m-%d"))
      write_csv(export_df, file)
    }
  )
  
  output$download_station_stats <- downloadHandler(
    filename = function() { "chennai_station_pollutant_statistics.csv" },
    content = function(file) {
      if (file.exists(stats_path)) file.copy(stats_path, file)
    }
  )
  
  output$download_before_after <- downloadHandler(
    filename = function() { "chennai_before_after_cleaning_comparison.csv" },
    content = function(file) {
      if (file.exists(comp_path)) file.copy(comp_path, file)
    }
  )
}

shinyApp(ui = ui, server = server)
