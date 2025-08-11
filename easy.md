## SQL Guide for Daffodil Bank

This document explains the database schema and all important SQL queries used by the app, with easy examples and simplified join patterns. It is based on `database/setup.sql`, `database/demo_data.sql`, and the queries in `classes/*.php` and `admin/*.php`.

### Schema overview
- **users**: customer profiles. Primary key `user_id`.
- **admin_users**: admins/staff. Primary key `admin_id`.
- **accounts**: bank accounts. Primary key `account_id`; FK `user_id → users(user_id)`; optional FK `created_by_admin → admin_users(admin_id)`.
- **transactions**: money movements. Primary key `transaction_id`; FKs `from_account_id` and `to_account_id → accounts(account_id)`; may be NULL for deposit/withdrawal sides.
- **account_types**: reference/types (Savings, Checking, Business).
- **audit_logs**: records of admin/user actions.

Key indexes: emails/usernames on `users`, account number and `user_id` on `accounts`, from/to account and created date on `transactions`. These help filters and joins.

### Demo data snapshots
Small sample from `database/demo_data.sql` to anchor examples.

- Users

| user_id | username       | first_name | last_name | email                         | status   |
|--------:|----------------|------------|-----------|-------------------------------|----------|
| 1       | alice_johnson  | Alice      | Johnson   | alice.johnson@email.com       | approved |
| 2       | bob_smith      | Bob        | Smith     | bob.smith@email.com           | approved |

- Accounts (selected)

| account_id | user_id | account_number | account_type | balance   | status |
|-----------:|--------:|----------------|--------------|-----------|--------|
| 1          | 1       | DAF000001001   | savings      | 195000.00 | active |
| 2          | 1       | DAF000001002   | checking     | 17000.00  | active |

- Transactions (selected)

| txn_id | from_acct | to_acct | type      | amount  | status    | reference       | created_at           |
|-------:|----------:|--------:|-----------|---------|-----------|-----------------|----------------------|
| 1      | 1         | 2       | transfer  | 5000.00 | completed | TXN202408030001 | 2024-08-01 10:30:00  |
| 11     | NULL      | 1       | deposit   | 50000.00| completed | TXN202408030011 | 2024-08-01 08:00:00  |
| 46     | 45        | 1       | transfer  | 11000.00| completed | TXN202408030046 | now() - 9 hours      |


## Stored logic

### Trigger: auto-update balances
Defined in `database/setup.sql`

```sql
CREATE TRIGGER update_account_balance_after_transaction
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
  IF NEW.status = 'completed' THEN
    CASE NEW.transaction_type
      WHEN 'deposit' THEN
        UPDATE accounts SET balance = balance + NEW.amount
        WHERE account_id = NEW.to_account_id;
      WHEN 'withdrawal' THEN
        UPDATE accounts SET balance = balance - NEW.amount
        WHERE account_id = NEW.from_account_id;
      WHEN 'transfer' THEN
        UPDATE accounts SET balance = balance - NEW.amount
        WHERE account_id = NEW.from_account_id;
        UPDATE accounts SET balance = balance + NEW.amount
        WHERE account_id = NEW.to_account_id;
    END CASE;
  END IF;
END;
```

Effect: when an INSERTed transaction is completed, balances adjust automatically. No manual balance math needed in app code.

### Procedure: CreateAccount

```sql
CALL CreateAccount(:user_id, :account_type, :admin_id, @account_number);
SELECT @account_number;
```

What happens:
- Counts existing accounts for the user
- Builds account number like `DAF<user padded><seq padded>`, e.g. `DAF000001003`
- Inserts new row in `accounts`

Example: For `user_id=1` (Alice) who already has 2 accounts, calling with `savings` returns `DAF000001003` and inserts it.

### Procedure: TransferMoney

```sql
CALL TransferMoney(:from_account, :to_account, :amount, :description, @result, @reference);
SELECT @result, @reference;
```

