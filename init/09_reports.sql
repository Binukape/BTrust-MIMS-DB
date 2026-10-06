CREATE VIEW v_account_agent AS
SELECT DISTINCT ah.account_id, c.agent_id
FROM account_holder ah
JOIN customer c ON ah.customer_id = c.customer_id;

CREATE VIEW v_account_holder_names AS
SELECT ah.account_id,
       GROUP_CONCAT(c.full_name ORDER BY c.full_name SEPARATOR ', ') AS holder_names
FROM account_holder ah
JOIN customer c ON ah.customer_id = c.customer_id
GROUP BY ah.account_id;

CREATE VIEW v_report_agent_wise AS
SELECT a.agent_id, a.agent_name, b.branch_name,
       DATE(t.transaction_timestamp) AS transaction_date,
       'PROCESSED' AS channel,
       COUNT(*) AS txn_count,
       SUM(t.amount) AS total_amount
FROM transaction t
JOIN agent a  ON t.agent_id = a.agent_id
JOIN branch b ON a.branch_id = b.branch_id
WHERE t.transaction_type IN ('DEPOSIT', 'WITHDRAWAL')
GROUP BY a.agent_id, a.agent_name, b.branch_name, DATE(t.transaction_timestamp)
UNION ALL
SELECT a.agent_id, a.agent_name, b.branch_name,
       DATE(s.transaction_timestamp) AS transaction_date,
       'SELF_SERVICE' AS channel,
       COUNT(*) AS txn_count,
       SUM(s.amount) AS total_amount
FROM (
    SELECT t.transaction_id, t.amount, t.transaction_timestamp, aa.agent_id
    FROM transaction t
    JOIN v_account_agent aa ON t.account_id = aa.account_id
    WHERE t.agent_id IS NULL
      AND t.transaction_type IN ('DEPOSIT', 'WITHDRAWAL')
) s
JOIN agent a  ON s.agent_id = a.agent_id
JOIN branch b ON a.branch_id = b.branch_id
GROUP BY a.agent_id, a.agent_name, b.branch_name, DATE(s.transaction_timestamp);

CREATE VIEW v_report_account_balances AS
SELECT sa.account_id, sa.account_number, sp.plan_name, b.branch_name,
       sa.status, sa.is_joint, sa.balance AS current_balance,
       hn.holder_names
FROM savings_account sa
JOIN savings_plan sp ON sa.plan_id = sp.plan_id
JOIN branch b        ON sa.branch_id = b.branch_id
LEFT JOIN v_account_holder_names hn ON sa.account_id = hn.account_id;

CREATE VIEW v_report_account_activity AS
SELECT t.account_id,
       DATE(t.transaction_timestamp) AS transaction_date,
       t.transaction_type,
       COUNT(*) AS txn_count,
       SUM(t.amount) AS total_amount
FROM transaction t
GROUP BY t.account_id, DATE(t.transaction_timestamp), t.transaction_type;

CREATE VIEW v_report_active_fds AS
SELECT f.fd_id, f.account_id, sa.account_number, hn.holder_names,
       fp.tenure_months, f.principal_amount, f.interest_rate_snapshot,
       f.start_date, f.maturity_date, f.last_interest_credit_date,
       LEAST(f.maturity_date,
             DATE_ADD(COALESCE(f.last_interest_credit_date, f.start_date), INTERVAL 30 DAY)) AS next_payout_date
FROM fixed_deposit f
JOIN fd_plan fp        ON f.fd_plan_id = fp.fd_plan_id
JOIN savings_account sa ON f.account_id = sa.account_id
LEFT JOIN v_account_holder_names hn ON f.account_id = hn.account_id
WHERE f.status = 'ACTIVE';

CREATE VIEW v_report_interest_distribution AS
SELECT DATE(t.transaction_timestamp) AS transaction_date,
       sp.plan_name,
       t.transaction_type AS interest_type,
       COUNT(*) AS txn_count,
       SUM(t.amount) AS total_amount
FROM transaction t
JOIN savings_account sa ON t.account_id = sa.account_id
JOIN savings_plan sp    ON sa.plan_id = sp.plan_id
WHERE t.transaction_type IN ('SAVINGS_INTEREST_CREDIT', 'FD_INTEREST_CREDIT')
GROUP BY DATE(t.transaction_timestamp), sp.plan_name, t.transaction_type
UNION ALL
SELECT DATE(t.transaction_timestamp) AS transaction_date,
       sp.plan_name,
       'FD_MATURITY_INTEREST' AS interest_type,
       COUNT(*) AS txn_count,
       SUM(t.amount - f.principal_amount) AS total_amount
FROM transaction t
JOIN fixed_deposit f    ON t.fd_id = f.fd_id
JOIN savings_account sa ON t.account_id = sa.account_id
JOIN savings_plan sp    ON sa.plan_id = sp.plan_id
WHERE t.transaction_type = 'FD_MATURITY_PAYOUT'
GROUP BY DATE(t.transaction_timestamp), sp.plan_name;

CREATE VIEW v_report_customer_activity AS
SELECT c.customer_id, c.full_name, c.agent_id,
       ah.account_id, sa.account_number,
       DATE(t.transaction_timestamp) AS transaction_date,
       SUM(CASE WHEN t.transaction_type = 'DEPOSIT' THEN 1 ELSE 0 END) AS deposit_count,
       SUM(CASE WHEN t.transaction_type = 'DEPOSIT' THEN t.amount ELSE 0 END) AS total_deposits,
       SUM(CASE WHEN t.transaction_type = 'WITHDRAWAL' THEN 1 ELSE 0 END) AS withdrawal_count,
       SUM(CASE WHEN t.transaction_type = 'WITHDRAWAL' THEN t.amount ELSE 0 END) AS total_withdrawals,
       SUM(CASE WHEN t.transaction_type = 'DEPOSIT' THEN t.amount
                WHEN t.transaction_type = 'WITHDRAWAL' THEN -t.amount
                ELSE 0 END) AS net_change
FROM customer c
JOIN account_holder ah  ON c.customer_id = ah.customer_id
JOIN savings_account sa ON ah.account_id = sa.account_id
JOIN transaction t      ON t.account_id = ah.account_id
WHERE t.transaction_type IN ('DEPOSIT', 'WITHDRAWAL')
GROUP BY c.customer_id, c.full_name, c.agent_id, ah.account_id, sa.account_number,
         DATE(t.transaction_timestamp);
