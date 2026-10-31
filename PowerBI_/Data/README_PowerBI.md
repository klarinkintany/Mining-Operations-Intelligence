# Mining Operations Performance Dashboard | Power BI

An interactive **Power BI dashboard for mining operations** designed to monitor production performance, operating costs, equipment reliability, and workplace safety across multiple mine sites.

The project combines a Power BI report (`.pbip`), a semantic model, CSV source tables, and documented DAX measures. It demonstrates how operational data can be organized into a consistent reporting model and translated into actionable management insights.

> **Data note:** The included dataset is synthetic/demo data for portfolio and learning purposes. It does not represent actual operational results from a mining company.

---

## Dashboard Overview

The report contains five analytical pages:

| Page | Focus | Questions it helps answer |
|---|---|---|
| 01 — Executive Overview | Overall mining performance | How are the mine sites performing across key operational KPIs? |
| 02 — Production Analytics | Production volume and target performance | How much material was mined and processed, and how does production compare with targets? |
| 03 — Equipment Performance | Equipment availability, utilization, OEE, downtime, and anomalies | Which equipment groups show reliability or utilization issues? |
| 04 — Cost & Efficiency | Operating cost, cost per tonne, cost structure, and volume-cost relationship | Where are operating costs concentrated, and how efficiently is production delivered? |
| 05 — Safety & Risk Monitoring | Incident frequency, severity, lost-time indicators, and investigations | What safety risks and incident patterns need management attention? |

## Project Objectives

- Build a consolidated view of mining operations across five sites.
- Monitor production volume, processing volume, and annual target attainment.
- Compare operating costs and cost per tonne across sites.
- Track equipment OEE, availability, utilization, breakdowns, and maintenance.
- Highlight equipment records flagged as potential anomalies.
- Monitor safety incidents, severity, lost-time injuries, and investigation status.
- Use reusable DAX measures and a date/site-based semantic model to support interactive reporting.

## Mine Sites

The dashboard data covers five sites and their respective commodities:

| Mine site | Commodity | Status |
|---|---|---|
| Iron Ridge Mine | Iron Ore | Operational |
| Golden Valley Mine | Gold | Operational |
| Lithium Creek Mine | Lithium | Operational |
| Copper Hills Mine | Copper | Operational |
| Nickel Point Mine | Nickel | Care & Maintenance |

The source tables cover the 2025 calendar year. Some report pages apply filters to focus on operational sites. Nickel Point Mine is marked Care & Maintenance in the site dimension.

## Data Model

The semantic model uses two dimension tables and four fact tables.

### Dimension tables

| Table | Rows | Description |
|---|---:|---|
| `DimDate` | 365 | Daily calendar for 2025, including year, month, month number, and quarter |
| `DimSite` | 5 | Site attributes, commodity, operational status, annual targets, processed tonnes, plan adherence, and cost relationship metrics |

### Fact tables

| Table | Rows | Description |
|---|---:|---|
| `FactMonthly` | 60 | Monthly production volume, number of days, and total operating cost by site |
| `FactEquipment` | 8,030 | Daily equipment performance, operating hours, downtime, maintenance, fuel, and anomaly fields |
| `FactCostStructure` | 35 | Operating cost by site and cost category |
| `FactSafety` | 360 | Safety incident records, severity, root cause, days lost, and investigation indicators |

### Key fields

- **Production:** `tonnes_mined`, `tonnes_processed`, `annual_target_tonnes`, `avg_plan_adherence_pct`
- **Cost:** `total_cost_aud`, `cost_aud`, `variable_cost_per_tonne_aud`, `fixed_cost_per_day_aud`
- **Equipment:** `availability_pct`, `utilization_pct`, `oee_pct`, `breakdown_hours`, `maintenance_hours`, `maintenance_cost_aud`
- **Safety:** `severity`, `incident_type`, `root_cause`, `days_lost`, `is_lost_time_injury`, `is_medical_treatment_injury`, `is_open_investigation`

## Key Performance Indicators

### Production

- Total tonnes mined
- Total tonnes processed
- Annual production target
- Target attainment (%)
- Average plan adherence (%)
- Processing ratio (%)

### Cost & Efficiency

- Total operating cost (AUD)
- Cost per tonne mined (AUD)
- Average daily cost per site (AUD)
- Cost share by site (%)
- Cost by category (AUD)
- Variable cost per tonne (AUD)
- Fixed cost per day (AUD)
- Volume-cost correlation and R²

### Equipment

- Average OEE (%)
- Average availability (%)
- Average utilization (%)
- Total operating hours
- Total breakdown hours
- Total maintenance hours
- Total maintenance cost (AUD)
- Equipment units
- Anomaly days and anomaly rate (%)

### Safety

- Total safety incidents
- Lost Time Injury (LTI) count
- Medical Treatment Injury (MTI) count
- Days lost
- High-severity incidents
- Open investigations
- Open investigation rate (%)

## DAX Measures

The project includes a separate `DAX_Measures.md` reference file with measure definitions and formatting. Measures are grouped into four areas:

