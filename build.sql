CREATE DATABASE IF NOT EXISTS mims_db;
USE mims_db;

SOURCE init/01_schema.sql;
SOURCE init/02_triggers.sql;
SOURCE init/03_procedures.sql;
SOURCE init/04_interest_and_events.sql;
SOURCE init/05_reference_data.sql;
SOURCE aiven/06_load_sample_data_aiven.sql;
SOURCE init/07_generate_transactions.sql;
SOURCE init/08_admin_audit.sql;
SOURCE init/09_reports.sql;

CALL sp_seed_sample_transactions(100);

SOURCE init/11_grants.sql;

SELECT 'Build complete.' AS status;
