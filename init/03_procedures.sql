DELIMITER $$

CREATE FUNCTION fn_now_sl()
RETURNS DATETIME
BEGIN
    RETURN CONVERT_TZ(UTC_TIMESTAMP(), '+00:00', '+05:30');
END$$

CREATE FUNCTION fn_today_sl()
RETURNS DATE
BEGIN
    RETURN DATE(CONVERT_TZ(UTC_TIMESTAMP(), '+00:00', '+05:30'));
END$$

CREATE FUNCTION fn_next_reference_number()
RETURNS VARCHAR(30)
BEGIN
    DECLARE v_today DATE;
    DECLARE v_seq INT;
    DECLARE v_ref VARCHAR(30);

    SET v_today = fn_today_sl();

    INSERT INTO transaction_daily_sequence (seq_date, last_seq)
    VALUES (v_today, 1)
    ON DUPLICATE KEY UPDATE last_seq = last_seq + 1;

    SELECT last_seq INTO v_seq
    FROM transaction_daily_sequence
    WHERE seq_date = v_today;

    SET v_ref = CONCAT('TXN-', DATE_FORMAT(v_today, '%Y%m%d'), '-', LPAD(v_seq, 6, '0'));

    RETURN v_ref;
END$$

CREATE FUNCTION fn_is_business_hours()
RETURNS BOOLEAN
BEGIN
    DECLARE v_now TIME;
    SET v_now = TIME(fn_now_sl());
    RETURN v_now >= '09:00:00' AND v_now <= '17:00:00';
END$$

CREATE PROCEDURE sp_deposit(
    IN p_account_id INT,
    IN p_amount DECIMAL(15,2),
    IN p_agent_id INT
)
BEGIN
    DECLARE v_status VARCHAR(10);
    DECLARE v_reference VARCHAR(30);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Deposit amount must be positive.';
    END IF;

    IF NOT fn_is_business_hours() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Deposits are only allowed between 09:00 and 17:00.';
    END IF;

    START TRANSACTION;

        SELECT status INTO v_status
        FROM savings_account
        WHERE account_id = p_account_id
        FOR UPDATE;

        IF v_status IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Savings account not found.';
        ELSEIF v_status <> 'ACTIVE' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Deposits are only allowed into ACTIVE accounts.';
        END IF;

        UPDATE savings_account
        SET balance = balance + p_amount
        WHERE account_id = p_account_id;

        SET v_reference = fn_next_reference_number();

        INSERT INTO transaction (account_id, agent_id, reference_number, transaction_type, amount, transaction_timestamp)
        VALUES (p_account_id, p_agent_id, v_reference, 'DEPOSIT', p_amount, fn_now_sl());

    COMMIT;

    SELECT v_reference AS reference_number;
END$$

CREATE PROCEDURE sp_withdraw(
    IN p_account_id INT,
    IN p_amount DECIMAL(15,2),
    IN p_agent_id INT
)
BEGIN
    DECLARE v_status VARCHAR(10);
    DECLARE v_withdrawn_today DECIMAL(15,2);
    DECLARE v_reference VARCHAR(30);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Withdrawal amount must be positive.';
    END IF;

    IF NOT fn_is_business_hours() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Withdrawals are only allowed between 09:00 and 17:00.';
    END IF;

    START TRANSACTION;

        SELECT status INTO v_status
        FROM savings_account
        WHERE account_id = p_account_id
        FOR UPDATE;

        IF v_status IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Savings account not found.';
        ELSEIF v_status <> 'ACTIVE' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Withdrawals are only allowed from ACTIVE accounts.';
        END IF;

        SELECT COALESCE(SUM(amount), 0) INTO v_withdrawn_today
        FROM transaction
        WHERE account_id = p_account_id
          AND transaction_type = 'WITHDRAWAL'
          AND DATE(transaction_timestamp) = fn_today_sl();

        IF (v_withdrawn_today + p_amount) > 100000.00 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Withdrawal rejected: would exceed the LKR 100,000 daily limit for this account.';
        END IF;

        UPDATE savings_account
        SET balance = balance - p_amount
        WHERE account_id = p_account_id;

        SET v_reference = fn_next_reference_number();

        INSERT INTO transaction (account_id, agent_id, reference_number, transaction_type, amount, transaction_timestamp)
        VALUES (p_account_id, p_agent_id, v_reference, 'WITHDRAWAL', p_amount, fn_now_sl());

    COMMIT;

    SELECT v_reference AS reference_number;
END$$