What happens:
- Checks `from_account` balance ≥ amount
- If OK: inserts a `transactions` row with status `completed` and returns `SUCCESS` + auto-generated reference
- If not: returns `INSUFFICIENT_FUNDS`


## Queries by feature

### Users (from `classes/User.php`)

- Register

```sql
INSERT INTO users
SET username=:username, email=:email, password_hash=:password_hash,
    first_name=:first_name, last_name=:last_name, phone=:phone,
    address=:address, date_of_birth=:date_of_birth;
```

- Login

```sql
SELECT user_id, username, email, password_hash, first_name, last_name,
       registration_status, is_active
FROM users
WHERE (username = :username OR email = :username)
  AND is_active = 1;
```

Example: `:username = 'alice_johnson'` finds Alice; app verifies the password hash and requires `registration_status='approved'`.

- Existence check

```sql
SELECT user_id FROM users
WHERE username = :username OR email = :email;
```

- Get by id / update profile / change password

```sql
SELECT * FROM users WHERE user_id = :user_id;

UPDATE users
SET first_name=:first_name, last_name=:last_name, phone=:phone,
    address=:address, date_of_birth=:date_of_birth
WHERE user_id=:user_id;

UPDATE users
SET password_hash=:password_hash
WHERE user_id=:user_id;
```

- Update registration status / activate-deactivate

```sql
UPDATE users SET registration_status=:status WHERE user_id=:user_id;
UPDATE users SET is_active=:is_active WHERE user_id=:user_id;
```

- Hard-delete safety checks (simplified view)

```sql
-- Active/pending accounts count
SELECT COUNT(*) FROM accounts
WHERE user_id = :user_id AND status IN ('active','pending');

-- Total balance across active accounts
SELECT SUM(balance) FROM accounts
WHERE user_id = :user_id AND status = 'active';

-- Any transactions involving user’s accounts
SELECT COUNT(*)
FROM transactions t
JOIN accounts a ON (t.from_account_id = a.account_id OR t.to_account_id = a.account_id)
WHERE a.user_id = :user_id;
```

Tip: The OR join uses indexes but can still be heavy on large data; see “Simplified joins” below for patterns using `UNION ALL`.


### Accounts (from `classes/Account.php`)

- Create via procedure (see above `CreateAccount`).

- Get by id / by account number

```sql
SELECT a.*, u.first_name, u.last_name, u.email, u.phone
FROM accounts a
JOIN users u ON a.user_id = u.user_id
WHERE a.account_id = :account_id; -- or a.account_number = :account_number
```

- User’s accounts

```sql
SELECT *
FROM accounts
WHERE user_id = :user_id
ORDER BY created_at DESC;
``;

- All accounts (with holder and creator)

```sql
SELECT a.*, u.first_name, u.last_name, u.email, u.username,
       au.full_name AS created_by_name
FROM accounts a
JOIN users u ON a.user_id = u.user_id
LEFT JOIN admin_users au ON a.created_by_admin = au.admin_id
-- optional WHERE a.status = :status
ORDER BY a.created_at DESC
LIMIT :limit OFFSET :offset;
```

- Search accounts

```sql
SELECT a.*, u.first_name, u.last_name, u.email, u.username,
       au.full_name AS created_by_name
FROM accounts a
JOIN users u ON a.user_id = u.user_id
LEFT JOIN admin_users au ON a.created_by_admin = au.admin_id
WHERE (
  a.account_number LIKE :q OR u.first_name LIKE :q OR u.last_name LIKE :q OR
  u.email LIKE :q OR u.username LIKE :q OR a.account_type LIKE :q OR
  CONCAT(u.first_name,' ',u.last_name) LIKE :q
)
-- optional AND a.status=:status
ORDER BY a.created_at DESC
LIMIT :limit OFFSET :offset;
```

- Update status / get balance / manual balance adjust

```sql
UPDATE accounts SET status=:status WHERE account_id=:account_id;

