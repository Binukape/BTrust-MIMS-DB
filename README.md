# BTrust-MIMS-DB — Starter Dev Environment

This is a **starter kit**, not a finished database. It contains everything EXCEPT the actual SQL logic — that part is what you're building yourself, using the companion document `BTrust_MIMS_DB_Beginner_Task_Guide.md`.

## What's already here

```
BTrust-MIMS-DB/
├── docker-compose.yml       — fully working, ready to use as-is
├── README.md                 — this file
└── init/
    └── data/                  — all 6 sample data CSVs, fully populated and ready to load
        ├── branches.csv
        ├── agents.csv
        ├── customers.csv
        ├── savings_accounts.csv
        ├── account_holders.csv
        └── fixed_deposits.csv
```

## What you need to build

Inside the `init/` folder (alongside the existing `data/` folder), you need to create these 7 files, following the Beginner's Task Guide:

```
init/
├── 01_schema.sql
├── 02_triggers.sql
├── 03_procedures.sql
├── 04_interest_and_events.sql
├── 05_reference_data.sql
├── 06_load_sample_data.sql
└── 07_generate_transactions.sql
```

And at the repository root, alongside `docker-compose.yml`:

```
build.sql
```

**The numeric prefixes (01_, 02_, etc.) matter.** Docker's MySQL image automatically runs every file it finds in `init/` in filename order, the very first time it starts against an empty database — so the numbering is what guarantees your schema exists before your triggers try to attach to it, and so on.

## How to test your work as you go

Once you've created at least `01_schema.sql`, you can already start the database and see it apply automatically:

```bash
docker compose up -d
```

To check what actually happened (useful after every change):

```bash
docker logs mims_db
```

To connect directly and poke around:

```bash
docker exec -it mims_db mysql -uroot -prootpassword mims_db
```

**Important:** Docker's automatic file-running only happens on a completely empty database volume. If you add or change a file after the container has already started once, it won't re-run automatically. To force a clean re-run after editing a file:

```bash
docker compose down -v
docker compose up -d
```

(`-v` also deletes the stored data volume, wiping everything and forcing a genuinely fresh start — this is exactly what you want while you're still actively building and testing.)

Once you've written `07_generate_transactions.sql`, generate the required 100 sample transactions with:

```bash
docker exec -it mims_db mysql -uroot -prootpassword mims_db -e "CALL sp_seed_sample_transactions(100);"
```

(Adjust the procedure name above if you named it differently — this assumes you followed the guide's suggested naming.)

## Demo login credentials

Every row in `agents.csv` and `customers.csv` shares the same pre-computed password hash. The real password behind that hash is:

**`password123`**

This is for local development convenience only — never treat this as real security, and never reuse this pattern outside of local sample data.

## A note on the sample data you've been given

Look closely at `customers.csv` before you write your loader (Task 6) — the birth dates were deliberately chosen to span every age-eligible savings plan band your schema will define, and `account_holders.csv` deliberately links two pairs of customers to the same account twice each, to represent the two required joint accounts. Understanding *why* the data looks the way it does will help you sanity-check your own schema and triggers once you start loading it.

## Once your database is fully built

Come back to this README and consider adding:
- A "Key business rules enforced at the database level" reference table, documenting which trigger or procedure enforces which rule, for anyone else reading your finished project.
- Deployment notes if you ever need to run this against a real cloud database host instead of just locally in Docker — in particular, note that `LOAD DATA INFILE`'s file paths and the `SOURCE` command in `build.sql` both behave differently outside of a local Docker setup.
