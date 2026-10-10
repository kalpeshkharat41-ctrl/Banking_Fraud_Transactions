# Banking Fraud Transaction Analysis using PostgreSQL

Analysing 10,000 banking transactions with SQL to find where fraud happens, how much it costs, and which signals actually predict it.
**Headline finding:** 1,251 of 10,000 transactions (12.51%) are fraudulent, worth about 15.66M in value. Among all the risk signals in the data, only `anomaly_score` separates fraud from genuine transactions. 85.6% of transactions with an anomaly score above 0.7 are fraud, versus 0.02% below 0.3.


## Business Problem

A bank's fraud team needs to know:

- How big is the fraud problem (volume and value)?
- Do some payment channels or authentication methods have more fraud than others?
- Is `device_risk_score` a reliable way to flag risky transactions?
- At which hours of the day is fraud most common?
- Which combination of indicators describes the most suspicious transactions?

## Dataset

| Item | Detail |
|---|---|
| File | `Banking_Fraud_Transactions.csv` |
| Rows | 10,000 (one row per transaction) |
| Columns | 20 |
| Missing values | None |
| Duplicates | None (`transaction_id` is unique) |
| Target column | `fraud_flag` (TRUE / FALSE) |

**Column groups**

| Group | Columns |
|---|---|
| Transaction | `transaction_id`, `transaction_amount`, `transaction_time_hour`, `payment_channel`, `authentication_type` |
| Customer / account | `account_age_days`, `avg_monthly_balance`, `transfer_frequency`, `daily_transaction_count` |
| Behaviour / risk | `login_attempts`, `failed_transactions_last_30d`, `session_duration_minutes`, `transaction_velocity_score`, `device_risk_score`, `anomaly_score`, `geo_distance_km` |
| Flags | `card_present_flag`, `international_transaction_flag`, `suspicious_ip_flag`, `fraud_flag` |

> The dataset has an hour of the day but no transaction date, so trend-over-time analysis was not possible.

## Tools

PostgreSQL, pgAdmin (or DBeaver), SQL (aggregations, CASE, subqueries, CTEs, window functions)

## Data Preparation

1. Created the table with proper data types (`DECIMAL` for money and scores, `SMALLINT` for 0/1 flags, `BOOLEAN` for `fraud_flag`).
2. Loaded the CSV with `COPY`.
3. Checked row count (10,000), NULLs (0) and duplicate IDs (0).

```sql
\copy Banking_Fraud_Transactions FROM 'Banking_Fraud_Transactions.csv' WITH (FORMAT csv, HEADER true);
```

---

## SQL Skills Demonstrated

`SELECT / WHERE / ORDER BY / LIMIT` · `DISTINCT` · `GROUP BY / HAVING` · `CASE WHEN` · `COUNT(*) FILTER` · scalar subquery · CTE · `RANK()` window function

---

## Analysis and Results

### Basic

| # | Question | Result |
|---|---|---|
| 1 | Top 10 transactions by amount | Largest transactions are close to the 25,000 maximum |
| 2 | Transactions above 10,000 | 5,938 |
| 3 | International transactions | 4,984 |
| 4 | Payment channels | ATM, Mobile App, POS Terminal, Web Banking |
| 5 | Total transaction value | 124,127,540.04 |

### Moderate

**1. Overall fraud rate**

```sql
SELECT COUNT(*) AS total_transactions,
       SUM(CASE WHEN fraud_flag = true THEN 1 ELSE 0 END) AS fraudulent_transactions,
       ROUND(SUM(CASE WHEN fraud_flag = true THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_percentage
FROM Banking_Fraud_Transactions;
```

| Total | Fraud | Fraud % |
|---|---|---|
| 10,000 | 1,251 | 12.51% |

**2. Fraud by payment channel**

```sql
SELECT payment_channel,
       COUNT(*) AS total_transactions,
       SUM(CASE WHEN fraud_flag THEN 1 ELSE 0 END) AS fraudulent_transactions,
       SUM(transaction_amount) AS total_amount,
       SUM(CASE WHEN fraud_flag = true THEN 1 ELSE 0 END) AS fraud_amount
FROM Banking_Fraud_Transactions
GROUP BY payment_channel;
```

| Channel | Transactions | Fraud | Fraud rate | Fraud amount |
|---|---|---|---|---|
| Mobile App | 4,804 | 616 | 12.82% | 7,711,462 |
| Web Banking | 3,247 | 400 | 12.32% | 5,038,342 |
| POS Terminal | 1,172 | 134 | 11.43% | 1,714,308 |
| ATM | 777 | 101 | 13.00% | 1,193,292 |

**3. Fraud by authentication type**

