# BTrust-MIMS-DB

Database for the B-Trust Microbanking and Interest Management System (MIMS), Group 28, In24-S3-CS3043 Database Systems. MySQL 8.0, InnoDB.

This repository is the data tier only. The API and the web app live in the BTrust_MIMS-Backend and BTrust-MIMS-Frontend repositories.

## Repository structure

```
BTrust-MIMS-DB/
├── docker-compose.yml                 local stack
├── docker-compose.prod.yml            production stack (Azure virtual machine)
├── README.md
├── deploy/                            Caddyfile, .env.example
├── .github/workflows/deploy.yml       copies the stack files to the server
└── init/
    ├── 01_schema.sql                  12 tables, keys, indexes, constraints
    ├── 02_triggers.sql                minimum balance, one active FD, append-only ledger
    ├── 03_procedures.sql              time helpers, reference numbers, deposit, withdraw, open FD, close FD early
    ├── 04_interest_and_events.sql     savings and FD interest procedures, daily event
    ├── 05_reference_data.sql          5 savings plans, 3 FD plans
    ├── 06_load_sample_data.sql        loads the CSV files
    ├── 07_generate_transactions.sql   sp_seed_sample_transactions()
    ├── 08_admin_audit.sql             audit triggers for admin changes
    ├── 09_reports.sql                 the report views
    ├── 10_users.sh                    creates the three MySQL accounts (passwords from environment variables)
    ├── 11_grants.sql                  permissions for those accounts, no passwords
    └── data/                          admins, branches, agents, customers, savings_accounts,
                                       account_holders, fixed_deposits (CSV)
```

## Quick start (local, Docker)

```bash
docker compose up -d
```

On the first start against an empty volume, MySQL runs every file in `init/` in filename order. Check that nothing failed:

```bash
docker logs mims_db 2>&1 | grep ERROR
```

The command must print nothing.

The database is then available on `localhost:3307`, database name `mims_db`, root password `rootpassword`:

```bash
docker compose exec db mysql -uroot -prootpassword mims_db
```

The CSV files contain no transactions. Create the 100 sample transactions once, after the first start:

```bash
docker compose exec db mysql -uroot -prootpassword mims_db -e "CALL sp_seed_sample_transactions(100);"
```

To start again from an empty database:

```bash
docker compose down -v
docker compose up -d
```

The compose file passes `--secure-file-priv=/docker-entrypoint-initdb.d` so that `LOAD DATA INFILE` in step 06 can read the CSV files from `init/data/`. Writing `--secure-file-priv=""` in a compose list passes two literal quote characters and the load fails with error 1290.

## Sample data

| Table | Rows |
|---|---|
| admin | 1 |
| branch | 3 |
| agent | 5 |
| customer | 15 |
| savings_account | 13 (11 individual, 2 joint) |
| account_holder | 15 |
| fixed_deposit | 10 (all three tenures) |
| transaction | 100 (created by `sp_seed_sample_transactions`) |

The sample transactions come from a procedure and not from a CSV file because every one needs a reference number from `fn_next_reference_number()`, and they are backdated across about 180 days. `sp_deposit` and `sp_withdraw` would refuse backdated rows because of the business-hours check.

## Demo logins

Every seeded admin, agent and customer uses the demo password `password123`. It is for development only. Usernames follow `firstname.lastname`, for example `nimal.perera` (agent) and `anura.fernando` (customer). The demo administrator is `admin.demo`.

## Database accounts

| Account | Used by | Rights |
|---|---|---|
| `mims_owner` | the team | everything on `mims_db` |
| `mims_app` | the backend | read all tables; EXECUTE on `sp_deposit`, `sp_withdraw`, `sp_open_fd`, `sp_close_fd_early`; manage branches, agents, customers and accounts; update only `savings_account.status`. No write on `transaction` or on any balance, no DROP. |
| `mims_reports` | report queries | SELECT on the report views only |

`10_users.sh` creates them from the environment variables `MIMS_OWNER_PASSWORD`, `MIMS_APP_PASSWORD` and `MIMS_REPORTS_PASSWORD`, and `11_grants.sql` sets the permissions. Locally, when the variables are not set, the dev passwords `dev_owner_pw`, `dev_app_pw` and `dev_reports_pw` are used. These are for local use only; on a server always set real values.

## Deploying

Production runs on one Azure virtual machine with `docker-compose.prod.yml`: Caddy (HTTPS, `/api` to the backend), MySQL, a one-time seeder, the backend and the frontend. The images come from ghcr.io.

On the server, create `/opt/mims/.env` from `deploy/.env.example` and fill in the domain, the GitHub owner, the four database passwords and `JWT_SECRET`. The production compose file refuses to start when one is missing. Then:

```bash
docker compose -f docker-compose.prod.yml up -d
```

- MySQL runs `init/` only on an empty data volume. A change to a database script on an existing server needs a manual migration, or `docker compose -f docker-compose.prod.yml down -v` and a new start, which deletes the data.
- The event scheduler is switched on by the compose file, so `ev_daily_interest_credit` runs every day.
- Pushing to `main` runs `.github/workflows/deploy.yml`, which copies `docker-compose.prod.yml`, `deploy/` and `init/` to the server. The backend and frontend repositories deploy their own images.

## Business rules enforced in the database

| Rule | Where |
|---|---|
| Balance never below the plan minimum or below zero | `trg_prevent_below_minimum_balance`, `CHECK (balance >= 0)` |
| One ACTIVE fixed deposit per account | `trg_prevent_second_active_fd`, `trg_prevent_second_active_fd_on_update` |
| Transactions are append-only | `trg_transaction_no_update`, `trg_transaction_no_delete` |
| Daily withdrawal limit of LKR 100,000 | `sp_withdraw` |
| Deposits and withdrawals only between 09:00 and 17:00 Sri Lanka time | `fn_is_business_hours()` in `sp_deposit` and `sp_withdraw` |
| Sri Lanka time everywhere | `fn_now_sl()`, `fn_today_sl()` |
| Unique reference numbers `TXN-YYYYMMDD-NNNNNN` | `fn_next_reference_number()`, `transaction_daily_sequence` |
| Opening an FD debits the savings balance | `sp_open_fd` |
| Early FD closure: flat penalty, payout row and penalty row, refused on or after the maturity date | `sp_close_fd_early` |
| 30-day simple interest for savings and FDs, credited once per cycle | `sp_credit_savings_interest()`, `sp_credit_fd_interest()`, daily event `ev_daily_interest_credit` |
| Each interest credit is its own transaction and rolls back on error | `sp_credit_savings_interest()`, `sp_credit_fd_interest()` |
| Admin changes to reference data are logged | `trg_audit_*` in `08_admin_audit.sql` (the backend sets `@acting_admin_id` first) |
| Reports read only the report views | `09_reports.sql` |

Checked by the application and not by the database: age limits per plan, and setting an account to DORMANT.
