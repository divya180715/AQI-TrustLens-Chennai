# AQI TrustLens: Data-Quality-Aware Air Pollution Analysis Dashboard for Chennai

## 1. Project Overview & Abstract
**AQI TrustLens** is an interactive, advanced data visualization system built in **R** and **Shiny** that analyzes historical ambient air quality in Chennai while systematically evaluating the reliability of underlying monitoring networks. Rather than treating open environmental telemetry as infallible or applying silent, destructive cleaning, TrustLens implements a transparent audit pipeline. It quantifies missingness, isolates duplicate entries, categorizes infrastructure failure annotations, flags physical aerosol inconsistencies, and illustrates the statistical impact of justified cleaning decisions.

---

## 2. Problem Statement & Motivation
Public health advisories and environmental policy decisions depend on Continuous Ambient Air Quality Monitoring Stations (CAAQMS). However, municipal monitoring datasets often suffer from:
- **Systematic Hardware & Infrastructure Failures:** Power cuts during cyclonic events, communication dropouts, and computer downtime.
- **Redundant Transmission Records:** Duplicate timestamped entries that distort summary statistics.
- **Physical Sensor Discrepancies:** Ambient optical anomalies such as $PM_{2.5}$ readings exceeding total $PM_{10}$.
- **Opaque Cleaning:** Standard portals either hide missing values or silently drop outliers without explaining data provenance.

---

## 3. Existing Systems vs. AQI TrustLens

| Feature | Existing Systems (e.g. CPCB Portal, Air-Quality Apps) | AQI TrustLens |
| :--- | :--- | :--- |
| **Data Quality Transparency** | Opaque; missing data is hidden or zero-filled. | Explicit audit heatmap showing missingness & hardware outages. |
| **Handling of Duplicates** | Ignored or silently averaged. | Audited with quantitative before-and-after comparison. |
| **Anomaly Treatment** | Deleted blindly as outliers. | Non-destructive tagging (flags physical $PM_{2.5} > PM_{10}$ inversions). |
| **Statistical Impact** | Assumes post-cleaning numbers are absolute ground truth. | Quantifies effect of cleaning and clarifies analytical limitations. |
| **User Interface** | Fixed tables or basic time series. | Modern, academic light workspace with top navy navigation and live reactive KPIs. |

---

## 4. Dataset Source & Specifications
- **Source:** [OpenCity.in / CPCB Chennai Air Quality Repository](https://data.opencity.in/dataset/chennai-air-quality-reports-2022-2024).
- **Temporal Horizon:** **January 1, 2023 to August 31, 2024** (20 continuous calendar months).
- **Total Ingested Observations:** **2,975 station-day records**.
- **Monitoring Stations (5):**
  1. Kodungaiyur (North Chennai - Residential/Industrial interface)
  2. Koyambedu (West-Central Chennai - Major transit hub)
  3. Manali (North Chennai - Heavy petrochemical industrial cluster)
  4. Perungudi (South Chennai - IT corridor and landfill proximity)
  5. Royapuram (Coastal North-Central Chennai - Densely populated port corridor)
- **Monitored Parameters:** $SO_2$, $NO_2$, $CO$, $PM_{2.5}$, $PM_{10}$, AQI Value, AQI Category, Prominent Pollutant.

---

## 5. Architecture & Project Structure
```text
AQI_TrustLens/
├── app.R                          # Top-level NavbarPage Interactive Shiny Dashboard (6 Tabs)
├── R/
│   ├── data_import.R              # Harmonized date parsing and multi-year ingestion
│   ├── data_cleaning.R            # Non-destructive auditing and anomaly flag pipeline
│   ├── analysis.R                 # Descriptive statistics and before-vs-after comparison
│   └── visualizations.R           # Academic light theme ggplot2 plotting functions
├── data/
│   ├── raw/                       # Preserved, unaltered CPCB bulletin CSV files
│   │   ├── chennai_aqi_2023.csv
│   │   └── chennai_aqi_2024.csv
│   └── processed/
│       └── chennai_aqi_audited.csv # 2,975 curated records with audit flags
└── outputs/
    ├── plots/                     # High-resolution PNG visual artifacts
    └── reports/                   # Audit CSVs, Data Dictionary & Validation Reports
        ├── data_dictionary.csv
        ├── station_pollutant_statistics.csv
        ├── before_after_cleaning_comparison.csv
        ├── final_validation_report.md
        └── faculty_demo_script.md
```

---

## 6. Functional Navigation & Tab Architecture (Top Navbar)

The redesigned dashboard uses Shiny's top `navbarPage` layout with a clean academic light theme (`#F8FAFC`), dark navy header (`#0F172A`), teal accents, and readable 14px typography:

1. **Tab 1: Executive Overview & Station Map**
   - 6 auto-updating KPI cards (Observations, Mean Value, Peak Spike with Station Name, Missingness %, Duplicate Pairs, Audit Flags).
   - Global interactive filters: Date range slider, pollutant selector, and multi-station selector with a **Reset All Filters** button.
   - Interactive Leaflet map (or high-contrast ggplot2 map fallback) displaying the 5 monitoring stations with popups.
2. **Tab 2: Pollution Trends**
   - High-resolution multi-station time series with optional **7-Day Trend Smoothing (LOESS)**.
   - Interactive Plotly tooltips displaying exact calendar dates, concentrations, and station names on hover.
3. **Tab 3: Station Comparison**
   - Radio toggle between **Distribution Boxplots** (median bar, parametric mean diamond, IQR, red outliers) and **CPCB National Health Category Breakdown** (% of days in Good, Moderate, Poor, etc.).
4. **Tab 4: Data Quality & Reliability**
   - Station-by-pollutant missingness heatmap exposing Koyambedu's 58.15% CO sensor downtime.
   - Narrative breakdown of hardware failure logs (PC issues, power outages during Cyclone Michaung).
5. **Tab 5: Before & After Cleaning**
   - Paired bar charts and summary shift table quantifying the impact of deduplicating 16 records.
6. **Tab 6: Data Export & Custom Reports**
   - Instant CSV export for active filtered subsets.
   - Download buttons for station statistics and before/after audit reports.

---

## 7. Installation & Execution Guide

### Prerequisites
- Install **R** ($\ge 4.2.0$) from [cran.r-project.org](https://cran.r-project.org/)
- Install **RStudio Desktop** from [posit.co](https://posit.co/)

### Setup & Launch
1. Open **RStudio**.
2. Set your working directory to the project folder (`setwd("path/to/AQI_TrustLens")`).
3. In the RStudio **Console**, install the required packages:
   ```R
   install.packages(c("shiny", "ggplot2", "dplyr", "readr", "tidyr", "scales", "stringr", "lubridate", "leaflet", "plotly"))
   ```
4. Open [app.R](file:///c:/Users/divya/Downloads/advt/app.R) and click **"Run App"** in RStudio, or execute:
   ```R
   shiny::runApp()
   ```

---

## 8. Summary of Recent Bugfixes & UI Overhaul
- **Navbar Page Structure:** Replaced nested/obscured tabsets with top-level `navbarPage` navigation to ensure all tabs are clearly separated, prominent, and clickable.
- **Academic Light Workspace:** Swapped dark-mode text compression for a spacious, light-themed card layout with 14px typography and clear visual hierarchy.
- **Schema Alignment:** Synchronized column naming across `data_cleaning.R`, `analysis.R`, and `app.R` with robust fallback aliases.
- **High-Contrast Charts:** Styled ggplot2 visualizations with `#FFFFFF` plot backgrounds, slate axes, and distinct station colors.
