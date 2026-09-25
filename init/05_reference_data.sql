-- 5 savings plans
INSERT INTO savings_plan(plan_name, interest_rate, minimum_balance, min_age, max_age) VALUES
    ('Children', 12.00, 0.00, 0, 12),
    ('Teen', 11.00, 500.00, 13, 17),
    ('Adult', 10.00, 1000.00, 18, 59),
    ('Senior', 13.00, 1000.00, 60, NULL),
    ('Joint', 7.00, 5000.00, NULL, NULL);

-- 3 Fixed deposit plans
INSERT INTO fd_plan(tenure_months, interest_rate, early_closure_penalty_days) VALUES
    (6, 13.00, 90),
    (12, 14.00, 180),
    (36, 15.00, 365);