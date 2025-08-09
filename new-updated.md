## SQL Reference — Daffodil Banking System (Auto-synced with current codebase)

This reference enumerates the SQL statements actually used in the current PHP codebase and the schema/routines defined under `database/`. It is organized by domain with concise context and purpose. All application queries use prepared statements unless explicitly noted.

- User Management
- Account Management
- Transaction Management
- Admin/Dashboard/Reports
- Audit & Logging
- Stored Routines, Triggers, Indexes
- Schema Overview

---

## User Management

### 1) Register user
File: `classes/User.php`

```sql
INSERT INTO users 
SET username=:username, email=:email, password_hash=:password_hash, 
    first_name=:first_name, last_name=:last_name, phone=:phone, 
    address=:address, date_of_birth=:date_of_birth
```
Purpose: Create a new user (status defaults to 'pending').

### 2) Login (by username or email) + active check
File: `classes/User.php`

```sql
SELECT user_id, username, email, password_hash, first_name, last_name, 
       registration_status, is_active 
FROM users 
WHERE (username = :username OR email = :username) 
  AND is_active = 1
```
Purpose: Authenticate, then verify password in PHP.

### 3) Check username/email exists
File: `classes/User.php`

```sql
SELECT user_id FROM users WHERE username = :username OR email = :email
```
Purpose: Prevent duplicates on registration.

### 4) Get user by id
File: `classes/User.php`

```sql
SELECT * FROM users WHERE user_id = :user_id
```
Purpose: Fetch full profile for display/edit.

### 5) Update user profile (basic)
File: `classes/User.php`

```sql
UPDATE users 
SET first_name=:first_name, last_name=:last_name, phone=:phone, 
    address=:address, date_of_birth=:date_of_birth 
WHERE user_id=:user_id
```
Purpose: Edit profile fields.

### 6) Verify current password
File: `classes/User.php`

```sql
SELECT password_hash FROM users WHERE user_id = :user_id
```
Purpose: Validate before password change.

### 7) Change password (inline flow)
File: `classes/User.php`

```sql
UPDATE users SET password_hash=:password_hash WHERE user_id=:user_id
```
Purpose: Persist new password hash after verification.

### 8) Pending users (admin list)
File: `classes/User.php`

```sql
SELECT user_id, username, email, first_name, last_name, phone, 
       date_of_birth, created_at 
FROM users 
WHERE registration_status = 'pending' 
ORDER BY created_at DESC
```
Purpose: Admin approval queue.

### 9) Approve/Reject registration (User class)
File: `classes/User.php`

```sql
UPDATE users SET registration_status=:status WHERE user_id=:user_id
```
Purpose: Admin status update + audit log.

### 10) Deactivate user (soft delete)
File: `classes/User.php`

```sql
UPDATE users SET is_active = 0 WHERE user_id = :user_id
```
Purpose: Non-destructive disable.

### 11) Hard delete user (guarded)
File: `classes/User.php`

```sql
-- Check active accounts
SELECT COUNT(*) as count FROM accounts WHERE user_id = :user_id AND status IN ('active','pending');

-- Check any transaction history
SELECT COUNT(*) as count 
FROM transactions t 
JOIN accounts a ON (t.from_account_id = a.account_id OR t.to_account_id = a.account_id) 
WHERE a.user_id = :user_id;

-- Delete dependent accounts
DELETE FROM accounts WHERE user_id = :user_id;

-- Delete user
DELETE FROM users WHERE user_id = :user_id;
```
Purpose: Only allow when no active accounts, balance, or tx history; performed inside a transaction and audited.

### 12) Can delete (advisory)
File: `classes/User.php`

```sql
SELECT COUNT(*) as count FROM accounts WHERE user_id = :user_id AND status IN ('active','pending');
SELECT SUM(balance) as total_balance FROM accounts WHERE user_id = :user_id AND status='active';
SELECT COUNT(*) as count 
FROM transactions t 
JOIN accounts a ON (t.from_account_id = a.account_id OR t.to_account_id = a.account_id) 
WHERE a.user_id = :user_id;
```
Purpose: Compute safe deletion and warnings.

