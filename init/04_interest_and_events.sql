DELIMITER $$ 
CREATE PROCEDURE sp_credit_savings_interest()
BEGIN

    DECLARE done INT DEFAULT FALSE;

    DECLARE v_fd_id INT;
    DECLARE v_account_id INT;
    DECLARE v_balance DECIMAL(15,2);
    DECLARE v_last_credit DATE;
    DECLARE v_opened DATE;
    DECLARE v_rate DECIMAL(5,2);    

    DECLARE v_cycle_start DATE;
    DECLARE v_days_passed INT;
    DECLARE v_interest_amount DECIMAL(15, 2);
    DECLARE v_ref_num VARCHAR(30);

    DECLARE cur CURSOR FOR 
    SELECT 
        sa.account_id, 
        sa.balance, 
        sa.last_interest_credit_date, 
        sa.opened_date, 
        sp.interest_rate 
    FROM savings_account sa 
    JOIN savings_plan sp ON sa.plan_id = sp.plan_id
    WHERE sa.status = 'ACTIVE';
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    
    OPEN cur;

    read_loop: LOOP

        FETCH cur INTO v_account_id, v_balance, v_last_credit, v_opened, v_rate;

        IF done THEN LEAVE read_loop; END IF;
        one_account: BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
        END;
        START TRANSACTION;
        SELECT balance INTO v_balance FROM savings_account WHERE account_id = v_account_id FOR UPDATE;

        SET v_cycle_start = COALESCE(v_last_credit, v_opened);
        SET v_days_passed = DATEDIFF(fn_today_sl(), v_cycle_start);

        IF v_days_passed >= 30 THEN

            SET v_interest_amount = ROUND(v_balance * (v_rate/100) * (30/365), 2);

            UPDATE savings_account
            SET balance = balance + v_interest_amount,
                last_interest_credit_date = fn_today_sl()
            WHERE account_id = v_account_id;

            IF v_interest_amount >0 THEN

                SET v_ref_num = fn_next_reference_number();

                

                INSERT INTO transaction(account_id, reference_number, transaction_type, amount, transaction_timestamp)
                VALUES (v_account_id, v_ref_num, 'SAVINGS_INTEREST_CREDIT', v_interest_amount, fn_now_sl());

            END IF;

            


        END IF;
        COMMIT;
        END one_account;
    END LOOP;

    CLOSE cur;

END$$

DELIMITER ;


DELIMITER $$

CREATE PROCEDURE sp_credit_fd_interest()
BEGIN
    DECLARE done INT DEFAULT FALSE;

    DECLARE v_fd_id INT;
    DECLARE v_account_id INT;
    DECLARE v_principal_amount DECIMAL(15, 2);
    DECLARE v_interest_rate DECIMAL(5, 2);
    DECLARE v_start_date DATE;
    DECLARE v_maturity_date DATE;
    DECLARE v_last_credit_date DATE;

    DECLARE v_cycle_start DATE;
    DECLARE v_days_passed INT;
    DECLARE v_interest_amount DECIMAL(15, 2);
    DECLARE v_ref_num VARCHAR(30);

    DECLARE final_days INT;
    DECLARE final_interest DECIMAL(15, 2);
    DECLARE v_status VARCHAR(10);


    DECLARE cur CURSOR FOR
    SELECT
        fd_id,
        account_id,
        principal_amount,
        interest_rate_snapshot,
        start_date,
        maturity_date,
        last_interest_credit_date
    FROM fixed_deposit
    WHERE status = 'ACTIVE';


    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;


    OPEN cur;

    read_loop: LOOP

        FETCH cur INTO v_fd_id, v_account_id, v_principal_amount, v_interest_rate, v_start_date, v_maturity_date, v_last_credit_date;
        IF done THEN LEAVE read_loop; END IF;
        one_fd: BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
        END;
        START TRANSACTION;
        SELECT status INTO v_status FROM fixed_deposit WHERE fd_id = v_fd_id FOR UPDATE;
        IF v_status = 'ACTIVE' THEN
        

        SET v_cycle_start = COALESCE(v_last_credit_date, v_start_date);

        IF fn_today_sl() >= v_maturity_date THEN

            
            SET final_days = GREATEST(DATEDIFF(v_maturity_date, v_cycle_start), 0);
            SET final_interest = ROUND(v_principal_amount * (v_interest_rate / 100) * (final_days / 365), 2);
            

            UPDATE fixed_deposit
            SET status = 'MATURED',
                last_interest_credit_date = v_maturity_date
            WHERE fd_id = v_fd_id;

            UPDATE savings_account
            SET balance = balance + (v_principal_amount + final_interest)
            WHERE account_id = v_account_id;

            SET v_ref_num = fn_next_reference_number();

            INSERT INTO transaction(account_id, fd_id, reference_number, transaction_type, amount, transaction_timestamp)
            VALUES (v_account_id, v_fd_id, v_ref_num, 'FD_MATURITY_PAYOUT', v_principal_amount + final_interest, fn_now_sl());

        ELSE
            SET v_days_passed = DATEDIFF(fn_today_sl(), v_cycle_start);


            IF v_days_passed >= 30 THEN

                SET v_interest_amount = ROUND(v_principal_amount * (v_interest_rate/100) * (30/365), 2);

                UPDATE savings_account
                SET balance = balance + v_interest_amount
                WHERE account_id = v_account_id;

                UPDATE fixed_deposit
                SET last_interest_credit_date = fn_today_sl()
                WHERE fd_id = v_fd_id;

                IF v_interest_amount >0 THEN

                    SET v_ref_num = fn_next_reference_number();

                    

                    INSERT INTO transaction(account_id, fd_id, reference_number, transaction_type, amount, transaction_timestamp)
                    VALUES (v_account_id, v_fd_id, v_ref_num, 'FD_INTEREST_CREDIT', v_interest_amount, fn_now_sl());

                END IF;

            END IF;
        END IF;
        END IF;
        COMMIT;
        END one_fd;

    END LOOP;

    CLOSE cur;

END $$

DELIMITER ;


SET GLOBAL event_scheduler = ON;

DELIMITER $$
CREATE EVENT IF NOT EXISTS ev_daily_interest_credit
ON SCHEDULE EVERY 1 DAY
STARTS (TIMESTAMP(CURRENT_DATE) + INTERVAL 1 DAY + INTERVAL 1 HOUR)
DO 
BEGIN
    -- Execute in the exact order specified
    CALL sp_credit_savings_interest();
    CALL sp_credit_fd_interest();
END$$

DELIMITER ;







