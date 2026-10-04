-- Trigger to prevent balance from going below minimum balance for savings account

DELIMITER $$

CREATE TRIGGER trg_prevent_below_minimum_balance
BEFORE UPDATE ON savings_account
FOR EACH ROW
BEGIN
    DECLARE v_minimum_balance DECIMAL(15,2);
    IF NEW.balance < OLD.balance THEN
        SELECT minimum_balance INTO v_minimum_balance
        FROM savings_plan
        WHERE plan_id = New.plan_id;
        IF NEW.balance < v_minimum_balance THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Balance cannot be below the minimum balance for the selected plan.';
        END IF;
    END IF;
END$$

DELIMITER ;

-- Trigger to prevent more than one ACTIVE Fixed Deposit for a savings account

DELIMITER $$

CREATE TRIGGER trg_prevent_second_active_fd
BEFORE INSERT ON fixed_deposit
FOR EACH ROW
BEGIN 
    DECLARE v_active_count INT;

    IF NEW.status = 'ACTIVE' THEN
        SELECT COUNT(*) INTO v_active_count
        FROM fixed_deposit
        WHERE account_id = NEW.account_id AND status = 'ACTIVE';

        IF v_active_count > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Rejected: This savings account already has an ACTIVE Fixed Deposit.';
        END IF;
    END IF;
END$$

DELIMITER ;

-- Trigger to prevent more than one ACTIVE Fixed Deposit for a savings account on update
DELIMITER $$

CREATE TRIGGER trg_prevent_second_active_fd_on_update
BEFORE UPDATE ON fixed_deposit
FOR EACH ROW
BEGIN   
    DECLARE v_active_count INT;

    IF NEW.status = 'ACTIVE' AND OLD.status <> 'ACTIVE' THEN
        SELECT COUNT(*) INTO v_active_count
        FROM fixed_deposit
        WHERE account_id = NEW.account_id AND status = 'ACTIVE' AND fd_id <> NEW.fd_id;

        IF v_active_count > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Rejected: This savings account already has an ACTIVE Fixed Deposit.';
        END IF;
    END IF;
END$$