### 13) Update profile (enhanced variant)
File: `classes/User.php`

```sql
UPDATE users 
SET first_name = :first_name, last_name = :last_name, phone = :phone, 
    date_of_birth = :date_of_birth, address = :address, updated_at = NOW() 
WHERE user_id = :user_id
```
Purpose: With `updated_at` stamping.

### 14) Update last login
File: `classes/User.php`

```sql
UPDATE users SET last_login = NOW() WHERE user_id = :user_id
```
Purpose: Track last login.

---

## Account Management

### 15) Create account (stored proc)
File: `classes/Account.php`

```sql
CALL CreateAccount(:user_id, :account_type, :admin_id, @account_number);
SELECT @account_number as account_number;
```
Purpose: Allocate account number and insert account via procedure. Audited.

### 16) Get account by id (with user)
File: `classes/Account.php`

```sql
SELECT a.*, u.first_name, u.last_name, u.email, u.phone
FROM accounts a
JOIN users u ON a.user_id = u.user_id
WHERE a.account_id = :account_id
```
Purpose: Detail view/context.

### 17) Get account by number
File: `classes/Account.php`

```sql
SELECT a.*, u.first_name, u.last_name, u.email, u.phone
FROM accounts a
JOIN users u ON a.user_id = u.user_id
WHERE a.account_number = :account_number
```
Purpose: Lookup by external identifier.

### 18) List user accounts
File: `classes/Account.php`

```sql
SELECT * FROM accounts WHERE user_id = :user_id ORDER BY created_at DESC
```
Purpose: User’s accounts list.

### 19) Admin list accounts (basic)
File: `classes/Account.php`

```sql
SELECT a.*, u.first_name, u.last_name, u.email, u.username,
       au.full_name as created_by_name
FROM accounts a
JOIN users u ON a.user_id = u.user_id
LEFT JOIN admin_users au ON a.created_by_admin = au.admin_id
-- Optional filter
-- WHERE a.status = :status
ORDER BY a.created_at DESC
LIMIT :limit OFFSET :offset
```
Purpose: Admin grid with optional status filter and pagination.

### 20) Admin list accounts with search
File: `classes/Account.php`

```sql
SELECT a.*, u.first_name, u.last_name, u.email, u.username,
       au.full_name as created_by_name
FROM accounts a
JOIN users u ON a.user_id = u.user_id
LEFT JOIN admin_users au ON a.created_by_admin = au.admin_id
WHERE 1=1
  -- Optional status
  -- AND a.status = :status
  AND (
    a.account_number LIKE :search OR
    u.first_name    LIKE :search OR
    u.last_name     LIKE :search OR
    u.email         LIKE :search OR
    u.username      LIKE :search OR
    a.account_type  LIKE :search OR
    CONCAT(u.first_name,' ',u.last_name) LIKE :search
  )
ORDER BY a.created_at DESC
LIMIT :limit OFFSET :offset
```
Purpose: Filtered admin grid.

### 21) Update account status
File: `classes/Account.php`

```sql
UPDATE accounts SET status = :status WHERE account_id = :account_id
```
Purpose: Activate/Suspend/Close; audited.

### 22) Get balance
File: `classes/Account.php`

```sql
SELECT balance FROM accounts WHERE account_id = :account_id
```
Purpose: Balance reads for guards/UI.

### 23) Manual balance adjustment (admin)
File: `classes/Account.php`

```sql
-- Update new balance
UPDATE accounts SET balance = :balance WHERE account_id = :account_id;

-- Create compensating transaction
INSERT INTO transactions 
  (from_account_id, to_account_id, transaction_type, amount, description, reference_number, status)
VALUES 
  (:from_account, :to_account, :type, :amount, :description, :reference, 'completed');
```
Purpose: Pinned inside a DB transaction; audited.