SELECT balance FROM accounts WHERE account_id=:account_id;

-- Manual balance adjustment records a compensating transaction;
-- The trigger applies the actual balance update.
INSERT INTO transactions
  (from_account_id, to_account_id, transaction_type, amount, description,
   reference_number, status)
VALUES (:from, :to, :type, :amount, :desc, :ref, 'completed');
```

- Account summary (original) and a simpler faster variant

Original uses an OR join and GROUP BY:

```sql
SELECT a.*, u.first_name, u.last_name, u.email,
       COUNT(t.transaction_id) AS total_transactions,
       SUM(CASE WHEN t.transaction_type='deposit' AND t.status='completed' THEN t.amount ELSE 0 END) AS total_deposits,
       SUM(CASE WHEN t.transaction_type='withdrawal' AND t.status='completed' THEN t.amount ELSE 0 END) AS total_withdrawals,
       MAX(t.created_at) AS last_transaction_date
FROM accounts a
JOIN users u ON a.user_id = u.user_id
LEFT JOIN transactions t ON (a.account_id = t.from_account_id OR a.account_id = t.to_account_id)
WHERE a.account_id = :account_id
GROUP BY a.account_id;
```

Simpler scalar subqueries (index-friendly; no GROUP BY needed):

```sql
SELECT a.*, u.first_name, u.last_name, u.email,
  (SELECT COUNT(*) FROM transactions t
   WHERE t.from_account_id=a.account_id OR t.to_account_id=a.account_id) AS total_transactions,
  (SELECT SUM(t.amount) FROM transactions t
   WHERE t.transaction_type='deposit' AND t.status='completed' AND t.to_account_id=a.account_id) AS total_deposits,
  (SELECT SUM(t.amount) FROM transactions t
   WHERE t.transaction_type='withdrawal' AND t.status='completed' AND t.from_account_id=a.account_id) AS total_withdrawals,
  (SELECT MAX(t.created_at) FROM transactions t
   WHERE t.from_account_id=a.account_id OR t.to_account_id=a.account_id) AS last_transaction_date
FROM accounts a
JOIN users u ON a.user_id=u.user_id
WHERE a.account_id=:account_id;
```

Example for `account_id=1` (Alice’s savings with demo data):
- total_transactions = 3 (one deposit into 1, one outgoing transfer 1→2, one incoming transfer 45→1)
- total_deposits = 50,000 (only deposit-type into 1)
- total_withdrawals = 0 (withdrawal-type from 1)

- Delete options checks

```sql
SELECT COUNT(*) FROM transactions
WHERE from_account_id=:account_id OR to_account_id=:account_id;

DELETE FROM accounts WHERE account_id=:account_id; -- only if allowed
```


### Transactions (from `classes/Transaction.php`)

- Transfer via procedure (see `TransferMoney`).

- Deposit / Withdraw

```sql
-- Deposit
INSERT INTO transactions
  (to_account_id, transaction_type, amount, description, reference_number, status)
VALUES (:account_id, 'deposit', :amount, :desc, :ref, 'completed');

-- Withdraw (after checking balance first)
INSERT INTO transactions
  (from_account_id, transaction_type, amount, description, reference_number, status)
VALUES (:account_id, 'withdrawal', :amount, :desc, :ref, 'completed');
```

- Transaction with party details (by id or by reference)

```sql
SELECT t.*,
       fa.account_number AS from_account_number,
       ta.account_number AS to_account_number,
       fu.first_name AS from_user_first, fu.last_name AS from_user_last,
       tu.first_name AS to_user_first,   tu.last_name AS to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id   = ta.account_id