```sql
SELECT authentication_type,
       COUNT(*) AS number_of_transactions,
       COUNT(*) FILTER (WHERE fraud_flag) AS fraud_count,
       ROUND(COUNT(*) FILTER (WHERE fraud_flag) * 100.0 / COUNT(*), 2) AS fraud_rate
FROM Banking_Fraud_Transactions
GROUP BY authentication_type
ORDER BY fraud_rate DESC;
```

| Authentication | Transactions | Fraud | Fraud rate |
|---|---|---|---|
| OTP | 4,214 | 551 | 13.08% |
| Password Only | 1,817 | 232 | 12.77% |
| Biometric | 1,585 | 191 | 12.05% |
| Two-Factor Authentication | 2,384 | 277 | 11.62% |

**4. Device risk categories** (High: 70 and above, Medium: 40 to under 70, Low: under 40)

```sql
SELECT CASE WHEN device_risk_score >= 70 THEN 'High Risk'
            WHEN device_risk_score >= 40 THEN 'Medium Risk'
            ELSE 'Low Risk' END AS risk_category,
       COUNT(*) AS number_of_transactions
FROM Banking_Fraud_Transactions
GROUP BY risk_category;
```

| Category | Transactions |
|---|---|
| Low Risk | 4,012 |
| High Risk | 3,038 |
| Medium Risk | 2,950 |

**5. Channels with at least 100 fraud cases**

```sql
SELECT payment_channel,
       COUNT(*) AS total_transactions,
       SUM(CASE WHEN fraud_flag = true THEN 1 ELSE 0 END) AS fraud_count,
       ROUND(SUM(CASE WHEN fraud_flag = true THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_rate
FROM Banking_Fraud_Transactions
GROUP BY payment_channel
HAVING SUM(CASE WHEN fraud_flag = true THEN 1 ELSE 0 END) >= 100
ORDER BY fraud_rate DESC;
```

All four channels qualify. ATM is highest at 13.00% and POS Terminal lowest at 11.43%.

### Advanced

**1. Transactions above the average amount**

```sql
SELECT transaction_id, transaction_amount, fraud_flag
FROM Banking_Fraud_Transactions
WHERE transaction_amount > (SELECT AVG(transaction_amount) FROM Banking_Fraud_Transactions)
ORDER BY transaction_amount DESC;
```

Average amount is 12,412.75. 4,973 transactions are above it.

**2. Channels ranked by fraud count (window function)**

```sql
SELECT payment_channel,
       SUM(CASE WHEN fraud_flag THEN 1 ELSE 0 END) AS fraud_count,
       RANK() OVER (ORDER BY SUM(CASE WHEN fraud_flag =true THEN 1 ELSE 0 END) DESC) AS fraud_rank
FROM Banking_Fraud_Transactions
GROUP BY payment_channel;
```

| Rank | Channel | Fraud count |
|---|---|---|
| 1 | Mobile App | 616 |
| 2 | Web Banking | 400 |
| 3 | POS Terminal | 134 |
| 4 | ATM | 101 |

**3. Suspicious transactions (multiple conditions)**

Fraud = TRUE, device risk score at least 70, suspicious IP, more than 5 failed transactions in 30 days.

```sql
SELECT transaction_id, transaction_amount, device_risk_score,
       suspicious_ip_flag, failed_transactions_last_30d
FROM Banking_Fraud_Transactions
WHERE fraud_flag
  AND device_risk_score >= 70
  AND suspicious_ip_flag = 1
  AND failed_transactions_last_30d > 5
ORDER BY transaction_amount DESC;

-- Total value of these transactions
SELECT COUNT(*) AS suspicious_count, SUM(transaction_amount) AS total_value
FROM Banking_Fraud_Transactions
WHERE fraud_flag AND device_risk_score >= 70
  AND suspicious_ip_flag = 1 AND failed_transactions_last_30d > 5;
```

160 transactions with a combined value of 2,122,400.01.

**4. Top 5 hours by fraud rate**

```sql
SELECT transaction_time_hour,
       COUNT(*) AS no_of_transactions,
       SUM(CASE WHEN fraud_flag =true THEN 1 ELSE 0 END) AS fraud_transactions,
       ROUND(SUM(CASE WHEN fraud_flag THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_rate,
       RANK() OVER (ORDER BY SUM(CASE WHEN fraud_flag THEN 1 ELSE 0 END) * 1.0 / COUNT(*) DESC) AS fraud_rank
FROM Banking_Fraud_Transactions
GROUP BY transaction_time_hour
ORDER BY fraud_rate DESC
LIMIT 5;
```

| Rank | Hour | Transactions | Fraud | Fraud rate |
|---|---|---|---|---|
| 1 | 04:00 | 372 | 56 | 15.05% |
| 2 | 18:00 | 418 | 62 | 14.83% |
| 3 | 09:00 | 408 | 59 | 14.46% |
| 4 | 22:00 | 441 | 62 | 14.06% |
| 5 | 13:00 | 376 | 52 | 13.83% |

