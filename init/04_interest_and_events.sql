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

        SET v_cycle_start = COALESCE(v_last_credit, v_opened);
        SET v_days_passed = DATEDIFF(CURDATE(), v_cycle_start);

        IF v_days_passed >= 30 THEN

            SET v_interest_amount = ROUND(v_balance * (v_rate/100) * (30/365), 2);

            UPDATE savings_account
            SET balance = balance + v_interest_amount,
                last_interest_credit_date = CURDATE()
            WHERE account_id = v_account_id;

            IF v_interest_amount >0 THEN

                SET v_ref_num = fn_next_reference_number();

                

                INSERT INTO transaction(account_id, reference_number, transaction_type, amount, transaction_timestamp)
                VALUES (v_account_id, v_ref_num, 'SAVINGS_INTEREST_CREDIT', v_interest_amount, CURRENT_TIMESTAMP());

            END IF;

            


        END IF;
    END LOOP;

    CLOSE cur;

END$$

DELIMITER ;