LEFT JOIN users   fu ON fa.user_id = fu.user_id
LEFT JOIN users   tu ON ta.user_id = tu.user_id
WHERE t.transaction_id = :id; -- or t.reference_number = :reference
```

- Account transactions feed (simplify OR with UNION ALL)

Original uses `WHERE (t.from_account_id=:id OR t.to_account_id=:id)` and CASE. A more index-friendly form:

```sql
SELECT * FROM (
  SELECT t.*, 'outgoing' AS direction,
         fa.account_number AS from_account_number,
         ta.account_number AS to_account_number
  FROM transactions t
  JOIN accounts fa ON t.from_account_id = fa.account_id
  LEFT JOIN accounts ta ON t.to_account_id = ta.account_id
  WHERE t.from_account_id = :account_id AND t.status='completed'
  UNION ALL
  SELECT t.*, 'incoming' AS direction,
         fa.account_number,
         ta.account_number
  FROM transactions t
  LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
  JOIN accounts ta ON t.to_account_id = ta.account_id
  WHERE t.to_account_id = :account_id AND t.status='completed'
) x
ORDER BY x.created_at DESC
LIMIT :limit OFFSET :offset;
```

- User transactions feed (two-branch UNION ALL keeps direction clear, avoids CASE logic):

```sql
SELECT t.*, 'outgoing' AS direction,
       fa.account_number AS account_number, fa.account_type AS account_type,
       fu.first_name AS from_user_first, fu.last_name AS from_user_last,
       tu.first_name AS to_user_first,   tu.last_name AS to_user_last
FROM transactions t
JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id = ta.account_id
LEFT JOIN users fu ON fa.user_id = fu.user_id
LEFT JOIN users tu ON ta.user_id = tu.user_id
WHERE fa.user_id = :user_id AND t.status='completed'
-- optional filters: account/type/date
UNION ALL
SELECT t.*, 'incoming' AS direction,
       ta.account_number, ta.account_type,
       fu.first_name, fu.last_name,
       tu.first_name, tu.last_name
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
JOIN accounts ta ON t.to_account_id = ta.account_id
LEFT JOIN users fu ON fa.user_id = fu.user_id
LEFT JOIN users tu ON ta.user_id = tu.user_id
WHERE ta.user_id = :user_id AND t.status='completed'
-- same optional filters
ORDER BY created_at DESC
LIMIT :limit OFFSET :offset;
```

- Transaction list (admin)

```sql
SELECT t.*,
       fa.account_number AS from_account_number,
       ta.account_number AS to_account_number,
       fu.first_name AS from_user_first, fu.last_name AS from_user_last,
       tu.first_name AS to_user_first,   tu.last_name AS to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id   = ta.account_id
LEFT JOIN users   fu ON fa.user_id = fu.user_id
LEFT JOIN users   tu ON ta.user_id = tu.user_id
-- optional WHERE t.status=:status AND/OR t.transaction_type=:type
ORDER BY t.created_at DESC
LIMIT :limit OFFSET :offset;
```

- Stats by type

```sql
SELECT t.transaction_type,
       COUNT(*) AS count,
       SUM(t.amount) AS total_amount,
       AVG(t.amount) AS average_amount
FROM transactions t
WHERE t.status='completed'
-- optional AND DATE(t.created_at) BETWEEN :start AND :end
GROUP BY t.transaction_type
ORDER BY total_amount DESC;
```

- Search by reference/account/description

```sql
SELECT t.*, fa.account_number AS from_account_number, ta.account_number AS to_account_number
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id   = ta.account_id
WHERE t.reference_number LIKE :q
   OR fa.account_number LIKE :q
   OR ta.account_number LIKE :q
   OR t.description LIKE :q
ORDER BY t.created_at DESC
LIMIT 50;
```


### Admin and reports

- Admin login

```sql
SELECT admin_id, username, email, password_hash, full_name, role
FROM admin_users
WHERE (username=:username OR email=:username) AND is_active=1;
```

- List users with account counts (pre-aggregate variant)

```sql
SELECT u.user_id, u.username, u.email, u.first_name, u.last_name,
       u.phone, u.registration_status, u.is_active, u.created_at,
       COALESCE(ac.account_count, 0) AS account_count