**5. Risk analysis using a CTE**

```sql
WITH categories AS (
    SELECT transaction_id, fraud_flag, transaction_amount,
           CASE WHEN device_risk_score >= 70 THEN 'High Risk'
                WHEN device_risk_score >= 40 THEN 'Medium Risk'
                ELSE 'Low Risk' END AS risk_category
    FROM Banking_Fraud_Transactions
)
SELECT risk_category,
       COUNT(*) AS transaction_count,
       COUNT(*) FILTER (WHERE fraud_flag) AS fraud_count,
       ROUND(COUNT(*) FILTER (WHERE fraud_flag) * 100.0 / COUNT(*), 2) AS fraud_rate,
       SUM(transaction_amount) FILTER (WHERE fraud_flag) AS fraudulent_amount,
       ROUND(AVG(transaction_amount), 2) AS avg_transaction_amount
FROM categories
GROUP BY risk_category
ORDER BY fraud_rate DESC;
```

| Risk category | Transactions | Fraud | Fraud rate | Fraud amount | Avg amount |
|---|---|---|---|---|---|
| High Risk | 3,038 | 391 | 12.87% | 4,896,506 | 12,500.56 |
| Low Risk | 4,012 | 515 | 12.84% | 6,451,006 | 12,392.73 |
| Medium Risk | 2,950 | 345 | 11.69% | 4,309,892 | 12,349.55 |

### Extra: which signal actually predicts fraud?

Device risk looked like an obvious fraud indicator, but the results above show almost no difference between risk bands. So I tested `anomaly_score`:

```sql
SELECT CASE WHEN anomaly_score <= 0.3 THEN '0.00 - 0.30'
            WHEN anomaly_score <= 0.5 THEN '0.31 - 0.50'
            WHEN anomaly_score <= 0.7 THEN '0.51 - 0.70'
            ELSE '0.71 - 1.00' END AS anomaly_band,
       COUNT(*) AS transactions,
       COUNT(*) FILTER (WHERE fraud_flag) AS fraud_count,
       ROUND(COUNT(*) FILTER (WHERE fraud_flag) * 100.0 / COUNT(*), 2) AS fraud_rate
FROM Banking_Fraud_Transactions
GROUP BY anomaly_band
ORDER BY anomaly_band;
```

| Anomaly score | Transactions | Fraud | Fraud rate |
|---|---|---|---|
| 0.00 - 0.30 | 4,816 | 1 | 0.02% |
| 0.31 - 0.50 | 2,954 | 45 | 1.52% |
| 0.51 - 0.70 | 1,208 | 330 | 27.32% |
| 0.71 - 1.00 | 1,022 | 875 | 85.62% |

---

## Key Insights

1. **Fraud is 12.51% of transactions** (1,251 of 10,000) and about 15.66M in value, roughly 12.6% of total transaction value.
2. **Anomaly score is the only strong fraud signal.** Fraud rate climbs from 0.02% to 85.6% as the score rises. Average anomaly score is 0.77 for fraud versus 0.29 for genuine transactions.
3. **Device risk score does not separate fraud.** High Risk (12.87%) and Low Risk (12.84%) devices have nearly the same fraud rate, so a rule based on device score alone would flag many genuine customers.
4. **Channel and authentication differences are small.** Fraud rates sit between 11.4% and 13.1% across all channels and authentication types. Mobile App has the most fraud cases (616) simply because it has the most traffic (48% of transactions).
5. **Early morning and evening hours run higher.** 04:00 has the highest fraud rate (15.05%) versus a low of about 9% at the quietest hour.
6. **160 transactions** meet all four high-risk conditions, with a combined value of 2.12M, which makes a good priority list for manual review.

## Recommendations

- Use `anomaly_score` thresholds as the first screening layer, for example an automatic review above 0.7 and enhanced monitoring between 0.5 and 0.7.
- Recalibrate or combine `device_risk_score` with other signals before using it for blocking decisions.
- Review OTP-based flows, which show the highest fraud rate (13.08%) among authentication types.
- Add extra monitoring around 04:00, 09:00, 13:00, 18:00 and 22:00.

## Limitations

- Most features (device risk, velocity, geo distance and others) are close to uniformly distributed and show almost no link to fraud, which suggests the dataset is simulated rather than real bank data. Findings show SQL technique and method, not real-world fraud patterns.
- No date column, so time trends cannot be analysed.
- Currency is not specified in the data.

---

## Project Structure

```
├── data/
│   └── Banking_Fraud_Transactions.csv
├── sql/
│   ├── 01_schema_and_loading.sql
│   └── 02_analysis_queries.sql
└── README.md
```
