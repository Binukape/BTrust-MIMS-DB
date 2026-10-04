create table branch(
    branch_id int auto_increment primary key,
    branch_name varchar(100) not null,
    branch_address varchar(255) not null,
    branch_phone varchar(20) not null
);

create table  agent(
    agent_id int auto_increment primary key,
    branch_id int not null,
    agent_name varchar(100) not null,
    agent_nic varchar(20) not null unique,
    username varchar(50) not null unique,
    password_hash varchar(255) not null,
    created_at datetime not null  default current_timestamp, 

    foreign key (branch_id) references branch(branch_id),

    index index_agent_branch_id(branch_id)
);

create table customer(
    customer_id int auto_increment primary key,
    agent_id int not null,
    full_name varchar(100) not null,
    nic_number varchar(20) not null unique,
    address varchar(255) not null,
    phone varchar(20) not null,
    date_of_birth date not null,
    username varchar(50) not null unique,
    password_hash varchar(255) not null,
    created_at datetime not null default current_timestamp,

    foreign key (agent_id) references agent(agent_id) ,
    index index_customer_agent_id(agent_id)
);

create table savings_plan(
    plan_id int auto_increment primary key ,
    plan_name varchar(20) not null unique,
    interest_rate decimal(5,2) not null,
    minimum_balance decimal(15,2) not null ,
    min_age int null,
    max_age int null

);


create table savings_account (
    account_id int auto_increment primary key,
    plan_id int not null,
    branch_id int not null,
    account_number varchar(20) not null unique,
    balance decimal(15,2) not null default 0.00,
    last_interest_credit_date date null,
    is_joint boolean not null default false,
    status enum ('ACTIVE','CLOSED','DORMANT') not null default 'ACTIVE',
    opened_date date not null,
    
    foreign key (plan_id) references savings_plan(plan_id),
    foreign key (branch_id) references branch(branch_id) ,

    index index_saving_account_plan_id(plan_id),
    index index_saving_account_branch_id(branch_id),
    index index_saving_account_status(status)
);


create table account_holder(
    account_id int ,
    customer_id int ,
    holder_role varchar(20) not null default 'PRIMARY',

    primary key (account_id,customer_id),
    foreign key (account_id) references savings_account(account_id),
    foreign key (customer_id) references customer(customer_id),

    index account_holder_customer_id(customer_id)
);

create table fd_plan(
    fd_plan_id int auto_increment primary key ,
    tenure_months int not null unique,
    interest_rate decimal(5,2) not null,
    early_closure_penalty_days int not null
);

create table fixed_deposit(
    fd_id int auto_increment primary key,
    account_id int not null,
    fd_plan_id int not null,
    principal_amount decimal(15,2) not null,
    interest_rate_snapshot decimal(5,2) not null,
    start_date date not null,
    maturity_date date not null,
    last_interest_credit_date date null,
    status enum('ACTIVE', 'MATURED' , 'CLOSED') not null default 'ACTIVE',

    foreign key (account_id) references savings_account(account_id),
    foreign key (fd_plan_id) references fd_plan(fd_plan_id),

    index fixed_deposit_account_id(account_id),
    index fixed_deposit_status(status)
);


create table transaction (
    transaction_id int auto_increment primary key,
    account_id int not null,
    agent_id int null,
    fd_id int null, 
    reference_number varchar(30) not null unique,
    transaction_type enum('DEPOSIT','WITHDRAWAL','SAVINGS_INTEREST_CREDIT','FD_INTEREST_CREDIT','FD_MATURITY_PAYOUT','FD_EARLY_CLOSURE_ADJUSTMENT') NOT NULL,
    amount decimal(15,2) not null,
    transaction_timestamp datetime not null default current_timestamp, 

    foreign key (account_id) references savings_account(account_id),
    foreign key (agent_id) references agent(agent_id),
    foreign key(fd_id) references fixed_deposit(fd_id),

    index transaction_account_id(account_id),
    index transaction_agent_id(agent_id),
    index transaction_fd_id(fd_id),
    index transaction_transaction_type(transaction_type),
    index transaction_transaction_timestamp(transaction_timestamp)
    

);

create table transaction_daily_sequence(
    seq_date date primary key,
    last_seq int not null default 0
);