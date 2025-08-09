# SQL Queries Documentation - Daffodil Banking System

This document contains all SQL queries used in the PHP codebase of the Daffodil Banking System, organized by functionality with detailed explanations.

## Table of Contents
1. [User Management Queries](#user-management-queries)
2. [Account Management Queries](#account-management-queries)
3. [Transaction Management Queries](#transaction-management-queries)
4. [Admin Management Queries](#admin-management-queries)
5. [Audit & Logging Queries](#audit--logging-queries)
6. [Report Generation Queries](#report-generation-queries)
7. [Stored Procedure Calls](#stored-procedure-calls)

---

## User Management Queries

### 1. User Registration
**File:** `classes/User.php` - Line 27
```sql
INSERT INTO users 
SET username=:username, email=:email, password_hash=:password_hash, 
    first_name=:first_name, last_name=:last_name, phone=:phone, 
    address=:address, date_of_birth=:date_of_birth
```
**Purpose:** Creates a new user account with all required information. Sets default registration status as 'pending'.

### 2. User Login Authentication
**File:** `classes/User.php` - Line 60
```sql
SELECT user_id, username, email, password_hash, first_name, last_name, 
       registration_status, is_active 
FROM users 
WHERE (username = :username OR email = :username) 
  AND is_active = 1
```
**Purpose:** Authenticates user login by checking username/email and verifying the user is active.

### 3. Check User Existence
**File:** `classes/User.php` - Line 94
```sql
SELECT user_id FROM users 
WHERE username = :username OR email = :email
```
**Purpose:** Prevents duplicate usernames and email addresses during registration.

### 4. Get User by ID
**File:** `classes/User.php` - Line 107
```sql
SELECT * FROM users WHERE user_id = :user_id
```
**Purpose:** Retrieves complete user information for profile display and management.

### 5. Update User Profile
**File:** `classes/User.php` - Line 135
```sql
UPDATE users 
SET first_name=:first_name, last_name=:last_name, phone=:phone, 
    address=:address, date_of_birth=:date_of_birth 
WHERE user_id=:user_id
```
**Purpose:** Allows users to update their personal information.

### 6. User Password Verification
**File:** `classes/User.php` - Line 162
```sql
SELECT password_hash FROM users WHERE user_id = :user_id
```
**Purpose:** Retrieves current password hash for verification before allowing password change.

### 7. Update User Password
**File:** `classes/User.php` - Line 171
```sql
UPDATE users SET password_hash=:password_hash WHERE user_id=:user_id
```
**Purpose:** Updates user password after successful verification of current password.

### 8. Get Pending Users (Admin)
**File:** `classes/User.php` - Line 185
```sql
SELECT user_id, username, email, first_name, last_name, phone, 
       date_of_birth, created_at 
FROM users 
WHERE registration_status = 'pending' 
ORDER BY created_at DESC
```
**Purpose:** Lists all users awaiting admin approval for registration.

### 9. Update Registration Status (Admin)
**File:** `classes/User.php` - Line 199
```sql
UPDATE users 
SET registration_status=:status 
WHERE user_id=:user_id
```
**Purpose:** Allows admin to approve or reject user registrations.

### 10. Soft Delete User (Deactivate)
**File:** `classes/User.php` - Line 234
```sql
UPDATE users SET is_active = 0 WHERE user_id = :user_id
```
**Purpose:** Deactivates a user account without permanently deleting data.

### 11. Hard Delete User
**File:** `classes/User.php` - Line 291
```sql
DELETE FROM users WHERE user_id = :user_id
```
**Purpose:** Permanently removes user record (only if no active accounts or transactions exist).

### 12. User Deletion Safety Checks
**File:** `classes/User.php` - Line 259, 272, 316, 323, 330
```sql
-- Check for active accounts
SELECT COUNT(*) as count FROM accounts 
WHERE user_id = :user_id AND status IN ('active', 'pending')

-- Check for transaction history
SELECT COUNT(*) as count FROM transactions t 
JOIN accounts a ON (t.from_account_id = a.account_id OR t.to_account_id = a.account_id) 
WHERE a.user_id = :user_id

-- Check total balance
SELECT SUM(balance) as total_balance FROM accounts 
WHERE user_id = :user_id AND status = 'active'
```
**Purpose:** Ensures data integrity before allowing user deletion by checking for dependencies.

### 13. Update Last Login
**File:** `classes/User.php` - Line 383
```sql
UPDATE users SET last_login = NOW() WHERE user_id = :user_id
```
**Purpose:** Records timestamp of user's last login for security and analytics.

### 14. Update User Profile (Enhanced)
**File:** `classes/User.php` - Line 354
```sql
UPDATE users SET first_name = :first_name, last_name = :last_name, 
phone = :phone, date_of_birth = :date_of_birth, address = :address, updated_at = NOW() 
WHERE user_id = :user_id
```
**Purpose:** Updates user profile with timestamp tracking.

---

## Account Management Queries

### 15. Get Account by ID with User Info
**File:** `classes/Account.php` - Line 52
```sql
SELECT a.*, u.first_name, u.last_name, u.email, u.phone
FROM accounts a
JOIN users u ON a.user_id = u.user_id
WHERE a.account_id = :account_id
```
**Purpose:** Retrieves complete account information including user details.

### 16. Get Account by Account Number
**File:** `classes/Account.php` - Line 79
```sql
SELECT a.*, u.first_name, u.last_name, u.email, u.phone
FROM accounts a
JOIN users u ON a.user_id = u.user_id
WHERE a.account_number = :account_number
```
**Purpose:** Finds account using account number for transfers and lookups.

### 17. Get User's Accounts
**File:** `classes/Account.php` - Line 93
```sql
SELECT * FROM accounts 
WHERE user_id = :user_id 
ORDER BY created_at DESC
```
**Purpose:** Lists all accounts belonging to a specific user.

### 18. Get All Accounts (Admin View)
**File:** `classes/Account.php` - Line 113
```sql
SELECT a.*, u.first_name, u.last_name, u.email, u.username,
       au.full_name as created_by_name
FROM accounts a
JOIN users u ON a.user_id = u.user_id
LEFT JOIN admin_users au ON a.created_by_admin = au.admin_id
WHERE a.status = :status (optional)
ORDER BY a.created_at DESC
LIMIT :limit OFFSET :offset
```
**Purpose:** Provides paginated list of all accounts with user and admin information for management.

### 19. Update Account Status
**File:** `classes/Account.php` - Line 136
```sql
UPDATE accounts 
SET status = :status 
WHERE account_id = :account_id
```
**Purpose:** Changes account status (active, suspended, closed, etc.).

### 20. Get Account Balance
**File:** `classes/Account.php` - Line 155
```sql
SELECT balance FROM accounts WHERE account_id = :account_id
```
**Purpose:** Retrieves current balance for an account.

### 21. Update Account Balance (Manual Adjustment)
**File:** `classes/Account.php` - Line 174
```sql
UPDATE accounts 
SET balance = :balance 
WHERE account_id = :account_id
```
**Purpose:** Allows admin to manually adjust account balance.

### 22. Account Summary with Statistics
**File:** `classes/Account.php` - Line 231
```sql
SELECT 
  a.*,
  u.first_name,
  u.last_name,
  u.email,
  COUNT(t.transaction_id) as total_transactions,
  SUM(CASE WHEN t.transaction_type = 'deposit' AND t.status = 'completed' THEN t.amount ELSE 0 END) as total_deposits,
  SUM(CASE WHEN t.transaction_type = 'withdrawal' AND t.status = 'completed' THEN t.amount ELSE 0 END) as total_withdrawals,
  MAX(t.created_at) as last_transaction_date
FROM accounts a
JOIN users u ON a.user_id = u.user_id
LEFT JOIN transactions t ON (a.account_id = t.from_account_id OR a.account_id = t.to_account_id)
WHERE a.account_id = :account_id
GROUP BY a.account_id
```
**Purpose:** Provides comprehensive account statistics including transaction summary.

### 23. Search Accounts
**File:** `classes/Account.php` - Line 255
```sql
SELECT a.*, u.first_name, u.last_name, u.email
FROM accounts a
JOIN users u ON a.user_id = u.user_id
WHERE a.account_number LIKE :search 
   OR u.first_name LIKE :search 
   OR u.last_name LIKE :search 
   OR u.email LIKE :search
ORDER BY a.created_at DESC
LIMIT 20
```
**Purpose:** Allows searching accounts by account number or user information.

### 24. Account Deletion Safety Check
**File:** `classes/Account.php` - Line 312, 356
```sql
-- Check transaction history
SELECT COUNT(*) as count FROM transactions 
WHERE from_account_id = :account_id OR to_account_id = :account_id
```
**Purpose:** Ensures account can be safely deleted by checking for transaction history.

### 25. Close Account (Soft Delete)
**File:** `classes/Account.php` - Line 281
```sql
UPDATE accounts SET status = 'closed' WHERE account_id = :account_id
```
**Purpose:** Closes an account without deleting the record.

### 26. Delete Account (Hard Delete)
**File:** `classes/Account.php` - Line 325
```sql
DELETE FROM accounts WHERE account_id = :account_id
```
**Purpose:** Permanently removes account record (only if no balance or transaction history).

### 27. Get Account Types
**File:** `admin/accounts.php` - Line 105
```sql
SELECT * FROM account_types WHERE is_active = 1
```
**Purpose:** Retrieves available account types for account creation.

---

## Transaction Management Queries

### 28. Manual Deposit
**File:** `classes/Transaction.php` - Line 55
```sql
INSERT INTO transactions 
(to_account_id, transaction_type, amount, description, reference_number, status)
VALUES (:account_id, 'deposit', :amount, :description, :reference, 'completed')
```
**Purpose:** Records a deposit transaction to an account.

### 29. Balance Check for Withdrawal
**File:** `classes/Transaction.php` - Line 100
```sql
SELECT balance FROM accounts WHERE account_id = :account_id
```
**Purpose:** Verifies sufficient funds before processing withdrawal.

### 30. Manual Withdrawal
**File:** `classes/Transaction.php` - Line 116
```sql
INSERT INTO transactions 
(from_account_id, transaction_type, amount, description, reference_number, status)
VALUES (:account_id, 'withdrawal', :amount, :description, :reference, 'completed')
```
**Purpose:** Records a withdrawal transaction from an account.

### 31. Get Transaction by ID
**File:** `classes/Transaction.php` - Line 159
```sql
SELECT t.*, 
       fa.account_number as from_account_number,
       ta.account_number as to_account_number,
       fu.first_name as from_user_first,
       fu.last_name as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id = ta.account_id
LEFT JOIN users fu ON fa.user_id = fu.user_id
LEFT JOIN users tu ON ta.user_id = tu.user_id
WHERE t.transaction_id = :transaction_id
```
**Purpose:** Retrieves complete transaction details with user and account information.

### 32. Get Transaction by Reference
**File:** `classes/Transaction.php` - Line 182
```sql
SELECT t.*, 
       fa.account_number as from_account_number,
       ta.account_number as to_account_number,
       fu.first_name as from_user_first,
       fu.last_name as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id = ta.account_id
LEFT JOIN users fu ON fa.user_id = fu.user_id
LEFT JOIN users tu ON ta.user_id = tu.user_id
WHERE t.reference_number = :reference
```
**Purpose:** Finds transaction using reference number for tracking and verification.

### 33. Get Account Transactions
**File:** `classes/Transaction.php` - Line 207
```sql
SELECT t.*, 
       CASE 
         WHEN t.from_account_id = :account_id THEN 'outgoing'
         WHEN t.to_account_id = :account_id THEN 'incoming'
         ELSE 'unknown'
       END as direction,
       fa.account_number as from_account_number,
       ta.account_number as to_account_number,
       fu.first_name as from_user_first,
       fu.last_name as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id = ta.account_id
LEFT JOIN users fu ON fa.user_id = fu.user_id
LEFT JOIN users tu ON ta.user_id = tu.user_id
WHERE (t.from_account_id = :account_id OR t.to_account_id = :account_id)
  AND t.status = 'completed'
ORDER BY t.created_at DESC
LIMIT :limit OFFSET :offset
```
**Purpose:** Lists all transactions for a specific account with pagination and direction indication.

### 34. Get User Transactions (All Accounts)
**File:** `classes/Transaction.php` - Line 242
```sql
SELECT t.*, 
       CASE 
         WHEN fa.user_id = :user_id THEN 'outgoing'
         WHEN ta.user_id = :user_id THEN 'incoming'
         ELSE 'unknown'
       END as direction,
       CASE 
         WHEN fa.user_id = :user_id THEN fa.account_number
         WHEN ta.user_id = :user_id THEN ta.account_number
         ELSE COALESCE(fa.account_number, ta.account_number)
       END as account_number,
       fa.account_number as from_account_number,
       ta.account_number as to_account_number,
       fu.first_name as from_user_first,
       fu.last_name as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id = ta.account_id
LEFT JOIN users fu ON fa.user_id = fu.user_id
LEFT JOIN users tu ON ta.user_id = tu.user_id
WHERE (fa.user_id = :user_id OR ta.user_id = :user_id)
  AND t.status = 'completed'
ORDER BY t.created_at DESC 
LIMIT :limit OFFSET :offset
```
**Purpose:** Lists all transactions across all accounts for a specific user with filters.

### 35. Get All Transactions (Admin View)
**File:** `classes/Transaction.php` - Line 324
```sql
SELECT t.*, 
       fa.account_number as from_account_number,
       ta.account_number as to_account_number,
       fu.first_name as from_user_first,
       fu.last_name as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id = ta.account_id
LEFT JOIN users fu ON fa.user_id = fu.user_id
LEFT JOIN users tu ON ta.user_id = tu.user_id
WHERE t.status = :status (optional)
  AND t.transaction_type = :type (optional)
ORDER BY t.created_at DESC
LIMIT :limit OFFSET :offset
```
**Purpose:** Provides admin view of all transactions with filtering options.

### 36. Transaction Statistics
**File:** `classes/Transaction.php` - Line 362
```sql
SELECT 
  t.transaction_type,
  COUNT(*) as count,
  SUM(t.amount) as total_amount,
  AVG(t.amount) as average_amount
FROM transactions t
WHERE t.status = 'completed'
  AND DATE(t.created_at) BETWEEN :start_date AND :end_date (optional)
GROUP BY t.transaction_type
ORDER BY total_amount DESC
```
**Purpose:** Generates transaction statistics by type for analytics.

### 37. Search Transactions
**File:** `classes/Transaction.php` - Line 385
```sql
SELECT t.*, 
       fa.account_number as from_account_number,
       ta.account_number as to_account_number,
       fu.first_name as from_user_first,
       fu.last_name as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id = ta.account_id
LEFT JOIN users fu ON fa.user_id = fu.user_id
LEFT JOIN users tu ON ta.user_id = tu.user_id
WHERE t.reference_number LIKE :search 
   OR fa.account_number LIKE :search 
   OR ta.account_number LIKE :search
   OR t.description LIKE :search
ORDER BY t.created_at DESC
LIMIT 50
```
**Purpose:** Searches transactions by reference number, account number, or description.

### 38. User Transaction Count (for Pagination)
**File:** `classes/Transaction.php` - Line 415
```sql
SELECT COUNT(DISTINCT t.transaction_id) as count
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id = ta.account_id
WHERE (fa.user_id = :user_id OR ta.user_id = :user_id)
```
**Purpose:** Counts total transactions for a user to calculate pagination.

### 39. User Transaction Summary
**File:** `classes/Transaction.php` - Line 455
```sql
SELECT 
  COUNT(DISTINCT t.transaction_id) as total_count,
  SUM(CASE WHEN ta.user_id = :user_id AND fa.user_id != :user_id THEN t.amount ELSE 0 END) as total_credit,
  SUM(CASE WHEN fa.user_id = :user_id AND ta.user_id != :user_id THEN t.amount 
           WHEN fa.user_id = :user_id AND t.transaction_type IN ('withdrawal') THEN t.amount 
           ELSE 0 END) as total_debit
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id = ta.account_id
WHERE (fa.user_id = :user_id OR ta.user_id = :user_id)
  AND t.status = 'completed'
```
**Purpose:** Calculates credit and debit totals for a user's transaction summary.

---

## Admin Management Queries

### 40. Admin Login
**File:** `classes/Admin.php` - Line 20
```sql
SELECT admin_id, username, email, password_hash, full_name, role 
FROM admin_users 
WHERE (username = :username OR email = :username) 
  AND is_active = 1
```
**Purpose:** Authenticates admin login and retrieves admin information.

### 41. Get Admin by ID
**File:** `classes/Admin.php` - Line 50
```sql
SELECT * FROM admin_users WHERE admin_id = :admin_id
```
**Purpose:** Retrieves admin information by ID.

### 42. Get All Users (Admin View)
**File:** `classes/Admin.php` - Line 79
```sql
SELECT u.user_id, u.username, u.email, u.first_name, u.last_name, 
       u.phone, u.registration_status, u.is_active, u.created_at,
       COUNT(a.account_id) as account_count
FROM users u
LEFT JOIN accounts a ON u.user_id = a.user_id
WHERE registration_status = :status (optional)
GROUP BY u.user_id
ORDER BY u.created_at DESC
LIMIT :limit OFFSET :offset
```
**Purpose:** Lists all users with account counts for admin management.

### 43. Get User Count
**File:** `classes/Admin.php` - Line 108
```sql
SELECT COUNT(*) as total FROM users 
WHERE registration_status = :status (optional)
```
**Purpose:** Counts users for pagination and statistics.

### 44. Update User Status (Admin)
**File:** `classes/Admin.php` - Line 122
```sql
UPDATE users SET registration_status=:status WHERE user_id=:user_id
```
**Purpose:** Allows admin to approve/reject user registrations.

### 45. Toggle User Activation
**File:** `classes/Admin.php` - Line 137
```sql
UPDATE users SET is_active=:is_active WHERE user_id=:user_id
```
**Purpose:** Activates or deactivates user accounts.

### 46. Dashboard Statistics - Total Users
**File:** `classes/Admin.php` - Line 156
```sql
SELECT COUNT(*) as total FROM users
```
**Purpose:** Counts total registered users for dashboard.

### 47. Dashboard Statistics - Pending Users
**File:** `classes/Admin.php` - Line 162
```sql
SELECT COUNT(*) as total FROM users WHERE registration_status = 'pending'
```
**Purpose:** Counts users awaiting approval for dashboard.

### 48. Dashboard Statistics - Total Accounts
**File:** `classes/Admin.php` - Line 168
```sql
SELECT COUNT(*) as total FROM accounts
```
**Purpose:** Counts total accounts for dashboard.

### 49. Dashboard Statistics - Active Accounts
**File:** `classes/Admin.php` - Line 174
```sql
SELECT COUNT(*) as total FROM accounts WHERE status = 'active'
```
**Purpose:** Counts active accounts for dashboard.

### 50. Dashboard Statistics - Total Balance
**File:** `classes/Admin.php` - Line 180
```sql
SELECT SUM(balance) as total FROM accounts WHERE status = 'active'
```
**Purpose:** Calculates total system balance for dashboard.

### 51. Dashboard Statistics - Today's Transactions
**File:** `classes/Admin.php` - Line 186
```sql
SELECT COUNT(*) as total FROM transactions WHERE DATE(created_at) = CURDATE()
```
**Purpose:** Counts today's transactions for dashboard.

### 52. Dashboard Statistics - Today's Transaction Amount
**File:** `classes/Admin.php` - Line 192
```sql
SELECT SUM(amount) as total FROM transactions 
WHERE DATE(created_at) = CURDATE() AND status = 'completed'
```
**Purpose:** Calculates today's total transaction amount for dashboard.

### 53. Get Recent Activities
**File:** `classes/Admin.php` - Line 203
```sql
SELECT al.*, u.first_name, u.last_name, au.full_name as admin_name
FROM audit_logs al
LEFT JOIN users u ON al.user_id = u.user_id
LEFT JOIN admin_users au ON al.admin_id = au.admin_id
ORDER BY al.created_at DESC
LIMIT :limit
```
**Purpose:** Shows recent system activities for dashboard.

### 54. Transaction Report
**File:** `classes/Admin.php` - Line 225
```sql
SELECT t.*, 
       fa.account_number as from_account,
       ta.account_number as to_account,
       fu.first_name as from_user_first,
       fu.last_name as from_user_last,
       tu.first_name as to_user_first,
       tu.last_name as to_user_last
FROM transactions t
LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
LEFT JOIN accounts ta ON t.to_account_id = ta.account_id
LEFT JOIN users fu ON fa.user_id = fu.user_id
LEFT JOIN users tu ON ta.user_id = tu.user_id
WHERE t.created_at BETWEEN :start_date AND :end_date
  AND t.transaction_type = :type (optional)
ORDER BY t.created_at DESC
```
**Purpose:** Generates transaction reports for specified date ranges.

---

## Audit & Logging Queries

### 55. Log Admin Actions
**File:** Multiple classes - Line varies
```sql
INSERT INTO audit_logs (admin_id, action, table_name, record_id, new_values, ip_address) 
VALUES (:admin_id, :action, :table_name, :record_id, :new_values, :ip_address)
```
**Purpose:** Records all admin actions for audit trail and compliance.

### 56. Get Audit Logs
**File:** `admin/audit.php` - Line 50
```sql
SELECT al.*, 
       au.full_name as admin_name, 
       au.role as admin_role,
       u.first_name, 
       u.last_name
FROM audit_logs al
LEFT JOIN admin_users au ON al.admin_id = au.admin_id
LEFT JOIN users u ON al.user_id = u.user_id
WHERE al.action = :action (optional)
  AND al.admin_id = :admin_id (optional)
  AND DATE(al.created_at) = :date (optional)
ORDER BY al.created_at DESC
LIMIT :limit OFFSET :offset
```
**Purpose:** Retrieves audit logs with filtering for admin review.

### 57. Count Audit Logs
**File:** `admin/audit.php` - Line 75
```sql
SELECT COUNT(*) as total FROM audit_logs al 
WHERE conditions (optional)
```
**Purpose:** Counts audit logs for pagination.

### 58. Get Admin List for Filters
**File:** `admin/audit.php` - Line 94
```sql
SELECT admin_id, full_name FROM admin_users 
WHERE is_active = 1 ORDER BY full_name
```
**Purpose:** Provides list of admins for audit log filtering.

---

## Report Generation Queries

### 59. Transaction Summary Report
**File:** `admin/reports.php` - Line 33
```sql
SELECT 
  DATE(t.created_at) as transaction_date,
  t.transaction_type,
  COUNT(*) as transaction_count,
  SUM(t.amount) as total_amount,
  AVG(t.amount) as average_amount
FROM transactions t
WHERE DATE(t.created_at) BETWEEN :start_date AND :end_date
  AND t.status = 'completed'
  AND t.transaction_type = :transaction_type (optional)
GROUP BY DATE(t.created_at), t.transaction_type
ORDER BY transaction_date DESC, t.transaction_type
```
**Purpose:** Generates daily transaction summary reports by type.

### 60. Account Summary Report
**File:** `admin/reports.php` - Line 63
```sql
SELECT 
  u.user_id,
  CONCAT(u.first_name, ' ', u.last_name) as user_name,
  u.email,
  a.account_number,
  a.account_type,
  a.balance,
  a.status,
  a.created_at,
  COUNT(t.transaction_id) as total_transactions,
  SUM(CASE WHEN t.transaction_type = 'deposit' AND t.status = 'completed' THEN t.amount ELSE 0 END) as total_deposits,
  SUM(CASE WHEN t.transaction_type = 'withdrawal' AND t.status = 'completed' THEN t.amount ELSE 0 END) as total_withdrawals
FROM users u
JOIN accounts a ON u.user_id = a.user_id
LEFT JOIN transactions t ON (a.account_id = t.from_account_id OR a.account_id = t.to_account_id)
  AND DATE(t.created_at) BETWEEN :start_date AND :end_date
WHERE u.registration_status = 'approved'
GROUP BY u.user_id, a.account_id
ORDER BY a.balance DESC
```
**Purpose:** Generates comprehensive account summary with transaction statistics.

### 61. User Activity Report
**File:** `admin/reports.php` - Line 91
```sql
SELECT 
  u.user_id,
  CONCAT(u.first_name, ' ', u.last_name) as user_name,
  u.email,
  u.registration_status,
  u.created_at as registration_date,
  COUNT(DISTINCT a.account_id) as total_accounts,
  COUNT(t.transaction_id) as total_transactions,
  MAX(t.created_at) as last_transaction_date,
  SUM(CASE WHEN t.transaction_type = 'deposit' AND t.status = 'completed' THEN t.amount ELSE 0 END) as total_deposits,
  SUM(CASE WHEN t.transaction_type = 'withdrawal' AND t.status = 'completed' THEN t.amount ELSE 0 END) as total_withdrawals
FROM users u
LEFT JOIN accounts a ON u.user_id = a.user_id
LEFT JOIN transactions t ON (a.account_id = t.from_account_id OR a.account_id = t.to_account_id)
  AND DATE(t.created_at) BETWEEN :start_date AND :end_date
GROUP BY u.user_id
ORDER BY total_transactions DESC
```
**Purpose:** Generates user activity reports showing engagement and transaction patterns.

---

## Stored Procedure Calls

### 62. Create Account Procedure
**File:** `classes/Account.php` - Line 23
```sql
CALL CreateAccount(:user_id, :account_type, :admin_id, @account_number)
```
**Purpose:** Creates a new account using stored procedure that handles account number generation.

### 63. Get Generated Account Number
**File:** `classes/Account.php` - Line 31
```sql
SELECT @account_number as account_number
```
**Purpose:** Retrieves the account number generated by the CreateAccount stored procedure.

### 64. Transfer Money Procedure
**File:** `classes/Transaction.php` - Line 24
```sql
CALL TransferMoney(:from_account, :to_account, :amount, :description, @result, @reference)
```
**Purpose:** Transfers money between accounts using stored procedure for atomicity.

### 65. Get Transfer Result
**File:** `classes/Transaction.php` - Line 33
```sql
SELECT @result as result, @reference as reference
```
**Purpose:** Retrieves result and reference number from the TransferMoney stored procedure.

---

## Balance Adjustment Transactions

### 66. Manual Balance Adjustment Transaction Record
**File:** `classes/Account.php` - Line 188
```sql
INSERT INTO transactions 
(from_account_id, to_account_id, transaction_type, amount, description, 
 reference_number, status)
VALUES 
(:from_account, :to_account, :type, :amount, :description, :reference, 'completed')
```
**Purpose:** Records balance adjustments made by admin as transaction records for audit trail.

---

## Summary

This banking system uses **66 distinct SQL queries** across various functionalities:

- **User Management**: 14 queries for registration, login, profile management, and user administration
- **Account Management**: 13 queries for account creation, management, and status updates
- **Transaction Management**: 15 queries for deposits, withdrawals, transfers, and transaction history
- **Admin Management**: 15 queries for admin operations, dashboard statistics, and system monitoring
- **Audit & Logging**: 4 queries for maintaining audit trails and compliance
- **Report Generation**: 3 queries for generating various business reports
- **Stored Procedures**: 4 calls to stored procedures for complex operations
- **Balance Adjustments**: 1 query for manual balance adjustments
- **Utility Queries**: 1 query for retrieving account types

The queries are designed with security in mind, using prepared statements with parameter binding to prevent SQL injection attacks. They also implement proper JOIN operations to maintain data integrity and provide comprehensive information across related tables.

All queries follow best practices including:
- Parameterized queries for security
- Proper indexing considerations
- Transaction management for data consistency
- Audit logging for compliance
- Pagination for performance
- Data validation and constraint checking