### 24) Account summary with stats
File: `classes/Account.php`

```sql
SELECT 
  a.*, u.first_name, u.last_name, u.email,
  COUNT(t.transaction_id) as total_transactions,
  SUM(CASE WHEN t.transaction_type='deposit' AND t.status='completed' THEN t.amount ELSE 0 END) as total_deposits,
  SUM(CASE WHEN t.transaction_type='withdrawal' AND t.status='completed' THEN t.amount ELSE 0 END) as total_withdrawals,
  MAX(t.created_at) as last_transaction_date
FROM accounts a
JOIN users u ON a.user_id = u.user_id
LEFT JOIN transactions t ON (a.account_id = t.from_account_id OR a.account_id = t.to_account_id)
WHERE a.account_id = :account_id
GROUP BY a.account_id
```
Purpose: Rich header/summary.

### 25) Search accounts (quick)
File: `classes/Account.php`

```sql
SELECT a.*, u.first_name, u.last_name, u.email
FROM accounts a
JOIN users u ON a.user_id = u.user_id
WHERE a.account_number LIKE :search 
   OR u.first_name LIKE :search 
   OR u.last_name  LIKE :search 
   OR u.email      LIKE :search
ORDER BY a.created_at DESC
LIMIT 20
```
Purpose: Lightweight search.

### 26) Soft delete account (close)
File: `classes/Account.php`

```sql
UPDATE accounts SET status='closed' WHERE account_id=:account_id
```
Purpose: Non-destructive closure; audited. Guard: requires zero balance.

### 27) Hard delete account (guarded)
File: `classes/Account.php`

```sql
-- Check history
SELECT COUNT(*) as count 
FROM transactions 
WHERE from_account_id = :account_id OR to_account_id = :account_id;

-- Delete account
DELETE FROM accounts WHERE account_id = :account_id;
```
Purpose: Only when zero balance and no history; done in a transaction; audited.

### 28) Admin page: Account types
File: `admin/accounts.php`

```sql
SELECT * FROM account_types WHERE is_active = 1
```
Purpose: Populate create-account dialog.

---

## Transaction Management

### 29) Stored-proc transfer
File: `classes/Transaction.php`

```sql
CALL TransferMoney(:from_account, :to_account, :amount, :description, @result, @reference);
SELECT @result as result, @reference as reference;
```
Purpose: Atomic transfer using server-side logic.

### 30) Manual deposit (admin)
File: `classes/Transaction.php`

```sql
INSERT INTO transactions 
  (to_account_id, transaction_type, amount, description, reference_number, status)
VALUES 
  (:account_id, 'deposit', :amount, :description, :reference, 'completed')
```
Purpose: Credit account and let trigger update balance.

### 31) Manual withdrawal (admin)
File: `classes/Transaction.php`

```sql
-- Guard
SELECT balance FROM accounts WHERE account_id = :account_id;

-- Insert
INSERT INTO transactions 
  (from_account_id, transaction_type, amount, description, reference_number, status)
VALUES 
  (:account_id, 'withdrawal', :amount, :description, :reference, 'completed')
```
Purpose: Debit account post sufficient-funds check.

### 32) Get transaction by id (joined context)
File: `classes/Transaction.php`

```sql
SELECT t*, 
       fa.account_number as from_account_number,
       ta.account_number as to_account_number,
       fu.first_name as from_user_first,
       fu.last_name  as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name  as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id   = ta.account_id
LEFT JOIN users   fu ON fa.user_id         = fu.user_id
LEFT JOIN users   tu ON ta.user_id         = tu.user_id
WHERE t.transaction_id = :transaction_id
```
Purpose: Detail with human-friendly context.

### 33) Get transaction by reference
File: `classes/Transaction.php`