FROM users u
LEFT JOIN (
  SELECT user_id, COUNT(*) AS account_count
  FROM accounts
  GROUP BY user_id
) ac ON ac.user_id = u.user_id
-- optional WHERE u.registration_status=:status
ORDER BY u.created_at DESC
LIMIT :limit OFFSET :offset;
```

- Search users with account numbers (keeps GROUP BY on users)

```sql
SELECT u.user_id, u.username, u.email, u.first_name, u.last_name, u.phone,
       u.registration_status, u.is_active, u.created_at,
       COUNT(DISTINCT a.account_id) AS account_count,
       GROUP_CONCAT(DISTINCT a.account_number ORDER BY a.account_number SEPARATOR ', ') AS account_numbers
FROM users u
LEFT JOIN accounts a ON a.user_id = u.user_id
WHERE (
  u.username LIKE :q OR u.email LIKE :q OR u.first_name LIKE :q OR u.last_name LIKE :q OR
  CONCAT(u.first_name,' ',u.last_name) LIKE :q OR a.account_number LIKE :q
)
-- optional AND u.registration_status=:status
GROUP BY u.user_id
ORDER BY u.created_at DESC
LIMIT :limit OFFSET :offset;
```

- Dashboard stats

```sql
SELECT COUNT(*) AS total FROM users;
SELECT COUNT(*) AS total FROM users WHERE registration_status='pending';
SELECT COUNT(*) AS total FROM accounts;
SELECT COUNT(*) AS total FROM accounts WHERE status='active';
SELECT SUM(balance) AS total FROM accounts WHERE status='active';
SELECT COUNT(*) AS total FROM transactions WHERE DATE(created_at)=CURDATE();
SELECT SUM(amount) AS total FROM transactions WHERE DATE(created_at)=CURDATE() AND status='completed';
```

- Recent activities (audit logs)

```sql
SELECT al.*, u.first_name, u.last_name, au.full_name AS admin_name
FROM audit_logs al
LEFT JOIN users u ON al.user_id = u.user_id
LEFT JOIN admin_users au ON al.admin_id = au.admin_id
ORDER BY al.created_at DESC
LIMIT :limit;
```

- Transaction report (with party details)

```sql
SELECT t.*,
       fa.account_number AS from_account,
       ta.account_number AS to_account,
       fu.first_name AS from_user_first, fu.last_name AS from_user_last,
       tu.first_name AS to_user_first,   tu.last_name AS to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id   = ta.account_id
LEFT JOIN users fu ON fa.user_id = fu.user_id
LEFT JOIN users tu ON ta.user_id = tu.user_id
WHERE t.created_at BETWEEN :start_date AND :end_date
-- optional AND t.transaction_type=:type
ORDER BY t.created_at DESC;
```

- Reports page (`admin/reports.php`)

1) Transaction summary by day and type

```sql
SELECT DATE(t.created_at) AS transaction_date,
       t.transaction_type,
       COUNT(*) AS transaction_count,
       SUM(t.amount) AS total_amount,
       AVG(t.amount) AS average_amount
FROM transactions t
WHERE DATE(t.created_at) BETWEEN :start_date AND :end_date
  AND t.status='completed'
-- optional AND t.transaction_type=:type
GROUP BY DATE(t.created_at), t.transaction_type
ORDER BY transaction_date DESC, t.transaction_type;
```

2) Account summary (per account, date-filtered transactions)

```sql
SELECT u.user_id, CONCAT(u.first_name,' ',u.last_name) AS user_name, u.email,
       a.account_number, a.account_type, a.balance, a.status, a.created_at,
       COUNT(t.transaction_id) AS total_transactions,
       SUM(CASE WHEN t.transaction_type='deposit'    AND t.status='completed' THEN t.amount ELSE 0 END) AS total_deposits,
       SUM(CASE WHEN t.transaction_type='withdrawal' AND t.status='completed' THEN t.amount ELSE 0 END) AS total_withdrawals
