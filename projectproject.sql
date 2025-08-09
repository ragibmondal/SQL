-- Daffodil Banking System Database Setup
-- Run this in phpMyAdmin or MySQL command line

CREATE DATABASE IF NOT EXISTS daffodil_bank;
USE daffodil_bank;

-- Table 1: users
CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone VARCHAR(15),
    address TEXT,
    date_of_birth DATE,
    registration_status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL
);

-- Table 2: admin_users
CREATE TABLE admin_users (
    admin_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role ENUM('super_admin', 'account_manager', 'customer_service') DEFAULT 'customer_service',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table 3: accounts
CREATE TABLE accounts (
    account_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    account_number VARCHAR(20) UNIQUE NOT NULL,
    account_type ENUM('savings', 'checking', 'business') NOT NULL,
    balance DECIMAL(15,2) DEFAULT 0.00,
    status ENUM('pending', 'active', 'suspended', 'closed') DEFAULT 'pending',
    created_by_admin INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (created_by_admin) REFERENCES admin_users(admin_id)
);

-- Table 4: transactions
CREATE TABLE transactions (
    transaction_id INT PRIMARY KEY AUTO_INCREMENT,
    from_account_id INT,
    to_account_id INT,
    transaction_type ENUM('deposit', 'withdrawal', 'transfer', 'fee') NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    description TEXT,
    status ENUM('pending', 'completed', 'failed') DEFAULT 'pending',
    reference_number VARCHAR(50) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (from_account_id) REFERENCES accounts(account_id),
    FOREIGN KEY (to_account_id) REFERENCES accounts(account_id)
);

-- Table 5: account_types
CREATE TABLE account_types (
    type_id INT PRIMARY KEY AUTO_INCREMENT,
    type_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    minimum_balance DECIMAL(10,2) DEFAULT 0.00,
    monthly_fee DECIMAL(10,2) DEFAULT 0.00,
    interest_rate DECIMAL(5,4) DEFAULT 0.0000,
    withdrawal_limit DECIMAL(15,2),
    is_active BOOLEAN DEFAULT TRUE
);

-- Table 6: audit_logs
CREATE TABLE audit_logs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    admin_id INT,
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(50),
    record_id INT,
    old_values JSON,
    new_values JSON,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (admin_id) REFERENCES admin_users(admin_id)
);

-- Insert sample account types
INSERT INTO account_types (type_name, description, minimum_balance, monthly_fee, interest_rate) VALUES
('Savings', 'Basic savings account', 100.00, 5.00, 0.0250),
('Checking', 'Checking account for daily transactions', 50.00, 10.00, 0.0100),
('Business', 'Business account for companies', 1000.00, 25.00, 0.0150);

-- Insert default admin user (password: admin123)
INSERT INTO admin_users (username, email, password_hash, full_name, role) VALUES
('admin', 'admin@daffodilbank.com', '$2y$10$UlIUEO2JhhZ6vq4ldLjnWej1VLuHIOt7i50oDktfzGvrxaSlluA96', 'System Administrator', 'super_admin');

-- Create indexes for better performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_accounts_user_id ON accounts(user_id);
CREATE INDEX idx_accounts_number ON accounts(account_number);
CREATE INDEX idx_transactions_from_account ON transactions(from_account_id);
CREATE INDEX idx_transactions_to_account ON transactions(to_account_id);
CREATE INDEX idx_transactions_date ON transactions(created_at);

-- Trigger for balance updates
DELIMITER //
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
END//
DELIMITER ;

-- Stored procedure for creating accounts
DELIMITER //
CREATE PROCEDURE CreateAccount(
    IN p_user_id INT,
    IN p_account_type VARCHAR(20),
    IN p_admin_id INT,
    OUT p_account_number VARCHAR(20)
)
BEGIN
    DECLARE account_count INT;
    
    SELECT COUNT(*) INTO account_count FROM accounts WHERE user_id = p_user_id;
    
    SET p_account_number = CONCAT('DAF', LPAD(p_user_id, 6, '0'), LPAD(account_count + 1, 3, '0'));
    
    INSERT INTO accounts (user_id, account_number, account_type, created_by_admin)
    VALUES (p_user_id, p_account_number, p_account_type, p_admin_id);
END//
DELIMITER ;

-- Stored procedure for money transfer
DELIMITER //
CREATE PROCEDURE TransferMoney(
    IN p_from_account INT,
    IN p_to_account INT,
    IN p_amount DECIMAL(15,2),
    IN p_description TEXT,
    OUT p_result VARCHAR(100),
    OUT p_reference VARCHAR(50)
)
BEGIN
    DECLARE from_balance DECIMAL(15,2);
    DECLARE ref_number VARCHAR(50);
    
    SELECT balance INTO from_balance FROM accounts WHERE account_id = p_from_account;
    
    IF from_balance >= p_amount THEN
        SET ref_number = CONCAT('TXN', DATE_FORMAT(NOW(), '%Y%m%d'), LPAD(FLOOR(RAND() * 999999), 6, '0'));
        
        INSERT INTO transactions (from_account_id, to_account_id, transaction_type, amount, description, reference_number, status)
        VALUES (p_from_account, p_to_account, 'transfer', p_amount, p_description, ref_number, 'completed');
        
        SET p_result = 'SUCCESS';
        SET p_reference = ref_number;
    ELSE
        SET p_result = 'INSUFFICIENT_FUNDS';
        SET p_reference = '';
    END IF;
END//
DELIMITER ;