```sql
SELECT t*, 
       fa.account_number as from_account_number,
       ta.account_number as to_account_number,
       fu.first_name as from_user_first,
       fu.last_name  as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name  as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id   = ta.account_id
LEFT JOIN users   fu ON fa.user_id         = fu.user_id
LEFT JOIN users   tu ON ta.user_id         = tu.user_id
WHERE t.reference_number = :reference
```
Purpose: Lookup by external reference.

### 34) Get account transactions (paged)
File: `classes/Transaction.php`

```sql
SELECT t*,
       CASE 
         WHEN t.from_account_id = :account_id THEN 'outgoing'
         WHEN t.to_account_id   = :account_id THEN 'incoming'
         ELSE 'unknown'
       END as direction,
       fa.account_number as from_account_number,
       ta.account_number as to_account_number,
       fu.first_name as from_user_first,
       fu.last_name  as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name  as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id   = ta.account_id
LEFT JOIN users   fu ON fa.user_id         = fu.user_id
LEFT JOIN users   tu ON ta.user_id         = tu.user_id
WHERE (t.from_account_id = :account_id OR t.to_account_id = :account_id)
  AND t.status = 'completed'
ORDER BY t.created_at DESC
LIMIT :limit OFFSET :offset
```
Purpose: Account statement view.

### 35) Get user transactions (filters supported)
File: `classes/Transaction.php`

```sql
SELECT t*,
       CASE WHEN fa.user_id = :user_id THEN 'outgoing'
            WHEN ta.user_id = :user_id THEN 'incoming'
            ELSE 'unknown' END as direction,
       CASE WHEN fa.user_id = :user_id THEN fa.account_number
            WHEN ta.user_id = :user_id THEN ta.account_number
            ELSE COALESCE(fa.account_number, ta.account_number) END as account_number,
       CASE WHEN fa.user_id = :user_id THEN fa.account_type
            WHEN ta.user_id = :user_id THEN ta.account_type
            ELSE COALESCE(fa.account_type, ta.account_type) END as account_type,
       fa.account_number as from_account_number,
       ta.account_number as to_account_number,
       fu.first_name as from_user_first,
       fu.last_name  as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name  as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id   = ta.account_id
LEFT JOIN users   fu ON fa.user_id         = fu.user_id
LEFT JOIN users   tu ON ta.user_id         = tu.user_id
WHERE (fa.user_id = :user_id OR ta.user_id = :user_id)
  AND t.status = 'completed'
-- Optional filters: account, type, date_from, date_to
ORDER BY t.created_at DESC
LIMIT :limit OFFSET :offset
```
Purpose: User-wide history with filters for account, type, date.

### 36) Admin list transactions (filters)
File: `classes/Transaction.php`

```sql
SELECT t*,
       fa.account_number as from_account_number,
       ta.account_number as to_account_number,
       fu.first_name as from_user_first,
       fu.last_name  as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name  as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id   = ta.account_id
LEFT JOIN users   fu ON fa.user_id         = fu.user_id
LEFT JOIN users   tu ON ta.user_id         = tu.user_id
-- Optional filters
-- WHERE t.status = :status AND t.transaction_type = :type
ORDER BY t.created_at DESC
LIMIT :limit OFFSET :offset
```
Purpose: Admin transaction grid.

### 37) Transaction statistics (optionally date-bounded)
File: `classes/Transaction.php`

```sql
SELECT 
  t.transaction_type,
  COUNT(*)     as count,
  SUM(t.amount) as total_amount,
  AVG(t.amount) as average_amount
FROM transactions t
WHERE t.status = 'completed'
  -- Optional date range
  -- AND DATE(t.created_at) BETWEEN :start_date AND :end_date
GROUP BY t.transaction_type
ORDER BY total_amount DESC
```
Purpose: Analytics widgets.

### 38) Search transactions (reference/number/description)
File: `classes/Transaction.php`