FROM users u
JOIN accounts a ON u.user_id = a.user_id
LEFT JOIN transactions t ON (a.account_id=t.from_account_id OR a.account_id=t.to_account_id)
  AND DATE(t.created_at) BETWEEN :start_date AND :end_date
WHERE u.registration_status='approved'
GROUP BY u.user_id, a.account_id
ORDER BY a.balance DESC;
```

3) User activity (per user, date-filtered)

```sql
SELECT u.user_id, CONCAT(u.first_name,' ',u.last_name) AS user_name, u.email,
       u.registration_status, u.created_at AS registration_date,
       COUNT(DISTINCT a.account_id) AS total_accounts,
       COUNT(t.transaction_id) AS total_transactions,
       MAX(t.created_at) AS last_transaction_date,
       SUM(CASE WHEN t.transaction_type='deposit'    AND t.status='completed' THEN t.amount ELSE 0 END) AS total_deposits,
       SUM(CASE WHEN t.transaction_type='withdrawal' AND t.status='completed' THEN t.amount ELSE 0 END) AS total_withdrawals
FROM users u
LEFT JOIN accounts a ON u.user_id = a.user_id
LEFT JOIN transactions t ON (a.account_id=t.from_account_id OR a.account_id=t.to_account_id)
  AND DATE(t.created_at) BETWEEN :start_date AND :end_date
GROUP BY u.user_id
ORDER BY total_transactions DESC;
```

- Audit logs page (`admin/audit.php`)

```sql
SELECT al.*, au.full_name AS admin_name, au.role AS admin_role, u.first_name, u.last_name
FROM audit_logs al
LEFT JOIN admin_users au ON al.admin_id = au.admin_id
LEFT JOIN users u ON al.user_id = u.user_id
-- optional WHERE filters on al.action, al.admin_id, DATE(al.created_at)
ORDER BY al.created_at DESC
LIMIT :limit OFFSET :offset;

SELECT COUNT(*) AS total FROM audit_logs al -- same WHERE for pagination
```


## Simplified joins cheat-sheet

- Avoid `OR` across different foreign-key columns in hot paths; prefer `UNION ALL` of two index-friendly branches (from vs to) and then `ORDER BY` outside.
- For single-entity summaries, consider scalar subqueries instead of `LEFT JOIN + GROUP BY` to reduce row duplication and simplify logic.
- For list pages that need counts, use pre-aggregated subqueries joined back to the main table.
- Remember `from_account_id` or `to_account_id` can be NULL (deposit/withdrawal). Use `LEFT JOIN` on those sides and `JOIN` only when you know a side must exist.


## Worked example: Alice’s savings account summary

Input: `account_id = 1`

Transactions involved (from the demo seed):

| Direction  | Type      | Amount  | Note                         |
|------------|-----------|---------|------------------------------|
| incoming   | deposit   | 50000.00| Salary deposit into account 1|
| outgoing   | transfer  | 5000.00 | Transfer from 1 → 2          |
| incoming   | transfer  | 11000.00| Transfer from 45 → 1         |

Computed:
- total_transactions = 3
- total_deposits = 50,000 (only deposit-type into account 1)
- total_withdrawals = 0 (no withdrawal-type from account 1)
- last_transaction_date = most recent of the three rows


## Notes on performance
- Existing indexes (`idx_accounts_user_id`, `idx_transactions_from_account`, `idx_transactions_to_account`, `idx_transactions_date`) support the filters shown.
- On very large datasets, consider covering indexes on `(status, created_at)` for reports, and `(transaction_type, status, created_at)` for summaries.
- If search becomes slow, consider FULLTEXT indexes on `users(name/email)` and `accounts(account_number)` or a search engine.


