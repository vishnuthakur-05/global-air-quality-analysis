# Global Air Quality Analysis

End-to-end analysis of city-level Air Quality Index (AQI) data: data cleaning and validation in Python, 20 analytical SQL queries in MySQL, unsupervised and supervised machine learning, and a 5-page interactive Power BI dashboard.

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Key Results](#key-results)
3. [Dataset](#dataset)
4. [Repository Structure](#repository-structure)
5. [Methodology](#methodology)
6. [Results in Detail](#results-in-detail)
7. [Dashboard](#dashboard)
8. [How to Run](#how-to-run)
9. [Limitations](#limitations)
10. [Future Work](#future-work)
11. [Author](#author)

---

## Project Overview

**Problem.** Air quality data covers thousands of cities with several pollutant readings each. Raw data has missing values and extreme readings, and its patterns are not visible without analysis. Decision-makers need to know which pollutants and regions drive poor air quality and how cities group into pollution profiles.

**Objectives**
- Clean and validate the raw data (missing values, duplicates, outliers, data types, valid categories).
- Answer business questions in SQL (rankings, hazardous share by country, quartiles, comparisons with global and national averages).
- Segment cities into pollution profiles with K-Means and Agglomerative clustering.
- Classify AQI category with Logistic Regression, Random Forest and SVM, and identify the dominant pollutant.
- Test whether national wealth (GDP per capita) explains national air quality.
- Deliver the findings in an interactive Power BI dashboard.

**Pipeline**

```
Raw CSV -> Python cleaning + EDA -> cleaned CSV -> MySQL analytics
                                        |-> ML (clustering, classification, GDP regression)
                                        |-> Power BI dashboard (cleaned data + cluster labels)
```

---

## Key Results

| Metric | Value |
|---|---|
| Records analyzed | 23,463 raw rows, 23,462 after cleaning |
| Countries | 175 named countries, plus an `Unknown` group (427 cities without a country label) |
| Global mean / median AQI | 72.0 / 55 (maximum 500) |
| Cities in the Hazardous category | 0.8% |
| Dominant pollutant | PM2.5 is the highest sub-index in roughly 78% of cities |
| Random Forest importance of PM2.5 | 0.84 |
| Random Forest accuracy | 99.87% on the held-out test set; 99.93% mean 5-fold CV |
| Logistic Regression accuracy | 94.23% |
| SVM accuracy | 96.00% (on a 3,000-row stratified sample) |
| GDP per capita vs country mean AQI | No useful linear relationship (test R2 = -0.35) |

> **Read the classification results carefully.** The AQI category is defined from the overall AQI, which is the highest of the four pollutant sub-indices. The classifiers use those sub-indices as features, so the near-perfect Random Forest score largely reflects the definition of the label rather than forecasting skill. See [Limitations](#limitations).

---

## Dataset

| Item | Detail |
|---|---|
| Source | Global Air Quality / Global Air Pollution dataset. **Add your source link here (for example the Kaggle dataset URL and license).** |
| Raw file | `dataset.csv` (read with `encoding="latin1"`) |
| Shape | 23,463 rows x 12 columns |
| Granularity | One row per city; snapshot data with **no date column** |

**Columns**

| Column | Description |
|---|---|
| `Country`, `City` | Location identifiers |
| `AQI Value`, `AQI Category` | Overall AQI (0 to 500) and its category |
| `CO AQI Value`, `CO AQI Category` | Carbon monoxide sub-index and category |
| `Ozone AQI Value`, `Ozone AQI Category` | Ozone sub-index and category |
| `NO2 AQI Value`, `NO2 AQI Category` | Nitrogen dioxide sub-index and category |
| `PM2.5 AQI Value`, `PM2.5 AQI Category` | Fine particulate matter sub-index and category |

**AQI categories**

| AQI range | Category |
|---|---|
| 0 to 50 | Good |
| 51 to 100 | Moderate |
| 101 to 150 | Unhealthy for Sensitive Groups |
| 151 to 200 | Unhealthy |
| 201 to 300 | Very Unhealthy |
| 301 and above | Hazardous |

**Summary statistics**

| Statistic | AQI | CO | Ozone | NO2 | PM2.5 |
|---|---|---|---|---|---|
| Mean | 72.01 | 1.37 | 35.19 | 3.06 | 68.52 |
| Median | 55 | 1 | 31 | 1 | 54 |
| Std | 56.06 | 1.83 | 28.10 | 5.25 | 54.80 |
| Max | 500 | 133 | 235 | 91 | 500 |

The mean is above the median, so the distribution is right-skewed: most cities are clean and a minority are heavily polluted.

---

## Repository Structure

```
global-air-quality-analysis/
├── README.md
├── requirements.txt
├── .gitignore
├── notebooks/
│   ├── 01_data_analysis.ipynb     # cleaning, validation, EDA
│   └── 02_ml_models.ipynb         # clustering, classification, GDP regression
├── sql/
│   └── aqi_queries.sql            # schema, load, 20 analytical queries, view, procedure
├── data/
│   └── air_quality_clean.csv      # cleaned dataset used by SQL and Power BI
└── dashboards/
    └── screenshots/               # 5 dashboard page screenshots
```

Files produced by the notebooks: `cleaned_air_quality.csv` (cleaned data), `cluster_labels.csv` (K-Means label per city, used in Power BI), `feature_importance.csv`, `cleaning_summary.json`, and `world_bank_gdp_per_capita.csv` (cached API result).

---

## Methodology

### 1. Data cleaning and validation (`01_data_analysis.ipynb`)

| Step | Action | Result |
|---|---|---|
| Missing `Country` | Filled with `"Unknown"` | 427 cities (1.82%) |
| Missing `City` | Row dropped | 1 row (23,463 -> 23,462) |
| Duplicates | `df.duplicated()` check | 0 duplicate rows found |
| Text clean-up | `str.strip()` on Country and City | Prevents split groups |
| Validation | Assertions: five numeric columns are integers; categories are only the six valid AQI bands | All checks passed |
| Outlier screening | IQR method on `AQI Value`, fences [-21.0, 139.0] | 2,935 cities (12.51%) flagged, **all retained** |

**Why outliers were kept.** AQI is naturally right-skewed, so the IQR fence flags many genuine high-pollution cities (values up to 500). These are real events, not data-entry errors, and removing them would delete the cities the study is about. IQR is used for screening, not deletion.

Country-level analysis excludes the `Unknown` group, and rankings require at least 5 cities per country to avoid unreliable averages.

### 2. Exploratory analysis

- Category shares: Good about 42.3%, Moderate about 39.3%, Unhealthy about 9.5%, Unhealthy for Sensitive Groups about 6.8%, Very Unhealthy about 1.2%, Hazardous about 0.8%.
- Mean AQI per category: Good 36.5, Moderate 66.5, Unhealthy for Sensitive Groups 121.1, Unhealthy 166.7, Very Unhealthy 228.1, Hazardous 440.9.
- Most polluted countries (mean AQI, at least 5 cities): Pakistan (about 178), India, Senegal, Saudi Arabia, Gambia, Yemen, Oman, China, Uzbekistan, Nepal.
- Highest share of Hazardous cities (at least 5 cities): India (about 6.3%), Democratic Republic of the Congo (about 4.3%), Pakistan (about 4.2%).
- Dominant pollutant (highest sub-index per city): PM2.5 in roughly 78% of cities, Ozone in roughly 22%, NO2 and CO almost never.
- Pollutant correlation heatmap across the four sub-indices.

### 3. SQL analytics (`sql/aqi_queries.sql`, MySQL)

Table `air_quality` (auto-increment `id`, country, city, and value + category for overall, CO, Ozone, NO2 and PM2.5) with indexes on `country` and `aqi_category`.

| Group | Queries | Techniques |
|---|---|---|
| Aggregation | Top 10 polluted countries; city count and share per category; average pollutant sub-index per category | `GROUP BY`, `HAVING`, scalar subquery |
| Conditional aggregation | Countries with the highest share of hazardous cities | `SUM(CASE WHEN ...)` |
| Window functions | Rank cities within country; `ROW_NUMBER` vs `RANK` vs `DENSE_RANK`; running average; `LAG`/`LEAD` neighbours; `NTILE(4)` quartiles | `OVER (PARTITION BY ... ORDER BY ...)`, frame clause |
| Subqueries and CTEs | Countries above the global average (subquery and CTE versions); cities above their own country's average; `EXISTS` pattern | Correlated subquery, CTE |
| Joins and sets | Best and worst city per country; combined hazardous and clean watchlist | Join of two ranked derived tables, `UNION` |
| Analytics helpers | Dominant pollutant per city; grand total row; top-3 hazardous countries with city detail | `CASE` + `GREATEST`, `WITH ROLLUP`, chained CTEs |
| Reusable objects | View `country_summary`; procedure `GetTopPollutedCountries(min_cities, top_n)` | `CREATE VIEW`, `CREATE PROCEDURE` |

Note: the running-average and `LAG`/`LEAD` queries are ordered by AQI value within each country because the data has no date column. They describe neighbours in a ranking, not a time trend.

### 4. Machine learning (`02_ml_models.ipynb`)

**Clustering.** Features: the four sub-indices, standardized. K-Means with k = 4 (elbow method over k = 2 to 8; the curve declines smoothly, so k = 4 is a judgement made for interpretability). Results are visualized with PCA. Agglomerative clustering (Ward linkage) with a dendrogram on a 600-city random sample cross-checks the structure. K-Means labels are saved to `cluster_labels.csv`.

**Classification.** Target: `AQI Category`. Features: CO, Ozone, NO2 and PM2.5 sub-index values (overall AQI is excluded). Stratified 80/20 split (`random_state=42`, 4,693 test rows).

| Model | Setup | Accuracy | Macro F1 |
|---|---|---|---|
| Logistic Regression | Scaled features, full data | 94.23% | 0.89 |
| Random Forest | 200 trees, full data | 99.87% | 0.978 |
| Random Forest (5-fold CV) | Full data | 99.93% mean, std 0.04 | |
| Random Forest grid search | 3-fold CV | 99.90% (best: depth 10, min split 5, 100 trees) | |
| SVM (RBF) | 3,000-row stratified sample, scaled | 96.00% (grid best C=10, gamma=auto, CV 95.46%) | 0.906 |

Random Forest made 6 errors in 4,693 test rows. All are on the boundary between Very Unhealthy and Hazardous (4 Hazardous predicted as Very Unhealthy, 2 the reverse). Hazardous: precision 0.944, recall 0.895.

**Feature importance (Random Forest).** PM2.5 about 0.84, Ozone about 0.08, CO about 0.07, NO2 about 0.01.

**GDP experiment.** Country-mean AQI merged with World Bank GDP per capita (current US$, 2022) through a manual country-name mapping (169 of 175 countries matched). Simple linear regression (test size 0.4): R2 = -0.35, MAE = 28.5 AQI points, coefficient about 1.4e-06 per US dollar. A negative R2 means the model is worse than predicting the mean, so GDP per capita alone does not explain national mean AQI in this data.

---

## Results in Detail

1. **PM2.5 is the main driver of poor air quality.** It is the highest sub-index in most cities and carries about 84% of Random Forest importance.
2. **Pollution is concentrated regionally.** South and Central Asia and parts of Africa and the Middle East lead the country rankings; India, DR Congo and Pakistan have the highest hazardous shares.
3. **Cities fall into four pollution profiles**, from a large low-pollution group to a small group of extreme cities.
4. **Wealth does not explain national air quality linearly** in this dataset.
5. **Hazardous events are rare (0.8%)**, so per-class precision and recall matter more than accuracy alone.

---

## Dashboard

Interactive Power BI report with five pages (screenshots in `dashboards/screenshots/`).

| Page | Content |
|---|---|
| 1. Global Overview | World map, category distribution, top and bottom 10 countries by mean AQI |
| 2. Country and City Deep-Dive | Pollutant radar profile and city AQI table, filterable by country |
| 3. ML and Clustering Insights | Cluster distribution, feature importance, model accuracy comparison |
| 4. Data Quality and Pipeline | Cleaning funnel (23,463 raw -> 23,462 cleaned) and AQI distribution by range |
| 5. Pollutant Deep-Dive and Correlation | Correlation matrix and dominant-pollutant map by country |

![Global Overview](dashboards/screenshots/01_global_overview.png)
![Deep Dive](dashboards/screenshots/02_country_city_deepdive.png)
![ML Insights](dashboards/screenshots/03_ml_clustering_insights.png)
![Data Quality](dashboards/screenshots/04_data_quality_pipeline.png)
![Pollutant Correlation](dashboards/screenshots/05_pollutant_correlation.png)

---

## How to Run

**Prerequisites:** Python 3.x, Jupyter, MySQL 8.x, Power BI Desktop (optional; screenshots are provided).

1. Clone and install:
   ```bash
   git clone https://github.com/vishnuthakur-05/global-air-quality-analysis.git
   cd global-air-quality-analysis
   pip install -r requirements.txt
   ```
2. Download the raw dataset from the source above and save it as `dataset.csv` next to the notebooks.
3. Run `notebooks/01_data_analysis.ipynb`. It exports `cleaned_air_quality.csv`.
4. Run `notebooks/02_ml_models.ipynb`. It reads `cleaned_air_quality.csv`, exports `cluster_labels.csv` and `feature_importance.csv`, and needs internet once to call the World Bank API for the GDP experiment.
5. Load the SQL: in `sql/aqi_queries.sql`, replace the CSV path in `LOAD DATA LOCAL INFILE` with your local path to the cleaned CSV, enable `local_infile` (`SET GLOBAL local_infile = 1;`), create the table, and run **one** load statement (`LINES TERMINATED BY '\r\n'` for Windows CSVs), then run the queries.
6. Open the Power BI report, or view the screenshots above.

**Common issues:** `LOAD DATA LOCAL INFILE` is blocked unless `local_infile` is enabled on both client and server; a wrong line terminator causes warnings or a single-row load (check with `SHOW WARNINGS` and `SELECT COUNT(*)`, expected 23,462 rows).

---

## Limitations

- **Snapshot data.** There is no time dimension, so the project supports comparisons, not trends or forecasts.
- **The classification target is a formula of the features.** The AQI category is a threshold on the overall AQI, which equals the highest pollutant sub-index. Random Forest recovers this almost exactly, so 99.87% shows the pipeline works but is not evidence of predictive power. The feature-importance ranking, clusters and regional findings are the meaningful outputs. Logistic Regression scores lower because a maximum across features is not a linear rule.
- **Country averages depend on city counts.** A minimum of 5 cities is applied, but small countries remain less reliable.
- **Clustering.** k = 4 rests on a smooth elbow curve; silhouette scores were not computed and Agglomerative clustering used a 600-city sample.
- **SVM** was trained on a 3,000-row sample, so its accuracy is not directly comparable to the full-data models.
- **GDP test** uses country means and a small sample (about 100 training countries).

---

## Future Work

- Add dated readings and forecast AQI (ARIMA, Prophet, LSTM).
- Add weather, population and industry data so prediction is genuine rather than definitional.
- Validate clusters with silhouette scores and compare K-Means with Agglomerative results.
- Weight country averages by city count or population; add health-impact estimates.
- Automate the pipeline and dashboard refresh; publish the `.pbix` file.

---

## Author

**Thakur Vishnu Vardhan Singh**  CMR Institute of Technology, Hyderabad
[LinkedIn](https://linkedin.com/in/vishnuvardhansingh) · [GitHub](https://github.com/vishnuthakur-05)