```sql
SELECT t*,
       fa.account_number as from_account_number,
       ta.account_number as to_account_number,
       fu.first_name as from_user_first,
       fu.last_name  as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name  as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id   = ta.account_id
LEFT JOIN users   fu ON fa.user_id         = fu.user_id
LEFT JOIN users   tu ON ta.user_id         = tu.user_id
WHERE t.reference_number LIKE :search 
   OR fa.account_number  LIKE :search 
   OR ta.account_number  LIKE :search
   OR t.description      LIKE :search
ORDER BY t.created_at DESC
LIMIT 50
```
Purpose: Admin quick search.

### 39) Count user transactions (for pagination)
File: `classes/Transaction.php`

```sql
SELECT COUNT(DISTINCT t.transaction_id) as count
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id   = ta.account_id
WHERE (fa.user_id = :user_id OR ta.user_id = :user_id)
-- Optional filters: account, type, date_from, date_to
```
Purpose: Total rows for paging.

### 40) User transaction summary (credit/debit totals)
File: `classes/Transaction.php`

```sql
SELECT 
  COUNT(DISTINCT t.transaction_id) as total_count,
  SUM(CASE WHEN ta.user_id = :user_id AND fa.user_id != :user_id THEN t.amount ELSE 0 END) as total_credit,
  SUM(CASE WHEN fa.user_id = :user_id AND ta.user_id != :user_id THEN t.amount 
           WHEN fa.user_id = :user_id AND t.transaction_type IN ('withdrawal') THEN t.amount 
           ELSE 0 END) as total_debit
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id   = ta.account_id
WHERE (fa.user_id = :user_id OR ta.user_id = :user_id)
  AND t.status = 'completed'
-- Optional filters: account, date_from, date_to
```
Purpose: Summary banner for user history.

---

## Admin, Dashboard, Reports

### 41) Admin login
File: `classes/Admin.php`

```sql
SELECT admin_id, username, email, password_hash, full_name, role 
FROM admin_users 
WHERE (username = :username OR email = :username) 
  AND is_active = 1
```
Purpose: Authenticate admin.

### 42) Get admin by id
File: `classes/Admin.php`

```sql
SELECT * FROM admin_users WHERE admin_id = :admin_id
```
Purpose: Load profile info.

### 43) Admin list users (+counts) with optional status and pagination
File: `classes/Admin.php`

```sql
SELECT u.user_id, u.username, u.email, u.first_name, u.last_name, 
       u.phone, u.registration_status, u.is_active, u.created_at,
       COUNT(a.account_id) as account_count
FROM users u
LEFT JOIN accounts a ON u.user_id = a.user_id
-- Optional status
-- WHERE registration_status = :status
GROUP BY u.user_id
ORDER BY u.created_at DESC
LIMIT :limit OFFSET :offset
```
Purpose: Admin users grid.

### 44) Count users (optional status)
File: `classes/Admin.php`

```sql
SELECT COUNT(*) as total FROM users
-- Optional
-- WHERE registration_status = :status
```
Purpose: Pagination/statistics.

### 45) Update user status (Admin class)
File: `classes/Admin.php`

```sql
UPDATE users SET registration_status=:status WHERE user_id=:user_id
```
Purpose: Approve/Reject; audited.

### 46) Toggle activation (Admin class)
File: `classes/Admin.php`

```sql
UPDATE users SET is_active=:is_active WHERE user_id=:user_id
```
Purpose: Activate/Deactivate; audited.

### 47) Dashboard stats
File: `classes/Admin.php`

```sql
SELECT COUNT(*) as total FROM users;
SELECT COUNT(*) as total FROM users WHERE registration_status = 'pending';
SELECT COUNT(*) as total FROM accounts;
SELECT COUNT(*) as total FROM accounts WHERE status = 'active';
SELECT SUM(balance) as total FROM accounts WHERE status = 'active';
SELECT COUNT(*) as total FROM transactions WHERE DATE(created_at) = CURDATE();
SELECT SUM(amount) as total FROM transactions WHERE DATE(created_at) = CURDATE() AND status = 'completed';
```
Purpose: Dashboard KPIs.

