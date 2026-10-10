-- ============================================================================
-- Project: Banking Fraud Transactions Analysis
-- Description: SQL queries ranging from basic filtering to advanced CTEs and window functions.
-- ============================================================================


-- ==========================================
-- 1. BASIC QUESTIONS
-- ==========================================

-- Q1. View TOP 10 transaction records
SELECT transaction_id, transaction_amount
FROM Banking_Fraud_Transactions
ORDER BY transaction_amount DESC
LIMIT 10;

-- Q2. Find transactions greater than 10,000
SELECT transaction_id, transaction_amount
FROM Banking_Fraud_Transactions
WHERE transaction_amount > 10000;

-- Q3. Display all transactions where international_transaction_flag equals 1
SELECT international_transaction_flag
FROM Banking_Fraud_Transactions
WHERE international_transaction_flag = 1;

-- Q4. Identify available payment channels
SELECT DISTINCT payment_channel
FROM Banking_Fraud_Transactions;

-- Q5. Find the total transaction amounts
SELECT SUM(transaction_amount) AS total_transaction_amount
FROM Banking_Fraud_Transactions;


-- ==========================================
-- 2. MODERATE QUESTIONS
-- ==========================================

-- Q1. Calculate total transactions, fraudulent transactions, and fraud percentage for the entire dataset
SELECT 
    COUNT(transaction_amount) AS total_number_of_transactions,
    SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) AS fraudulent_transactions,
    ROUND(SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(transaction_amount), 2) AS fraud_percentage
FROM Banking_Fraud_Transactions;

-- Q2. For each payment channel, calculate total transactions, fraudulent transactions, and total transaction amount
SELECT 
    payment_channel,
    COUNT(transaction_id) AS total_transactions, 
    SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) AS fraudulent_transactions,
    SUM(transaction_amount) AS total_transaction_amount
FROM Banking_Fraud_Transactions
GROUP BY payment_channel;

-- Q3. Find the number of transactions and fraud count for each authentication type
SELECT 
    authentication_type, 
    COUNT(transaction_id) AS number_of_transactions, 
    SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) AS fraud_count
FROM Banking_Fraud_Transactions
GROUP BY authentication_type;

-- Q4. Create a risk category using device_risk_score and count transactions in each category
SELECT 
    CASE 
        WHEN device_risk_score >= 70 THEN 'High_Risk' 
        WHEN device_risk_score >= 40 AND device_risk_score < 70 THEN 'Medium_Risk' 
        ELSE 'Low_Risk' 
    END AS risk_category,
    COUNT(transaction_id) AS number_of_transactions
FROM Banking_Fraud_Transactions
GROUP BY risk_category;

-- Q5. Identify payment channels with at least 100 fraudulent transactions, showing fraud rate ordered descending
SELECT 
    payment_channel, 
    COUNT(transaction_id) AS total_transactions, 
    SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) AS fraud_count, 
    ROUND(SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(transaction_id), 2) AS fraud_rate
FROM Banking_Fraud_Transactions
GROUP BY payment_channel
HAVING SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) >= 100
ORDER BY fraud_rate DESC;


-- ==========================================
-- 3. ADVANCED QUESTIONS
-- ==========================================

-- Q1. Return transactions with an amount greater than the dataset average
SELECT transaction_id, transaction_amount, fraud_flag
FROM Banking_Fraud_Transactions
WHERE transaction_amount > (
    SELECT AVG(transaction_amount) 
    FROM Banking_Fraud_Transactions
)
ORDER BY transaction_amount DESC;

-- Q2. Calculate fraudulent transaction counts per payment channel and rank them using a window function
SELECT 
    payment_channel, 
    SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) AS fraudulent_transaction_counts,
    RANK() OVER (ORDER BY SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) DESC) AS fraud_rank
FROM Banking_Fraud_Transactions
GROUP BY payment_channel
ORDER BY fraudulent_transaction_counts DESC;

-- Q3. Find suspicious transactions meeting multiple strict criteria
SELECT 
    transaction_id, 
    transaction_amount, 
    fraud_flag, 
    device_risk_score, 
    suspicious_ip_flag, 
    failed_transactions_last_30d
FROM Banking_Fraud_Transactions
WHERE fraud_flag = TRUE 
  AND device_risk_score >= 70 
  AND suspicious_ip_flag = 1 
  AND failed_transactions_last_30d > 5
ORDER BY transaction_amount;

-- Q4. Calculate transaction count and fraud rate by hour, ranking and returning the top hours
SELECT 
    transaction_time_hour,
    COUNT(transaction_id) AS no_of_transactions,
    SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) AS fraud_transaction,
    ROUND(SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(transaction_id), 2) AS fraud_rate,
    RANK() OVER (ORDER BY ROUND(SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(transaction_id), 2) DESC) AS fraud_rate_rank
FROM Banking_Fraud_Transactions
GROUP BY transaction_time_hour
ORDER BY fraud_rate DESC;

-- Q5. High-risk transaction analysis using a Common Table Expression (CTE)
WITH Categories AS (
    SELECT 
        transaction_id, 
        fraud_flag, 
        transaction_amount, 
        CASE 
            WHEN device_risk_score >= 70 THEN 'High_Risk' 
            WHEN device_risk_score >= 40 AND device_risk_score < 70 THEN 'Medium_Risk' 
            ELSE 'Low_Risk' 
        END AS risk_category 
    FROM Banking_Fraud_Transactions
)
SELECT 
    risk_category, 
    COUNT(transaction_id) AS transaction_count,
    SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(transaction_id), 2) AS fraud_rate,
    SUM(CASE WHEN fraud_flag = TRUE THEN 1 ELSE 0 END) AS total_fraudulent_transaction_count,
    AVG(transaction_amount) AS average_transaction_amount
FROM Categories
GROUP BY risk_category
ORDER BY fraud_rate DESC;