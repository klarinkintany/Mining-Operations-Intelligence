# Mining Operations Analytics & Predictive Cost Intelligence

An end-to-end mining analytics portfolio project combining **data preparation, operational analytics, equipment performance monitoring, safety analytics, and machine learning-based cost prediction**.

The project uses synthetic mining operations data to demonstrate how data analytics and machine learning can support operational visibility, cost control, equipment reliability, and data-driven decision-making across multiple mine sites.

> **Data note:** The dataset is synthetic and should be treated as a portfolio/demo dataset, not as actual operational or financial information from a mining company.

---

## Project Overview

Mining operations generate data across production, operating costs, equipment utilization, maintenance, and workplace safety. Analyzing these areas together can help identify operational patterns, monitor performance, and support better planning.

This project organizes the available data into three analytical workstreams:

| Workstream | Focus | Key outputs |
|---|---|---|
| Production & Cost Analytics | Production volume, operating costs, cost efficiency, and site comparisons | Site cost summaries, monthly trends, cost structure, cost prediction |
| Equipment Performance | Availability, utilization, OEE, downtime, maintenance, and anomalies | Equipment summaries, breakdown analysis, anomaly results |
| Safety Analytics | Incident types, severity, root causes, and lost-time indicators | Prepared safety dataset for safety KPI analysis |

## Project Objectives

- Compare production and cost performance across mining sites.
- Analyze cost per tonne and cost structure by site.
- Monitor equipment availability, utilization, and Overall Equipment Effectiveness (OEE).
- Identify equipment records flagged as potential anomalies for further investigation.
- Explore workplace safety incidents by type, severity, and root cause.
- Build and evaluate a machine learning model to estimate daily mining operating costs.
- Prepare structured outputs that can be used in reporting and Power BI dashboards.

## Mining Sites Covered

The prepared cost-efficiency summary contains five mining sites:

| Site | Commodity | Status |
|---|---|---|
| Iron Ridge Mine | Iron Ore | Operational |
| Golden Valley Mine | Gold | Operational |
| Lithium Creek Mine | Lithium | Operational |
| Copper Hills Mine | Copper | Operational |
| Nickel Point Mine | Nickel | Care & Maintenance |

The available records cover the 2025 calendar year. Nickel Point Mine is in Care & Maintenance status and has no mined tonnes in the site summary; production-based efficiency measures are therefore not applicable for that site.

## Key Analytical Areas

### 1. Production & Cost Analytics

The production and cost outputs support analysis of:

- Total tonnes mined and processed.
- Total operating cost (AUD).
- Cost per tonne mined and processed.
- Production target attainment.
- Average daily production and cost.
- Monthly site-level production and cost trends.
- Cost structure across labor, equipment, fuel, maintenance, consumables, utilities, and administration.
- Relationship between production volume and operating cost.

**Main output files:**

- `site_cost_efficiency_summary.csv`
- `site_cost_structure.csv`
- `monthly_site_trends.csv`
- `production_cost_relationship.csv`

### 2. Equipment Performance & Anomaly Detection

Equipment analytics cover five equipment categories:

- Haul Truck
- Excavator
- Dozer
- LHD Loader
- Jumbo Drill

Performance indicators include:

- Availability (%)
- Utilization (%)
- OEE (%)
- Operating hours
- Breakdown hours
- Maintenance hours
- Maintenance cost (AUD)
- Fuel consumption (liters)

The anomaly output contains an `anomaly_score` and an `anomaly_status` field. Records labeled `Potential Anomaly` should be treated as investigation candidates, not confirmed equipment failures.

**Main output files:**

- `equipment_type_summary.csv`
- `equipment_breakdown_level_summary.csv`
- `equipment_anomaly_results.csv`

### 3. Safety Analytics

The prepared safety dataset contains 360 incident records and includes:

- Incident date and mine site.
- Incident type and severity.
- Incident description and root cause.
- Investigation status.
- Days lost.
- Lost Time Injury (LTI) indicator.
- Medical Treatment Injury (MTI) indicator.
- Open investigation indicator.
- Workforce size.

These fields can support analysis of incident frequency, severity distribution, root causes, investigation status, and lost-time indicators.

**Main output file:**

- `safety_prepared.csv`

---

## Machine Learning: Operating Cost Prediction

A Random Forest Regressor was developed using a scikit-learn Pipeline to estimate daily total operating cost (`total_cost_aud`).

### Model configuration

| Item | Configuration |
|---|---|
| Algorithm | Random Forest Regressor |
| Target | `total_cost_aud` |
| Features | `site_id`, `month_num`, `day_of_week`, `day_of_year`, `tonnes_mined` |
| Data split | Time-based split by date |
| Training records | 1,460 |
| Testing records | 365 |
| Test period | 2025-10-20 to 2025-12-31 |

### Model evaluation

The saved metrics file compares three approaches:

| Model | MAE (AUD) | RMSE (AUD) | R² | WAPE |
|---|---:|---:|---:|---:|
| Site Average Baseline | 138,206.79 | 300,963.74 | 0.9531 | 9.2525% |
| Linear Model per Site | 37,037.89 | 57,360.73 | 0.9983 | 2.4796% |
| Random Forest | 44,412.05 | 78,915.84 | 0.9968 | 2.9732% |