### 48) Recent activities (dashboard)
File: `classes/Admin.php`

```sql
SELECT al.*, u.first_name, u.last_name, au.full_name as admin_name
FROM audit_logs al
LEFT JOIN users u ON al.user_id = u.user_id
LEFT JOIN admin_users au ON al.admin_id = au.admin_id
ORDER BY al.created_at DESC
LIMIT :limit
```
Purpose: Activity feed.

### 49) Transaction report (date range + optional type)
File: `classes/Admin.php`

```sql
SELECT t*, 
       fa.account_number as from_account,
       ta.account_number as to_account,
       fu.first_name as from_user_first,
       fu.last_name  as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name  as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id   = ta.account_id
LEFT JOIN users   fu ON fa.user_id         = fu.user_id
LEFT JOIN users   tu ON ta.user_id         = tu.user_id
WHERE t.created_at BETWEEN :start_date AND :end_date
-- Optional type
-- AND t.transaction_type = :type
ORDER BY t.created_at DESC
```
Purpose: Reports page backend.

### 50) Reports page — Transaction Summary
File: `admin/reports.php`

```sql
SELECT 
  DATE(t.created_at) as transaction_date,
  t.transaction_type,
  COUNT(*)  as transaction_count,
  SUM(t.amount) as total_amount,
  AVG(t.amount) as average_amount
FROM transactions t
WHERE DATE(t.created_at) BETWEEN :start_date AND :end_date
  AND t.status = 'completed'
-- Optional type
-- AND t.transaction_type = :transaction_type
GROUP BY DATE(t.created_at), t.transaction_type
ORDER BY transaction_date DESC, t.transaction_type
```
Purpose: Daily summary table.

### 51) Reports page — Account Summary
File: `admin/reports.php`

```sql
SELECT 
  u.user_id,
  CONCAT(u.first_name,' ',u.last_name) as user_name,
  u.email,
  a.account_number,
  a.account_type,
  a.balance,
  a.status,
  a.created_at,
  COUNT(t.transaction_id) as total_transactions,
  SUM(CASE WHEN t.transaction_type='deposit'   AND t.status='completed' THEN t.amount ELSE 0 END) as total_deposits,
  SUM(CASE WHEN t.transaction_type='withdrawal' AND t.status='completed' THEN t.amount ELSE 0 END) as total_withdrawals
FROM users u
JOIN accounts a ON u.user_id = a.user_id
LEFT JOIN transactions t ON (a.account_id = t.from_account_id OR a.account_id = t.to_account_id)
  AND DATE(t.created_at) BETWEEN :start_date AND :end_date
WHERE u.registration_status = 'approved'
GROUP BY u.user_id, a.account_id
ORDER BY a.balance DESC
```
Purpose: Balance and activity per account.

### 52) Reports page — User Activity
File: `admin/reports.php`

```sql
SELECT 
  u.user_id,
  CONCAT(u.first_name,' ',u.last_name) as user_name,
  u.email,
  u.registration_status,
  u.created_at as registration_date,
  COUNT(DISTINCT a.account_id) as total_accounts,
  COUNT(t.transaction_id) as total_transactions,
  MAX(t.created_at) as last_transaction_date,
  SUM(CASE WHEN t.transaction_type='deposit'   AND t.status='completed' THEN t.amount ELSE 0 END) as total_deposits,
  SUM(CASE WHEN t.transaction_type='withdrawal' AND t.status='completed' THEN t.amount ELSE 0 END) as total_withdrawals
FROM users u
LEFT JOIN accounts a ON u.user_id = a.user_id
LEFT JOIN transactions t ON (a.account_id = t.from_account_id OR a.account_id = t.to_account_id)
  AND DATE(t.created_at) BETWEEN :start_date AND :end_date
GROUP BY u.user_id
ORDER BY total_transactions DESC
```
Purpose: Engagement overview.

