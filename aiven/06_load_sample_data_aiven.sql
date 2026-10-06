LOAD DATA LOCAL INFILE './init/data/admins.csv'
INTO TABLE admin
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(admin_id, full_name, username, password_hash);

LOAD DATA LOCAL INFILE './init/data/branches.csv'
INTO TABLE branch
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(branch_id, branch_name, branch_address, branch_phone);

LOAD DATA LOCAL INFILE './init/data/agents.csv'
INTO TABLE agent
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(agent_id, branch_id, agent_name, agent_nic, username, password_hash);

LOAD DATA LOCAL INFILE './init/data/customers.csv'
INTO TABLE customer
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, agent_id, full_name, nic_number, address, phone, date_of_birth, username, password_hash);

LOAD DATA LOCAL INFILE './init/data/savings_accounts.csv'
INTO TABLE savings_account
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(account_id, plan_id, branch_id, account_number, balance, is_joint, status, opened_date);

LOAD DATA LOCAL INFILE './init/data/account_holders.csv'
INTO TABLE account_holder
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(account_id, customer_id, holder_role);

LOAD DATA LOCAL INFILE './init/data/fixed_deposits.csv'
INTO TABLE fixed_deposit
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(fd_id, account_id, fd_plan_id, principal_amount, interest_rate_snapshot, start_date, maturity_date, status);

ALTER TABLE admin           AUTO_INCREMENT = 100;
ALTER TABLE branch          AUTO_INCREMENT = 100;
ALTER TABLE agent           AUTO_INCREMENT = 100;
ALTER TABLE customer        AUTO_INCREMENT = 100;
ALTER TABLE savings_account AUTO_INCREMENT = 100;
ALTER TABLE fixed_deposit   AUTO_INCREMENT = 100;
