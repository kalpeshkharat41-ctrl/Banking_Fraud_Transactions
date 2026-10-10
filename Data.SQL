-- Sample Seed Data Insertion Script
INSERT INTO Banking_Fraud_Transactions(CREATE TABLE Banking_Fraud_Transactions(transaction_id , transaction_amount , login_attempts , device_risk_score ,transfer_frequency  ,anomaly_score , account_age_days , transaction_time_hour , failed_transactions_last_30d , avg_monthly_balance , daily_transaction_count , geo_distance_km , session_duration_minutes , transaction_velocity_score , payment_channel , authentication_type , card_present_flag , international_transaction_flag , suspicious_ip_flag , fraud_flag) 
FROM 'C:\Users\Lenovo\Desktop\SQL projects\Banking_fraud_transaction'
DELIMITER ','
CSV HEADER;