- **Cost:** operating cost, cost per tonne, daily cost, cost share, cost structure, volume-cost correlation, and R².
- **Equipment:** OEE, availability, utilization, breakdown hours, maintenance hours/cost, operating hours, equipment count, and anomaly rate.
- **Production:** mined and processed tonnes, annual target, plan adherence, target attainment, and processing ratio.
- **Safety:** incident count, LTI, MTI, days lost, high-severity incidents, and open investigations.

Example DAX:

```dax
Total Operating Cost (AUD) =
SUM(FactMonthly[total_cost_aud])
```

```dax
Cost per Tonne Mined (AUD) =
DIVIDE(
    [Total Operating Cost (AUD)],
    [Total Tonnes Mined]
)
```

```dax
Avg OEE % =
AVERAGE(FactEquipment[oee_pct])
```

```dax
Total Safety Incidents =
COUNTROWS(FactSafety)
```

## Repository Structure

```text
Power BI/
├── README.md
├── DAX_Measures.md
├── MiningDashboard.pbip
├── MiningDashboard.Report/
│   └── definition/
│       └── pages/
│           ├── p01/   # Executive Overview
│           ├── p02/   # Production Analytics
│           ├── p03/   # Equipment Performance
│           ├── p04/   # Cost & Efficiency
│           └── p05/   # Safety & Risk Monitoring
├── MiningDashboard.SemanticModel/
│   └── definition/
│       ├── model.tmdl
│       ├── relationships.tmdl
│       └── tables/
│           ├── DimDate.tmdl
│           ├── DimSite.tmdl
│           ├── FactCostStructure.tmdl
│           ├── FactEquipment.tmdl
│           ├── FactMonthly.tmdl
│           └── FactSafety.tmdl
├── MiningTheme.json
└── Data/
    ├── dim_date.csv
    ├── dim_site.csv
    ├── fact_cost_structure.csv
    ├── fact_equipment.csv
    ├── fact_monthly.csv
    └── fact_safety.csv
```

## Tools & Technologies

- **Microsoft Power BI Desktop** — report development and interactive visualization.
- **Power Query** — data loading and transformation.
- **DAX** — KPI calculations and filter-aware measures.
- **Power BI Project (PBIP)** — text-based report and semantic model project structure.
- **CSV** — source data tables.
- **Tabular Model Definition Language (TMDL)** — semantic model metadata and table definitions.

## How to Open the Project

1. Download and extract the `Power BI` folder from this repository.
2. Install or open a compatible version of **Power BI Desktop** that supports Power BI Project (`.pbip`) files.
3. Open `MiningDashboard.pbip`.
4. If Power BI prompts for data source paths, point the queries to the CSV files in the `Data` folder.
5. Refresh the data and review the five report pages.
6. If you make changes to the model or report, save the project from Power BI Desktop.

Keep the `MiningDashboard.Report`, `MiningDashboard.SemanticModel`, `Data`, and `.pbip` files together in their original relative folder structure.

## Suggested Portfolio Walkthrough

When presenting this project to a recruiter or interviewer:

1. Start with the Executive Overview to explain the business context and high-level KPIs.
2. Show Production Analytics to discuss production volume, target attainment, and site comparisons.
3. Explain Equipment Performance using OEE, availability, utilization, breakdown, and anomaly indicators.
4. Use Cost & Efficiency to demonstrate cost-per-tonne analysis and cost drivers.
5. Finish with Safety & Risk Monitoring to show how incident and investigation data can support safety management.

Focus on the operational question behind each visual, what the KPI measures, and what action a mining operations team could investigate based on the result.

## Limitations & Interpretation

- The dataset is synthetic and intended for demonstration, not operational decision-making.
- Equipment anomaly fields identify records for further investigation; they do not prove a mechanical failure.
- OEE, availability, utilization, and cost measures should be interpreted using their defined calculation logic and the relevant filter context.
- Cost and production comparisons should consider differences in commodity, site scale, and operating status.
- Safety incident counts alone do not measure exposure-adjusted risk. Rates such as TRIFR or LTIFR require suitable hours-worked data and clearly defined calculation standards.
- The dashboard is a reporting and analytics portfolio project; it is not a live connection to mine control systems or enterprise operational databases.

## Future Improvements

- Add screenshots or a short walkthrough GIF of all five report pages.
- Add a documented relationship diagram and KPI glossary.
- Add drill-through pages for individual sites and equipment units.
- Add time-intelligence comparisons such as month-over-month and year-to-date performance.
- Add exposure-adjusted safety rates when workforce hours are available.
- Connect the report to a refreshable database or data warehouse.
- Add row-level security if the report is adapted for multi-site business users.

---

## Project Summary

This Power BI project demonstrates how mining production, cost, equipment, and safety data can be brought together in one interactive reporting solution.

**Portfolio focus:** Power BI | DAX | Data Modeling | Mining Analytics | Production Performance | Cost Efficiency | Equipment Reliability | Safety Analytics