**Interpretation:** On the saved test set, the Random Forest performed substantially better than the site-average baseline. The per-site linear model achieved the strongest scores among the three evaluated approaches. This comparison is important: a more complex model is not automatically the best model for every dataset.

These results are specific to the synthetic dataset and its time-based test period. They should not be interpreted as evidence of equivalent performance on real mining operations.

**Main output files:**

- `cost_model_metrics.json`
- `cost_model_predictions.csv`
- `random_forest_cost_model.joblib`

## Data Preparation & Quality Checks

Prepared datasets and supporting documentation are included in the archive.

- `equipment_prepared.csv` — prepared equipment-level records with additional calendar and operational flags.
- `safety_prepared.csv` — prepared safety incident records.
- `prepared_data_dictionary.csv` — column-level descriptions and data types.
- `data_quality_audit.csv` — data quality validation results.

The supplied quality audit reports **40 checks with Pass status** and no failed checks in the provided audit file. This describes the checks recorded in that file; it does not guarantee that every possible data issue has been tested.

---

## Repository Structure

```text
.
├── README.md
└── Data/
    ├── equipment_analytics/
    │   └── equipment_analytics_results/
    │       ├── equipment_anomaly_results.csv
    │       ├── equipment_breakdown_level_summary.csv
    │       └── equipment_type_summary.csv
    │
    ├── prepared_data/
    │   └── prepared_data/
    │       ├── data_quality_audit.csv
    │       ├── equipment_prepared.csv
    │       ├── prepared_data_dictionary.csv
    │       └── safety_prepared.csv
    │
    └── production_cost_results/
        └── production_cost_results/
            ├── cost_model_metrics.json
            ├── cost_model_predictions.csv
            ├── monthly_site_trends.csv
            ├── production_cost_relationship.csv
            ├── random_forest_cost_model.joblib
            ├── site_cost_efficiency_summary.csv
            └── site_cost_structure.csv
```

## Tools & Technologies

The supplied files demonstrate outputs associated with a data analytics and machine learning workflow. The project can be explored or extended with:

- **Python** — data preparation and analysis.
- **Pandas / NumPy** — data manipulation.
- **Matplotlib / Seaborn** — exploratory data analysis and visualization.
- **Scikit-learn** — machine learning and model evaluation.
- **Power BI** — operational dashboards and reporting.
- **SQL** — querying and aggregating structured operational data.

The archive contains prepared datasets and model outputs; it does not include the original notebooks or scripts used to generate every output.

## How to Use This Dataset

1. Download or clone this repository.
2. Extract the `Data` directory.
3. Load the CSV files into Python, SQL, or Power BI.
4. Start with `prepared_data` for equipment and safety analysis.
5. Use `production_cost_results` for site-level cost analysis and model evaluation.
6. Use `equipment_analytics_results` to explore equipment performance and potential anomalies.

Example: load the prepared equipment dataset with Pandas.

```python
import pandas as pd

equipment = pd.read_csv(
    "Data/prepared_data/prepared_data/equipment_prepared.csv"
)

print(equipment.head())
print(equipment.info())
```

Example: inspect saved model metrics.

```python
import json

with open(
    "Data/production_cost_results/production_cost_results/cost_model_metrics.json",
    "r"
) as file:
    metrics = json.load(file)

print(metrics)
```

## Potential Dashboard KPIs

The prepared outputs can be used to build a multi-page Power BI report.

| Dashboard page | Suggested KPIs and visuals |
|---|---|
| Executive Overview | Total tonnes mined, total operating cost, cost per tonne, target attainment, site comparison |
| Production & Cost | Monthly production trend, monthly cost trend, cost per tonne by site, cost structure |
| Equipment Performance | Average OEE, availability, utilization, breakdown hours, maintenance cost by equipment type |
| Anomaly Monitoring | Normal vs potential anomaly records, anomaly score distribution, equipment and site drill-down |
| Safety Performance | Incident count, severity distribution, incident type, root cause, days lost, investigation status |

## Limitations & Considerations

- The dataset is synthetic and does not represent a real mine or company.
- The anomaly labels are indicators for further review, not proof of actual failures.
- Model performance is measured on the supplied time-based test set and may change with different data, features, or validation methods.
- The test period is relatively short; additional time-based validation is recommended before operational use.
- Cost and production comparisons should account for differences in commodity, site scale, operating status, and unit basis.
- Nickel Point Mine has zero mined tonnes in the supplied site summary, so cost-per-tonne and production target metrics are not meaningful for that site.
- The ZIP archive contains prepared data and analytical outputs, but not the complete source code or dashboard file.

## Future Improvements

- Add reproducible Python notebooks or scripts for the complete data pipeline.
- Add SQL queries and a documented data model.
- Build an interactive Power BI dashboard with site, date, commodity, and equipment filters.
- Investigate potential equipment anomalies using maintenance history and operating context.
- Compare additional forecasting models and use rolling time-series validation.
- Add explainability techniques such as feature importance and SHAP.
- Expand safety analysis with exposure-adjusted rates when suitable exposure data is available.

---

## Project Summary

This portfolio project demonstrates how mining operational data can be transformed into structured analytical outputs for production monitoring, cost efficiency analysis, equipment performance management, safety reporting, and predictive cost estimation.

**Focus:** Mining Analytics | Operational Performance | Cost Intelligence | Equipment Reliability | Safety Analytics | Machine Learning