### 53) Audit page — Fetch audit logs (with filters)
File: `admin/audit.php`

```sql
SELECT al*, 
       au.full_name as admin_name, 
       au.role      as admin_role,
       u.first_name, 
       u.last_name
FROM audit_logs al
LEFT JOIN admin_users au ON al.admin_id = au.admin_id
LEFT JOIN users u ON al.user_id = u.user_id
-- Optional filters: action, admin_id, DATE(created_at)
ORDER BY al.created_at DESC
LIMIT :limit OFFSET :offset;

-- Count
SELECT COUNT(*) as total FROM audit_logs al -- [same filters]
```
Purpose: Review trail with pagination.

### 54) Audit page — Admin list for filters
File: `admin/audit.php`

```sql
SELECT admin_id, full_name FROM admin_users WHERE is_active = 1 ORDER BY full_name
```
Purpose: Populate admin filter.

---

## Audit Logging (in-code writers)

### 55) Insert audit log
Files: `classes/User.php`, `classes/Admin.php`, `classes/Account.php`, `classes/Transaction.php`

```sql
INSERT INTO audit_logs (admin_id, action, table_name, record_id, new_values, ip_address) 
VALUES (:admin_id, :action, :table_name, :record_id, :new_values, :ip_address)
```
Purpose: Uniform audit trail for privileged actions.

---

## Stored Routines, Triggers, Indexes (from `database/setup.sql` / `reset_database.sql`)

### Trigger: update_account_balance_after_transaction
Scope: AFTER INSERT ON `transactions` when `NEW.status='completed'`
Effect: Adjust balances for deposit/withdrawal/transfer accordingly.

### Procedure: CreateAccount(p_user_id, p_account_type, p_admin_id, OUT p_account_number)
Logic: Generate `DAF{user}{seq}` number and insert into `accounts` (status defaults to 'pending').

### Procedure: TransferMoney(p_from_account, p_to_account, p_amount, p_description, OUT p_result, OUT p_reference)
Logic: Check funds; if sufficient, insert completed transfer with generated reference; balances adjusted by trigger.

### Indexes (partial list)
- users: `idx_users_email(email)`, `idx_users_username(username)`
- accounts: `idx_accounts_user_id(user_id)`, `idx_accounts_number(account_number)`
- transactions: `idx_transactions_from_account(from_account_id)`, `idx_transactions_to_account(to_account_id)`, `idx_transactions_date(created_at)`

---

## Schema Overview

Tables
- `users`(user_id, username, email, password_hash, first_name, last_name, phone, address, date_of_birth, registration_status, is_active, created_at, updated_at, last_login)
- `admin_users`(admin_id, username, email, password_hash, full_name, role, is_active, created_at)
- `accounts`(account_id, user_id, account_number, account_type, balance, status, created_by_admin, created_at, updated_at)
- `transactions`(transaction_id, from_account_id, to_account_id, transaction_type, amount, description, status, reference_number, created_at)
- `account_types`(type_id, type_name, description, minimum_balance, monthly_fee, interest_rate, withdrawal_limit, is_active)
- `audit_logs`(log_id, user_id, admin_id, action, table_name, record_id, old_values, new_values, ip_address, created_at)

---

## Security & Consistency Notes
- All dynamic values are bound parameters; no string interpolation.
- Mutations that require invariants use database transactions in PHP where needed (e.g., user/account hard deletes, manual balance adjustments).
- Balance changes are centralized via an AFTER INSERT trigger on `transactions`.
- Audit logging is enforced for privileged operations in classes.

---

## Quick Setup (from SQL scripts)
1. Initialize schema
   - Run `database/setup.sql` (or `database/reset_database.sql` for a clean rebuild)
2. Load demo data (optional)
   - Run `database/demo_data.sql`
3. App connection
   - Configure credentials in `config/database.php` (`Database::getConnection()`)


