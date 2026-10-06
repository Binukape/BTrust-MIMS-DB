DELIMITER $$

CREATE TRIGGER trg_audit_branch_insert AFTER INSERT ON branch
FOR EACH ROW
BEGIN
    IF @acting_admin_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Admin change rejected: acting admin is not set';
    END IF;
    INSERT INTO admin_audit_log (admin_id, action, table_name, record_id, old_values, new_values, changed_at)
    VALUES (@acting_admin_id, 'INSERT', 'branch', NEW.branch_id, NULL,
            JSON_OBJECT('branch_name', NEW.branch_name, 'branch_address', NEW.branch_address, 'branch_phone', NEW.branch_phone),
            fn_now_sl());
END$$

CREATE TRIGGER trg_audit_branch_update AFTER UPDATE ON branch
FOR EACH ROW
BEGIN
    IF @acting_admin_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Admin change rejected: acting admin is not set';
    END IF;
    INSERT INTO admin_audit_log (admin_id, action, table_name, record_id, old_values, new_values, changed_at)
    VALUES (@acting_admin_id, 'UPDATE', 'branch', NEW.branch_id,
            JSON_OBJECT('branch_name', OLD.branch_name, 'branch_address', OLD.branch_address, 'branch_phone', OLD.branch_phone),
            JSON_OBJECT('branch_name', NEW.branch_name, 'branch_address', NEW.branch_address, 'branch_phone', NEW.branch_phone),
            fn_now_sl());
END$$

CREATE TRIGGER trg_audit_branch_delete AFTER DELETE ON branch
FOR EACH ROW
BEGIN
    IF @acting_admin_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Admin change rejected: acting admin is not set';
    END IF;
    INSERT INTO admin_audit_log (admin_id, action, table_name, record_id, old_values, new_values, changed_at)
    VALUES (@acting_admin_id, 'DELETE', 'branch', OLD.branch_id,
            JSON_OBJECT('branch_name', OLD.branch_name, 'branch_address', OLD.branch_address, 'branch_phone', OLD.branch_phone),
            NULL, fn_now_sl());
END$$

CREATE TRIGGER trg_audit_agent_insert AFTER INSERT ON agent
FOR EACH ROW
BEGIN
    IF @acting_admin_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Admin change rejected: acting admin is not set';
    END IF;
    INSERT INTO admin_audit_log (admin_id, action, table_name, record_id, old_values, new_values, changed_at)
    VALUES (@acting_admin_id, 'INSERT', 'agent', NEW.agent_id, NULL,
            JSON_OBJECT('branch_id', NEW.branch_id, 'agent_name', NEW.agent_name, 'agent_nic', NEW.agent_nic, 'username', NEW.username),
            fn_now_sl());
END$$

CREATE TRIGGER trg_audit_agent_update AFTER UPDATE ON agent
FOR EACH ROW
BEGIN
    IF @acting_admin_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Admin change rejected: acting admin is not set';
    END IF;
    INSERT INTO admin_audit_log (admin_id, action, table_name, record_id, old_values, new_values, changed_at)
    VALUES (@acting_admin_id, 'UPDATE', 'agent', NEW.agent_id,
            JSON_OBJECT('branch_id', OLD.branch_id, 'agent_name', OLD.agent_name, 'agent_nic', OLD.agent_nic, 'username', OLD.username),
            JSON_OBJECT('branch_id', NEW.branch_id, 'agent_name', NEW.agent_name, 'agent_nic', NEW.agent_nic, 'username', NEW.username,
                        'password_changed', NEW.password_hash <> OLD.password_hash),
            fn_now_sl());
END$$

CREATE TRIGGER trg_audit_agent_delete AFTER DELETE ON agent
FOR EACH ROW
BEGIN
    IF @acting_admin_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Admin change rejected: acting admin is not set';
    END IF;
    INSERT INTO admin_audit_log (admin_id, action, table_name, record_id, old_values, new_values, changed_at)
    VALUES (@acting_admin_id, 'DELETE', 'agent', OLD.agent_id,
            JSON_OBJECT('branch_id', OLD.branch_id, 'agent_name', OLD.agent_name, 'agent_nic', OLD.agent_nic, 'username', OLD.username),
            NULL, fn_now_sl());
END$$

CREATE TRIGGER trg_audit_savings_plan_insert AFTER INSERT ON savings_plan
FOR EACH ROW
BEGIN
    IF @acting_admin_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Admin change rejected: acting admin is not set';
    END IF;
    INSERT INTO admin_audit_log (admin_id, action, table_name, record_id, old_values, new_values, changed_at)
    VALUES (@acting_admin_id, 'INSERT', 'savings_plan', NEW.plan_id, NULL,
            JSON_OBJECT('plan_name', NEW.plan_name, 'interest_rate', NEW.interest_rate, 'minimum_balance', NEW.minimum_balance,
                        'min_age', NEW.min_age, 'max_age', NEW.max_age),
            fn_now_sl());
END$$

CREATE TRIGGER trg_audit_savings_plan_update AFTER UPDATE ON savings_plan
FOR EACH ROW
BEGIN
    IF @acting_admin_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Admin change rejected: acting admin is not set';
    END IF;
    INSERT INTO admin_audit_log (admin_id, action, table_name, record_id, old_values, new_values, changed_at)
    VALUES (@acting_admin_id, 'UPDATE', 'savings_plan', NEW.plan_id,
            JSON_OBJECT('plan_name', OLD.plan_name, 'interest_rate', OLD.interest_rate, 'minimum_balance', OLD.minimum_balance,
                        'min_age', OLD.min_age, 'max_age', OLD.max_age),
            JSON_OBJECT('plan_name', NEW.plan_name, 'interest_rate', NEW.interest_rate, 'minimum_balance', NEW.minimum_balance,
                        'min_age', NEW.min_age, 'max_age', NEW.max_age),
            fn_now_sl());
END$$

CREATE TRIGGER trg_audit_savings_plan_delete AFTER DELETE ON savings_plan
FOR EACH ROW
BEGIN
    IF @acting_admin_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Admin change rejected: acting admin is not set';
    END IF;
    INSERT INTO admin_audit_log (admin_id, action, table_name, record_id, old_values, new_values, changed_at)
    VALUES (@acting_admin_id, 'DELETE', 'savings_plan', OLD.plan_id,
            JSON_OBJECT('plan_name', OLD.plan_name, 'interest_rate', OLD.interest_rate, 'minimum_balance', OLD.minimum_balance,
                        'min_age', OLD.min_age, 'max_age', OLD.max_age),
            NULL, fn_now_sl());
END$$

CREATE TRIGGER trg_audit_log_no_update
BEFORE UPDATE ON admin_audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Audit log rows cannot be updated';
END$$

CREATE TRIGGER trg_audit_log_no_delete
BEFORE DELETE ON admin_audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Audit log rows cannot be deleted';
END$$

DELIMITER ;
