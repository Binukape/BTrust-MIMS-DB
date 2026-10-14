# BTrust-MIMS-DB

Database for the B-Trust Microbanking and Interest Management System (MIMS), Group 28, In24-S3-CS3043 Database Systems. MySQL 8.0, InnoDB.

This repository is the data tier only. The API and the web app live in the BTrust_MIMS-Backend and BTrust-MIMS-Frontend repositories.

## Repository structure

```
BTrust-MIMS-DB/
├── docker-compose.yml                 local stack (database, seeder, backend, frontend)
├── docker-compose.prod.yml            production stack (Azure virtual machine)
├── README.md
├── deploy/                            Caddyfile, .env.example
├── .github/workflows/
│   ├── deploy.yml                     copies the stack files to the server and checks the site
│   └── reset-database.yml             manual button: rebuild the database from init/
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

The full stack needs the three repositories side by side in one folder:

```
BTrust-MIMS-DB/    BTrust_MIMS-Backend/    BTrust-MIMS-Frontend/
```

From inside `BTrust-MIMS-DB`:

```bash
docker compose up -d --build
```

| Service | What it is | Address |
|---|---|---|
| `db` | MySQL 8.0, runs every file in `init/` on the first start | `localhost:3307` (database `mims_db`, root password `rootpassword`) |
| `seed` | one-time helper that creates the 100 sample transactions, then exits | |
| `backend` | Express API | http://localhost:4000 |
| `frontend` | React app (Vite dev server) | http://localhost:5173 |

To run only the database and the sample transactions:

```bash
docker compose up -d db seed
```

Check that nothing failed during the first start. The command must print nothing:

```bash
docker logs mims_db 2>&1 | grep ERROR
```

Open the database:

```bash
docker compose exec db mysql -uroot -prootpassword mims_db
```

To start again from an empty database:

```bash
docker compose down -v
docker compose up -d --build
```

The compose file passes `--secure-file-priv=/docker-entrypoint-initdb.d` so that `LOAD DATA INFILE` in step 06 can read the CSV files from `init/data/`. Writing `--secure-file-priv=""` in a compose list passes two literal quote characters and the load fails with error 1290. It also passes `--skip-log-bin`: with the binary log on, MySQL refuses to create the stored functions unless they carry `DETERMINISTIC` or data-access labels.

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

Live site: https://btrust-mims-xyz.centralindia.cloudapp.azure.com
Local: http://localhost:5173

Every seeded login uses the same demo password: `password123`. It is for demo data only; the data files hold just its bcrypt hash. Deposits and withdrawals only work from 09:00 to 17:00 Sri Lanka time.

| Role | Username | Password |
|---|---|---|
| Administrator | `admin.demo` | `password123` |

Agents:

| Username | Name | Branch |
|---|---|---|
| `nimal.perera` | Nimal Perera | Colombo Main Branch |
| `kamala.silva` | Kamala Silva | Colombo Main Branch |
| `sunil.bandara` | Sunil Bandara | Kandy Branch |
| `priya.rajapaksa` | Priya Rajapaksa | Kandy Branch |
| `kumar.selvam` | Kumar Selvam | Jaffna Branch |

All agents use the password `password123`.

Customers:

| Username | Name | Agent | Account | Plan |
|---|---|---|---|---|
| `anura.fernando` | Anura Fernando | nimal.perera | SA00000001 | Adult |
| `dilani.wick` | Dilani Wickramasinghe | nimal.perera | SA00000002 | Adult |
| `somasiri.g` | Somasiri Gunawardena | kamala.silva | SA00000003 | Senior |
| `tharindu.j` | Tharindu Jayasuriya | kamala.silva | SA00000004 | Teen |
| `sithumini.p` | Sithumini Perera | sunil.bandara | SA00000005 | Children |
| `ruwan.k` | Ruwan Karunaratne | sunil.bandara | SA00000006 | Adult |
| `chamara.r` | Chamara Rathnayake | priya.rajapaksa | SA00000007 (joint, primary) | Joint |
| `ishara.desilva` | Ishara De Silva | kumar.selvam | SA00000007 (joint, secondary) | Joint |
| `priyantha.w` | Priyantha Wijesekara | nimal.perera | SA00000008 | Senior |
| `nadeeka.a` | Nadeeka Abeysinghe | kamala.silva | SA00000009 | Adult |
| `kavindu.s` | Kavindu Senanayake | sunil.bandara | SA00000010 | Teen |
| `malithi.g` | Malithi Gunasekara | priya.rajapaksa | SA00000011 (joint, primary) | Joint |
| `vishwa.b` | Vishwa Balasubramaniam | kumar.selvam | SA00000011 (joint, secondary) | Joint |
| `sanduni.r` | Sanduni Rodrigo | nimal.perera | SA00000012 | Children |
| `buddhika.e` | Buddhika Ekanayake | kamala.silva | SA00000013 | Adult |

All customers use the password `password123`. An agent only sees their own customers, and a customer only sees their own accounts.

## Database accounts

| Account | Used by | Rights |
|---|---|---|
| `mims_owner` | the team | everything on `mims_db` |
| `mims_app` | the backend | read all tables; EXECUTE on `sp_deposit`, `sp_withdraw`, `sp_open_fd`, `sp_close_fd_early`; manage branches, agents, customers and accounts; update only `savings_account.status`. No write on `transaction` or on any balance, no DROP. |
| `mims_reports` | report queries | SELECT on the report views only |

`10_users.sh` creates them from the environment variables `MIMS_OWNER_PASSWORD`, `MIMS_APP_PASSWORD` and `MIMS_REPORTS_PASSWORD`, and `11_grants.sql` sets the permissions. Locally, when the variables are not set, the dev passwords `dev_owner_pw`, `dev_app_pw` and `dev_reports_pw` are used. These are for local use only; on a server always set real values.

## Deploying

Production runs on one Azure virtual machine with `docker-compose.prod.yml`: Caddy (HTTPS, `/api` to the backend), MySQL, a one-time seeder, the backend and the frontend. The images come from ghcr.io. The site is at https://btrust-mims-xyz.centralindia.cloudapp.azure.com.

On the server, `/opt/mims/.env` (created from `deploy/.env.example`, never committed) holds the domain, the GitHub owner, the four database passwords and `JWT_SECRET`. The production compose file refuses to start when one is missing.

How a change reaches the server:

| You push to `main` in | What happens |
|---|---|
| BTrust_MIMS-Backend | tests, builds the image (tagged `latest` and with the commit id), pushes it to ghcr.io, runs `docker compose pull backend` and `up -d` on the server |
| BTrust-MIMS-Frontend | the same for the frontend image |
| BTrust-MIMS-DB (compose file, `deploy/`, `init/`) | copies those files to `/opt/mims` and runs `docker compose up -d` |

Every deployment ends by calling `/api/health` on the public address for up to five minutes; if the site does not answer, the run turns red. The commands on the server run under a lock, so two deployments never overlap.

**Database changes need the Reset button.** MySQL runs the files in `init/` only when the data volume is empty, so a push that changes a table, trigger, procedure or CSV file is copied to the server but not applied to the existing database. To apply it (and to restore the demo data), open the Actions tab of this repository, choose **Reset database**, click **Run workflow** and type `RESET`. It deletes all data, rebuilds the database from `init/` with the sample data, and checks the site. From a terminal: `gh workflow run reset-database.yml -f confirm=RESET`.

The event scheduler is switched on by the compose file, so `ev_daily_interest_credit` runs every day at 01:00 server time (06:30 Sri Lanka time).

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

## Team and contributions

Group 28, In24-S3-CS3043 Database Systems.

| Member | Handled |
|---|---|
| Perera K.D.B.M. (Binuka) | System architecture, the money procedures and functions, the report views, the MySQL accounts and their rights, Docker, Azure hosting and CI/CD |
| Ranathunga N.R.A.K.H.K. | The database schema, login and authentication, access control, and the admin portal with the audit log |
| Jackson J.W. | The triggers, the reference data, customer registration and account opening |
| Pranav M.A. | Deposits and withdrawals, fixed deposits, and the nightly interest procedures and event |
| Isiwara M.A.G.A. | Reports and exports, the sample data and transaction seeder, and testing |

The files each member wrote are listed in the READMEs of the backend and frontend repositories.
