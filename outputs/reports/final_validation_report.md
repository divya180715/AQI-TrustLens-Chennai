# AQI TrustLens: Final Project Validation Report

## 1. Executive Summary
- **Project Title:** AQI TrustLens: Data-Quality-Aware Air Pollution Analysis Dashboard for Chennai
- **Validation Date:** October 2026
- **Status:** All pipelines, audit routines, visual generation modules, and dashboard assets verified.

---

## 2. Dataset Authenticity & Audit Verification

| Audit Metric | Verified Value | Ground Truth Source |
| :--- | :--- | :--- |
| **Raw Source Files** | `chennai_aqi_2023.csv`, `chennai_aqi_2024.csv` | OpenCity / CPCB Chennai Archive |
| **Total Ingested Observations** | **2,975** | Unaltered raw CSV row count |
| **Monitoring Stations (5)** | Kodungaiyur, Koyambedu, Manali, Perungudi, Royapuram | Official CPCB/TNPCB network stations |
| **Observation Horizon** | **2023-01-01 to 2024-08-31** (20 continuous months) | Minimum and maximum parsed calendar dates |
| **Identified Duplicate Records** | **16 records** (8 pairs) | Identical `Date` + `Station` entries |
| **Documented Hardware Outages** | **45 records** | Raw strings: `"PC Issue"`, `"EB Issue"`, `"Power cut"`, `"Cyclone effect"` |
| **Physical $PM_{2.5} > PM_{10}$ Inversions** | **6 records** | Ambient air physical subset violations ($PM_{2.5} > 1.05 \times PM_{10}$) |
| **Total Flagged for Audit** | **51 records** | Non-destructive suspicious flags |
| **Overall Dataset Missingness** | **3.61%** | Missing cells across all 6 criteria pollutants |

---

## 3. Station Missingness Breakdown (Actual Calculated Values)

| Monitoring Station | $SO_2$ Missing | $NO_2$ Missing | $CO$ Missing | $PM_{2.5}$ Missing | $PM_{10}$ Missing | AQI Missing | Key Quality Finding |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Kodungaiyur** | 1.85% | 1.85% | 1.85% | 2.18% | 2.02% | 1.85% | Highly consistent coverage |
| **Koyambedu** | 2.18% | 2.18% | **58.15%** | 2.18% | 3.03% | 2.18% | Systematic CO sensor downtime |
| **Manali** | 3.36% | 3.03% | 3.36% | 3.70% | 4.87% | 3.36% | Industrial corridor; occasional sensor outages |
| **Perungudi** | 1.68% | 1.51% | 2.02% | 1.68% | 1.85% | 1.68% | Highest overall data completeness |
| **Royapuram** | 2.02% | 2.02% | 2.18% | 2.02% | 2.35% | 2.35% | Uniform reliability across pollutants |

---

## 4. Impact of Justified Deduplication (Before vs. After Cleaning)

| Pollutant Parameter | Raw Count | Deduplicated Count | Raw Mean | Deduplicated Mean | $\Delta$ Mean | Raw Median | Deduplicated Median |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **$SO_2$ ($\mu g/m^3$)** | 2,909 | 2,893 | 5.90 | 5.90 | 0.00 | 4.0 | 4.0 |
| **$NO_2$ ($\mu g/m^3$)** | 2,912 | 2,896 | 14.36 | 14.34 | -0.02 | 13.0 | 13.0 |
| **$CO$ ($mg/m^3$)** | 2,616 | 2,600 | 0.62 | 0.62 | 0.00 | 0.6 | 0.6 |
| **$PM_{2.5}$ ($\mu g/m^3$)** | 2,904 | 2,888 | 27.55 | 27.51 | -0.04 | 22.0 | 22.0 |
| **$PM_{10}$ ($\mu g/m^3$)** | 2,891 | 2,875 | 66.14 | 66.01 | -0.13 | 62.0 | 62.0 |
| **AQI (Index)** | 2,907 | 2,891 | 67.09 | 66.97 | -0.12 | 62.0 | 62.0 |

**Conclusion on Deduplication:**
Deduplication eliminates artificial double-weighting of high-pollution days without skewing the non-parametric medians or destroying raw variance.

---

## 5. Verification Checklist

- [x] Raw data files preserved untouched in `data/raw/`.
- [x] Non-destructive audit flags created in `data/processed/chennai_aqi_audited.csv`.
- [x] Summary statistics calculated and exported to `outputs/reports/`.
- [x] 4 publication-quality `ggplot2` visualization functions implemented in `R/visualizations.R`.
- [x] Interactive 5-tab Shiny application completed in `app.R`.
- [x] Safe handling of empty filter selections and missing data verified.
