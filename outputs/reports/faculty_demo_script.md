# AQI TrustLens: Faculty Demonstration & Viva Script (5–7 Minutes)

## Presentation Objective
Demonstrate an advanced, data-quality-aware environmental dashboard that bridges raw sensor ingestion, transparent quality auditing, and interactive exploration of Chennai's air pollution.

---

### Minute 1: The Problem & Motivation
- **Statement to Faculty:**  
  *"Most air pollution dashboards assume environmental sensor telemetry is 100% clean and infallible. In reality, Indian urban monitoring networks experience frequent power cuts, PC communication failures, duplicate transmissions, and sensor drift."*
- **The Core Value of AQI TrustLens:**  
  *"Rather than blindly deleting anomalies or hiding missing data, AQI TrustLens exposes data quality alongside pollution trends. We quantify missingness, flag physical inconsistencies, and measure how cleaning decisions impact analytical conclusions."*

---

### Minute 2: Tab 1 — Overview & Provenance
- **Action:** Open Tab 1 in the Shiny Dashboard.
- **Key Talking Points:**
  - Point to the dynamic KPI cards: **2,975 real records** across **5 CPCB monitoring stations** (Kodungaiyur, Koyambedu, Manali, Perungudi, Royapuram) covering **Jan 2023 to Aug 2024**.
  - Highlight the audit counters: **16 duplicate entries**, **45 hardware failure notes**, and an overall missingness rate of **3.61%**.
  - Emphasize: *"Every single metric here is dynamically calculated from actual CPCB bulletin records, not hardcoded."*

---

### Minute 3: Tab 2 — Pollution Trends Over Time
- **Action:** Navigate to Tab 2. Select $PM_{2.5}$ or AQI and demonstrate filtering.
- **Key Talking Points:**
  - Demonstrate toggling monitoring stations (e.g., isolating Manali vs. Perungudi).
  - Adjust the date range slider to show seasonal shifts.
  - Explain the spikes: *"Notice the multi-station simultaneous spikes during November/December. Because these peaks occur synchronously across all stations, our pipeline identifies them as genuine post-monsoon winter inversions rather than isolated sensor errors."*

---

### Minute 4: Tab 3 — Station-Wise Distribution & Comparison
- **Action:** Navigate to Tab 3. Select AQI or $PM_{10}$.
- **Key Talking Points:**
  - Explain the box plot: *"Stations are ordered by median exposure. The box captures the IQR (interquartile range), the red diamond denotes the arithmetic mean, and the individual dots display genuine outliers."*
  - Mention microclimates: *"Manali exhibits higher industrial particulate variability, while coastal and residential stations show lower baseline medians. We present this comparison without claiming direct causation."*

---

### Minute 5: Tab 4 — Data Quality & Reliability Heatmap
- **Action:** Navigate to Tab 4.
- **Key Talking Points:**
  - Point out the **Koyambedu CO missingness block (45.04% NA / 268 days)**:
    *"Notice the prominent red tile at Koyambedu for Carbon Monoxide. Without this quality audit, a researcher averaging Chennai's CO levels would receive a severely distorted picture due to an unannounced sensor failure."*
  - Explain the 45 hardware issue notes: *"We systematically extracted raw maintenance notes like 'N/A (PC Issue)' and 'EB Power supply issue' so faculty and analysts know why data was lost."*

---

### Minute 6: Tab 5 — Before-and-After Cleaning Comparison
- **Action:** Navigate to Tab 5.
- **Key Talking Points:**
  - Direct attention to the paired bar chart and comparison table.
  - State the quantitative shift: *"When we deduplicate 16 redundant records, the mean AQI shifts slightly from 67.09 to 66.97 ($\Delta = -0.12$), while the median remains exactly 62.0."*
  - Clarify the scientific nuance: *"Crucially, deduplicating records corrects mathematical double-counting, but we never claim it certifies that remaining observations are 100% noise-free. This honest data provenance is the hallmark of TrustLens."*

---

### Minute 7: Potential Faculty Viva Questions & Model Answers

**Q1: Why did you flag $PM_{2.5} > PM_{10}$ instead of deleting those records?**  
*Answer:* In atmospheric physics, $PM_{2.5}$ is a sub-fraction of $PM_{10}$ (particles $<2.5\mu m$ are part of particles $<10\mu m$). When $PM_{2.5} > PM_{10}$, it indicates optical scattering discrepancies or humidity hygroscopic growth. Deleting them destroys evidence of sensor calibration drift. Non-destructive flagging allows engineers to audit calibration while keeping data intact.

**Q2: What is the main novelty of AQI TrustLens compared to existing dashboards like CPCB's portal?**  
*Answer:* Standard portals only show real-time numbers or static averages with no visibility into sensor downtime, duplicate records, or data reliability. AQI TrustLens makes the data quality audit an interactive, first-class citizen alongside environmental metrics.
