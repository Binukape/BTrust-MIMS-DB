GRANT ALL PRIVILEGES ON mims_db.* TO 'mims_owner'@'%';

GRANT SELECT ON mims_db.v_report_agent_wise           TO 'mims_reports'@'%';
GRANT SELECT ON mims_db.v_report_account_balances     TO 'mims_reports'@'%';
GRANT SELECT ON mims_db.v_report_account_activity     TO 'mims_reports'@'%';
GRANT SELECT ON mims_db.v_report_active_fds           TO 'mims_reports'@'%';
GRANT SELECT ON mims_db.v_report_interest_distribution TO 'mims_reports'@'%';
GRANT SELECT ON mims_db.v_report_customer_activity    TO 'mims_reports'@'%';
GRANT SELECT ON mims_db.v_account_agent               TO 'mims_reports'@'%';
GRANT SELECT ON mims_db.v_account_holder_names        TO 'mims_reports'@'%';

GRANT SELECT ON mims_db.* TO 'mims_app'@'%';

GRANT EXECUTE ON PROCEDURE mims_db.sp_deposit        TO 'mims_app'@'%';
GRANT EXECUTE ON PROCEDURE mims_db.sp_withdraw       TO 'mims_app'@'%';
GRANT EXECUTE ON PROCEDURE mims_db.sp_open_fd        TO 'mims_app'@'%';
GRANT EXECUTE ON PROCEDURE mims_db.sp_close_fd_early TO 'mims_app'@'%';

GRANT INSERT, UPDATE, DELETE ON mims_db.branch TO 'mims_app'@'%';
GRANT UPDATE ON mims_db.savings_plan           TO 'mims_app'@'%';

GRANT INSERT ON mims_db.agent TO 'mims_app'@'%';
GRANT UPDATE (agent_name, agent_nic, username, password_hash) ON mims_db.agent TO 'mims_app'@'%';

GRANT INSERT ON mims_db.customer       TO 'mims_app'@'%';
GRANT INSERT ON mims_db.savings_account TO 'mims_app'@'%';
GRANT INSERT ON mims_db.account_holder TO 'mims_app'@'%';

GRANT UPDATE (status) ON mims_db.savings_account TO 'mims_app'@'%';
