
# Mining Operations Intelligence

### End-to-End Data Analytics, Machine Learning & Operational Performance Project


------------------------------------------------------------------------

## Project Overview

Mining Operations Intelligence is an end-to-end analytics project built
around a **synthetic mining operations database**. It demonstrates a
reproducible workflow for auditing data quality, exploring operational
performance, preparing analytical datasets, analyzing equipment and
safety indicators, and estimating operating costs.

The project covers five mine sites over the 2025 calendar year. Its
outputs support analytical reporting and portfolio demonstration; they
do **not** represent the actual performance of a mining company.

## Project Objectives

-   Audit the structure, completeness, consistency, and reliability of
    mining database tables.
-   Explore production, operating costs, equipment performance,
    maintenance, and safety.
-   Prepare integrated, documented datasets for downstream analysis.
-   Identify unusual equipment-days using an unsupervised
    anomaly-detection method.
-   Compare approaches for estimating daily operating costs.
-   Present operational KPIs and trends through Power BI dashboards.

## Technology Stack

  Area                Tools
  ------------------- ---------------------------------
  Programming         Python
  Data manipulation   Pandas, NumPy
  Database            SQLite, SQL
  Visualization       Matplotlib, Power BI
  Machine learning    Scikit-learn
  Model persistence   Joblib
  Reporting           Power BI, DAX
  Environment         Google Colab / Jupyter Notebook

## Project Workflow

1.  **Database audit** --- inspect schema, table coverage, missing
    values, duplicate keys, cost reconciliation, and logical
    consistency.
2.  **Exploratory data analysis** --- analyze production, monthly
    trends, operating costs, equipment performance, maintenance, and
    safety.
3.  **Data preparation and feature engineering** --- integrate
    production, cost, and mine-site records; aggregate equipment and
    safety data at site-day level; create documented analytical
    features.
4.  **Equipment and safety preparation** --- audit equipment and
    incident records, validate metric definitions, and export
    analysis-ready tables with audit documentation.
5.  **Equipment performance analytics** --- analyze OEE, downtime,
    maintenance cost, fuel intensity, and equipment-level patterns;
    apply Isolation Forest to flag potential anomalies.
6.  **Production and cost efficiency** --- analyze site-level production
    and cost, monthly patterns, cost structure, and production-cost
    relationships; compare daily cost-estimation models.
7.  **Power BI reporting** --- use prepared CSV outputs to build
    interactive operational dashboards.

## Notebook Guide

All six notebooks are located in `Code/notebooks/`.

  -----------------------------------------------------------------------------------------------------------------------
  Notebook                                              Description             Main outputs / purpose
  ----------------------------------------------------- ----------------------- -----------------------------------------
  `01_Mining_Operations_Database_Audit_clean.ipynb`     Database setup and data Database structure, coverage,
                                                        quality audit           missing-value, duplicate, reconciliation,
                                                                                and consistency checks

  `02_Mining_Operations_EDA_clean.ipynb`                Exploratory data        Production, cost, equipment, maintenance,
                                                        analysis                safety, and extended operational analysis

  `03_Mining_Operations_Data_Preparation_clean.ipynb`   Data preparation and    `mining_operations_prepared.csv` and
                                                        feature engineering     `mining_operations_data_dictionary.csv`

  `04_Equipment_Safety_Data_Preparation_clean.ipynb`    Equipment and safety    `equipment_prepared.csv`,
                                                        data preparation        `safety_prepared.csv`,
                                                                                `data_quality_audit.csv`, and
                                                                                `prepared_data_dictionary.csv`

  `05_Equipment_Performance_Analytics_clean.ipynb`      Equipment performance   Equipment summaries and
                                                        and anomaly detection   `equipment_anomaly_results.csv`

  `06_Production_Cost_Efficiency_clean.ipynb`           Production and cost     Site/monthly cost and production
                                                        efficiency analysis     summaries, model predictions, metrics,
                                                                                and saved Random Forest pipeline
  -----------------------------------------------------------------------------------------------------------------------

## Dataset Scope

The source database is `mining_operations.db`. The notebooks query the
database tables directly using SQL.

  Data area               Coverage described in the notebooks
  ----------------------- -------------------------------------------
  Mine sites              5 sites
  Production and cost     365 days per site; 1,825 site-day records
  Equipment performance   22 units × 365 days = 8,030 records
  Safety incidents        360 incident records
  Reporting period        1 January -- 31 December 2025

The five mine sites represented in the analysis are Iron Ridge, Golden
Valley, Lithium Creek, Copper Hills, and Nickel Point.

## Machine Learning & Analytical Methods

### 1. Equipment Anomaly Detection

Notebook 05 uses **Isolation Forest** from scikit-learn to flag unusual
equipment-day records.

-   The model uses equipment performance and maintenance-related
    features.
