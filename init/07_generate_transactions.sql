DELIMITER $$

CREATE PROCEDURE sp_seed_sample_transactions(IN p_count INT)
BEGIN
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_active_count INT DEFAULT 0;
    DECLARE v_account_id INT;
    DECLARE v_balance DECIMAL(15,2);
    DECLARE v_min_balance DECIMAL(15,2);
    DECLARE v_available DECIMAL(15,2);
    DECLARE v_amount DECIMAL(15,2);
    DECLARE v_agent_id INT;
    DECLARE v_fd_id INT;
    DECLARE v_fd_start DATE;
    DECLARE v_fd_span INT;
    DECLARE v_type VARCHAR(30);
    DECLARE v_timestamp DATETIME;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT COUNT(*) INTO v_active_count
    FROM savings_account
    WHERE status = 'ACTIVE';

    IF v_active_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No ACTIVE savings accounts to seed transactions for.';
    END IF;

    START TRANSACTION;

    WHILE v_i < p_count DO
        SET v_agent_id = NULL;
        SET v_amount = NULL;
        SET v_fd_id = NULL;

        SELECT sa.account_id, sa.balance, sp.minimum_balance
        INTO v_account_id, v_balance, v_min_balance
        FROM savings_account sa
        JOIN savings_plan sp ON sa.plan_id = sp.plan_id
        WHERE sa.status = 'ACTIVE'
        ORDER BY RAND() LIMIT 1;

        IF RAND() < 0.7 THEN
            SELECT a.agent_id INTO v_agent_id
            FROM account_holder ah
            JOIN customer c ON ah.customer_id = c.customer_id
            JOIN agent a    ON c.agent_id = a.agent_id
            WHERE ah.account_id = v_account_id
            ORDER BY RAND() LIMIT 1;
        END IF;

        SET v_type = ELT(1 + FLOOR(RAND() * 20),
            'DEPOSIT','DEPOSIT','DEPOSIT','DEPOSIT','DEPOSIT','DEPOSIT','DEPOSIT','DEPOSIT','DEPOSIT',
            'WITHDRAWAL','WITHDRAWAL','WITHDRAWAL','WITHDRAWAL','WITHDRAWAL',
            'SAVINGS_INTEREST_CREDIT','SAVINGS_INTEREST_CREDIT','SAVINGS_INTEREST_CREDIT',
            'FD_INTEREST_CREDIT','FD_INTEREST_CREDIT','FD_INTEREST_CREDIT');

        SET v_timestamp = TIMESTAMP(DATE_SUB(fn_today_sl(), INTERVAL 1 + FLOOR(RAND() * 180) DAY))
                          + INTERVAL (9*3600 + FLOOR(RAND() * 8*3600)) SECOND;

        IF v_type = 'FD_INTEREST_CREDIT' THEN
            SELECT fd_id, account_id, start_date,
                   ROUND(principal_amount * (interest_rate_snapshot / 100) * (30 / 365), 2),
                   DATEDIFF(LEAST(maturity_date, fn_today_sl()), start_date)
            INTO   v_fd_id, v_account_id, v_fd_start, v_amount, v_fd_span
            FROM fixed_deposit
            WHERE DATEDIFF(LEAST(maturity_date, fn_today_sl()), start_date) >= 30
            ORDER BY RAND() LIMIT 1;

            IF v_fd_id IS NULL THEN
                SET v_type = 'DEPOSIT';
                SET v_amount = ROUND(100 + RAND() * 900, 2);
            ELSE
                SET v_timestamp = LEAST(
                    TIMESTAMP(DATE_ADD(v_fd_start, INTERVAL 30 + FLOOR(RAND() * (v_fd_span - 29)) DAY))
                        + INTERVAL (9*3600 + FLOOR(RAND() * 8*3600)) SECOND,
                    fn_now_sl());
            END IF;
        ELSEIF v_type = 'WITHDRAWAL' THEN
            SET v_available = v_balance - v_min_balance;
            IF v_available < 200 THEN
                SET v_type = 'DEPOSIT';
                SET v_amount = ROUND(100 + RAND() * 900, 2);
            ELSE
                SET v_amount = ROUND(100 + RAND() * LEAST(v_available * 0.3, 20000), 2);
            END IF;
        ELSEIF v_type = 'DEPOSIT' THEN
            SET v_amount = ROUND(500 + RAND() * 49500, 2);
        ELSE
            SET v_amount = GREATEST(ROUND(v_balance * 0.10 * 30 / 365, 2), 5.00);
        END IF;

        IF v_type = 'WITHDRAWAL' THEN
            UPDATE savings_account SET balance = balance - v_amount WHERE account_id = v_account_id;
        ELSE
            UPDATE savings_account SET balance = balance + v_amount WHERE account_id = v_account_id;
        END IF;

        IF v_type NOT IN ('DEPOSIT', 'WITHDRAWAL') THEN
            SET v_agent_id = NULL;
        END IF;

        INSERT INTO transaction (account_id, agent_id, fd_id, reference_number,
                                 transaction_type, amount, transaction_timestamp)
        VALUES (v_account_id, v_agent_id, v_fd_id, fn_next_reference_number(),
                v_type, v_amount, v_timestamp);

        SET v_i = v_i + 1;
    END WHILE;

    COMMIT;
END$$

DELIMITER ;