CREATE PROCEDURE sp_open_fd(
    IN p_account_id INT,
    IN p_fd_plan_id INT,
    IN p_principal_amount DECIMAL(15,2)
)
BEGIN
    DECLARE v_status VARCHAR(10);
    DECLARE v_rate DECIMAL(5,2);
    DECLARE v_tenure_months INT;
    DECLARE v_start DATE;
    DECLARE v_maturity DATE;
    DECLARE v_fd_id INT;
    DECLARE v_reference VARCHAR(30);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_principal_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fixed Deposit principal amount must be positive.';
    END IF;

    SELECT interest_rate, tenure_months INTO v_rate, v_tenure_months
    FROM fd_plan
    WHERE fd_plan_id = p_fd_plan_id;

    IF v_rate IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid FD plan.';
    END IF;

    START TRANSACTION;

        SELECT status INTO v_status
        FROM savings_account
        WHERE account_id = p_account_id
        FOR UPDATE;

        IF v_status IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Savings account not found.';
        ELSEIF v_status <> 'ACTIVE' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A Fixed Deposit requires an ACTIVE Savings Account.';
        END IF;

        SET v_start = fn_today_sl();
        SET v_maturity = DATE_ADD(v_start, INTERVAL v_tenure_months MONTH);

        INSERT INTO fixed_deposit
            (account_id, fd_plan_id, principal_amount, interest_rate_snapshot,
             start_date, maturity_date, status)
        VALUES
            (p_account_id, p_fd_plan_id, p_principal_amount, v_rate,
             v_start, v_maturity, 'ACTIVE');

        SET v_fd_id = LAST_INSERT_ID();

        UPDATE savings_account
        SET balance = balance - p_principal_amount
        WHERE account_id = p_account_id;

        SET v_reference = fn_next_reference_number();

        INSERT INTO transaction (account_id, agent_id, fd_id, reference_number, transaction_type, amount, transaction_timestamp)
        VALUES (p_account_id, NULL, v_fd_id, v_reference, 'FD_OPENING_DEBIT', p_principal_amount, fn_now_sl());

    COMMIT;

    SELECT v_fd_id AS fd_id, v_maturity AS maturity_date, v_reference AS reference_number;
END$$

CREATE PROCEDURE sp_close_fd_early(
    IN p_fd_id INT
)
BEGIN
    DECLARE v_account_id INT;
    DECLARE v_status VARCHAR(10);
    DECLARE v_principal DECIMAL(15,2);
    DECLARE v_rate DECIMAL(5,2);
    DECLARE v_penalty_days INT;
    DECLARE v_maturity DATE;
    DECLARE v_penalty DECIMAL(15,2);
    DECLARE v_payout DECIMAL(15,2);
    DECLARE v_reference VARCHAR(30);
    DECLARE v_adjust_reference VARCHAR(30);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

        SELECT fd.account_id, fd.status, fd.principal_amount, fd.interest_rate_snapshot, fp.early_closure_penalty_days, fd.maturity_date
        INTO v_account_id, v_status, v_principal, v_rate, v_penalty_days, v_maturity
        FROM fixed_deposit fd
        JOIN fd_plan fp ON fd.fd_plan_id = fp.fd_plan_id
        WHERE fd.fd_id = p_fd_id
        FOR UPDATE OF fd;

        IF v_account_id IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fixed Deposit not found.';
        ELSEIF v_status <> 'ACTIVE' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only an ACTIVE Fixed Deposit can be closed early.';
        ELSEIF v_maturity <= fn_today_sl() THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fixed Deposit has matured; the nightly job will pay it out.';
        END IF;

        SET v_penalty = LEAST(ROUND(v_principal * (v_rate / 100) * (v_penalty_days / 365), 2), v_principal);
        SET v_payout = v_principal - v_penalty;

        UPDATE fixed_deposit
        SET status = 'CLOSED'
        WHERE fd_id = p_fd_id;

        UPDATE savings_account
        SET balance = balance + v_payout
        WHERE account_id = v_account_id;

        SET v_reference = fn_next_reference_number();
        INSERT INTO transaction (account_id, agent_id, fd_id, reference_number, transaction_type, amount, transaction_timestamp)
        VALUES (v_account_id, NULL, p_fd_id, v_reference, 'FD_EARLY_CLOSURE_PAYOUT', v_principal, fn_now_sl());

        IF v_penalty > 0 THEN
            SET v_adjust_reference = fn_next_reference_number();
            INSERT INTO transaction (account_id, agent_id, fd_id, reference_number, transaction_type, amount, transaction_timestamp)
            VALUES (v_account_id, NULL, p_fd_id, v_adjust_reference, 'FD_EARLY_CLOSURE_ADJUSTMENT', v_penalty, fn_now_sl());
        END IF;

    COMMIT;

    SELECT v_reference AS payout_reference_number,
           v_adjust_reference AS adjustment_reference_number,
           v_penalty AS penalty_charged,
           v_payout AS net_amount_credited;
END$$

DELIMITER ;