-   `contamination=0.02` is an assumed threshold that controls the
    expected share of records flagged.
-   The notebook checks flagged records against breakdown days and
    evaluates sensitivity to the contamination setting and stability
    across random seeds.
-   A flagged record is a **potential anomaly for review**, not proof of
    equipment failure.

### 2. Daily Operating Cost Estimation

Notebook 06 compares three approaches for estimating daily operating
cost from site, calendar, and daily mined-tonnage information:

-   Site-average baseline
-   Linear regression fitted separately for each site
-   Random Forest Regressor pipeline

The notebook evaluates model results using MAE, RMSE, R², and site-level
MAPE, and uses permutation importance to inspect Random Forest inputs.

**Important interpretation:** this is cost estimation for a known
production volume, not a future production or cost forecast. The
notebook reports that per-site linear regression performed best in its
evaluation; Random Forest did not outperform this simpler approach. The
saved Random Forest model is retained for comparison and
reproducibility.

## Power BI Dashboard

The Power BI report uses exported analytical CSV files to present
operational information such as:

-   Total tonnes mined and processed
-   Production trends by month
-   Production and processed tonnes by mine site
-   Operating cost and cost per tonne
-   Equipment OEE and downtime
-   Safety indicators
-   Equipment anomaly results, where included in the report

Dashboard visuals should be interpreted according to the grain and
definitions of their source tables. For example, monthly summary data
supports monthly trends; it should not be presented as daily or weekly
production data.

## Key Findings from the Synthetic Dataset

The notebooks report the following patterns within this demonstration
dataset:

-   Production scale varies substantially by mine site. Iron Ridge
    contributes the largest production volume.
-   Nickel Point is marked as **Care & Maintenance** and records no
    mined production while retaining fixed operating costs.
-   Equipment OEE varies by equipment type. The notebook reports the
    highest average OEE for Haul Trucks and the lowest for Jumbo Drills.
-   Breakdown days account for a disproportionate share of maintenance
    cost in the equipment dataset.
-   Isolation Forest primarily flags records associated with breakdown
    days and some high-maintenance-cost days.
-   Daily operating cost is strongly associated with daily production
    volume in the synthetic data.
-   Per-site linear regression provides a more accurate cost estimate
    than the Random Forest model in the notebook's evaluation.

These findings describe the constructed dataset only. They should not be
generalized to real mines.

## Repository Structure

The supplied ZIP contains the following notebook structure:

``` text
Code/
└── notebooks/
    ├── 01_Mining_Operations_Database_Audit_clean.ipynb
    ├── 02_Mining_Operations_EDA_clean.ipynb
    ├── 03_Mining_Operations_Data_Preparation_clean.ipynb
    ├── 04_Equipment_Safety_Data_Preparation_clean.ipynb
    ├── 05_Equipment_Performance_Analytics_clean.ipynb
    └── 06_Production_Cost_Efficiency_clean.ipynb
```

The notebooks export their generated CSV files and model artifacts into
their configured output folders (for example, `prepared_data`,
`equipment_analytics_results`, and `production_cost_results`). Those
generated outputs are not included in this `Code.zip` archive unless
added separately.

## How to Run

1.  Download or clone the repository containing the project notebooks
    and source database.

2.  Open the notebooks in Google Colab or Jupyter Notebook.

3.  Make sure `mining_operations.db` is available at the database path
    configured in each notebook.

4.  Install the required Python packages if they are not already
    available:

    ``` bash
    pip install pandas numpy matplotlib scikit-learn joblib
    ```

5.  Run the notebooks in sequence from 01 to 06. Some notebooks use
    outputs or prepared data generated by earlier stages; follow each
    notebook's database path and output-folder settings.

6.  Connect the exported CSV files to Power BI and build or refresh the
    report.

## Limitations & Responsible Use

-   **Synthetic data:** this project is for portfolio and analytical
    demonstration, not a representation of real company operations.
-   **One-year coverage:** the dataset covers 2025 only; long-term
    seasonality and multi-year trends cannot be validated.
-   **Anomaly interpretation:** Isolation Forest flags unusual records
    for investigation; it does not confirm equipment failure.
-   **Cost model scope:** the cost-estimation model uses known daily
    production information and is not a future forecasting system.
-   **Site comparability:** mine sites produce different commodities and
    operate at very different scales. Cost-per-tonne values should not
    be used to rank site efficiency without considering commodity, unit
    basis, and each site's own target.
-   **Model validation:** all model results are specific to the
    synthetic dataset and require validation on real operational data
    before operational use.

## Author

**Mining Operations Intelligence --- Portfolio Project**

Developed as an end-to-end demonstration of data analytics, SQL, data
preparation, machine learning, and Power BI reporting for the mining
industry.

------------------------------------------------------------------------

::: {align="center"}
**Python · SQL · Machine Learning · Power BI**
:::
