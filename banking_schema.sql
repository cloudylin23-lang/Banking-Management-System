-- ============================================================
--  BANKING MANAGEMENT SYSTEM
--  Project 09 - DATCOM Lab, NEU College of Technology
--  Chay tung phan theo thu tu de tranh loi Foreign Key
-- ============================================================

DROP DATABASE IF EXISTS banking;
CREATE DATABASE banking
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE banking;

-- ============================================================
-- PHAN 1: TAO BANG
-- Thu tu: Branches -> Employees -> Customers -> Accounts -> Transactions
-- ============================================================

-- 1. Branches (khong co FK, tao truoc tien)
CREATE TABLE Branches (
    BranchID    INT             AUTO_INCREMENT PRIMARY KEY,
    BranchName  VARCHAR(100)    NOT NULL,
    Address     VARCHAR(255)    NOT NULL,
    Phone       VARCHAR(20),
    ManagerID   INT             DEFAULT NULL   -- FK -> Employees (them sau)
);

-- 2. Employees
CREATE TABLE Employees (
    EmployeeID  INT             AUTO_INCREMENT PRIMARY KEY,
    BranchID    INT             NOT NULL,
    FullName    VARCHAR(100)    NOT NULL,
    Position    ENUM('Manager','Teller','Auditor') NOT NULL DEFAULT 'Teller',
    HireDate    DATE            NOT NULL,
    Salary      DECIMAL(15,2)   NOT NULL DEFAULT 0,
    Email       VARCHAR(100)    UNIQUE,
    CONSTRAINT fk_emp_branch FOREIGN KEY (BranchID)
        REFERENCES Branches(BranchID)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Them FK ManagerID vao Branches sau khi da co bang Employees
ALTER TABLE Branches
    ADD CONSTRAINT fk_branch_manager FOREIGN KEY (ManagerID)
        REFERENCES Employees(EmployeeID)
        ON UPDATE CASCADE ON DELETE SET NULL;

-- 3. Customers
CREATE TABLE Customers (
    CustomerID  INT             AUTO_INCREMENT PRIMARY KEY,
    FullName    VARCHAR(100)    NOT NULL,
    DateOfBirth DATE,
    PhoneNumber VARCHAR(20)     NOT NULL,
    Email       VARCHAR(100),
    Address     VARCHAR(255),
    NationalID  VARCHAR(20)     NOT NULL UNIQUE,
    CreatedAt   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Accounts
CREATE TABLE Accounts (
    AccountID   INT             AUTO_INCREMENT PRIMARY KEY,
    CustomerID  INT             NOT NULL,
    BranchID    INT             NOT NULL,
    AccountType ENUM('Savings','Checking') NOT NULL DEFAULT 'Savings',
    Balance     DECIMAL(15,2)   NOT NULL DEFAULT 0,
    OpenDate    DATE            NOT NULL,
    Status      ENUM('Active','Closed') NOT NULL DEFAULT 'Active',
    CONSTRAINT fk_acc_customer FOREIGN KEY (CustomerID)
        REFERENCES Customers(CustomerID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_acc_branch FOREIGN KEY (BranchID)
        REFERENCES Branches(BranchID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_balance CHECK (Balance >= 0)
);

-- 5. Transactions
CREATE TABLE Transactions (
    TransactionID   INT             AUTO_INCREMENT PRIMARY KEY,
    AccountID       INT             NOT NULL,
    EmployeeID      INT,
    TransactionDate DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Amount          DECIMAL(15,2)   NOT NULL,
    TransactionType ENUM('Deposit','Withdrawal','Transfer') NOT NULL,
    Description     VARCHAR(255),
    BalanceAfter    DECIMAL(15,2)   NOT NULL,
    CONSTRAINT fk_txn_account FOREIGN KEY (AccountID)
        REFERENCES Accounts(AccountID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_txn_employee FOREIGN KEY (EmployeeID)
        REFERENCES Employees(EmployeeID)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_amount CHECK (Amount > 0)
);

-- Bang log giao dich dang nghi (dung cho Trigger)
CREATE TABLE SuspiciousLog (
    LogID           INT         AUTO_INCREMENT PRIMARY KEY,
    TransactionID   INT,
    FlaggedAt       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Reason          VARCHAR(255),
    CONSTRAINT fk_log_txn FOREIGN KEY (TransactionID)
        REFERENCES Transactions(TransactionID)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- ============================================================
-- PHAN 2: DU LIEU MAU
-- ============================================================

-- Branches (chua co ManagerID, se cap nhat sau)
INSERT INTO Branches (BranchName, Address, Phone) VALUES
('Chi nhanh Ha Noi',        '123 Dinh Tien Hoang, Hoan Kiem, Ha Noi',   '024-3825-1001'),
('Chi nhanh Ho Chi Minh',   '456 Nguyen Hue, Quan 1, TP.HCM',          '028-3822-2002'),
('Chi nhanh Da Nang',       '789 Tran Phu, Hai Chau, Da Nang',         '023-6382-3003'),
('Chi nhanh Can Tho',       '101 Hoa Binh, Ninh Kieu, Can Tho',        '029-2382-4004'),
('Chi nhanh Hai Phong',     '202 Tran Hung Dao, Le Chan, Hai Phong',   '022-5382-5005');

-- Employees
INSERT INTO Employees (BranchID, FullName, Position, HireDate, Salary, Email) VALUES
(1, 'Nguyen Van An',    'Manager',  '2018-03-15', 25000000, 'an.nguyen@banking.vn'),
(1, 'Tran Thi Bich',   'Teller',   '2020-06-01', 12000000, 'bich.tran@banking.vn'),
(2, 'Le Van Cuong',    'Manager',  '2017-09-20', 26000000, 'cuong.le@banking.vn'),
(2, 'Pham Thi Dung',   'Teller',   '2021-01-10', 11500000, 'dung.pham@banking.vn'),
(3, 'Hoang Van Em',    'Manager',  '2019-05-22', 24500000, 'em.hoang@banking.vn'),
(3, 'Do Thi Phuong',   'Auditor',  '2020-11-03', 15000000, 'phuong.do@banking.vn'),
(4, 'Vu Van Giang',    'Manager',  '2016-07-14', 27000000, 'giang.vu@banking.vn'),
(4, 'Ngo Thi Hoa',     'Teller',   '2022-03-28', 11000000, 'hoa.ngo@banking.vn'),
(5, 'Dang Van Hung',   'Manager',  '2015-12-01', 28000000, 'hung.dang@banking.vn'),
(5, 'Bui Thi Lan',     'Auditor',  '2019-08-17', 14500000, 'lan.bui@banking.vn');

-- Cap nhat ManagerID cho tung chi nhanh
UPDATE Branches SET ManagerID = 1  WHERE BranchID = 1;
UPDATE Branches SET ManagerID = 3  WHERE BranchID = 2;
UPDATE Branches SET ManagerID = 5  WHERE BranchID = 3;
UPDATE Branches SET ManagerID = 7  WHERE BranchID = 4;
UPDATE Branches SET ManagerID = 9  WHERE BranchID = 5;

-- Customers
INSERT INTO Customers (FullName, DateOfBirth, PhoneNumber, Email, Address, NationalID) VALUES
('Nguyen Minh Khoa',  '1990-04-12', '0901234567', 'khoa.nm@gmail.com',   '10 Le Loi, Ha Noi',          '001090012345'),
('Tran Thi Mai',      '1985-08-25', '0912345678', 'mai.tt@gmail.com',    '22 Ly Thuong Kiet, Ha Noi',  '001085023456'),
('Le Van Thanh',      '1993-02-07', '0923456789', 'thanh.lv@gmail.com',  '5 Nguyen Trai, TP.HCM',      '079093034567'),
('Pham Ngoc Lan',     '1988-11-30', '0934567890', 'lan.pn@gmail.com',    '88 Hung Vuong, Da Nang',     '048088045678'),
('Hoang Duc Manh',    '1995-06-18', '0945678901', 'manh.hd@gmail.com',   '33 Phan Chu Trinh, Can Tho', '092095056789'),
('Vu Thi Thu',        '1991-09-03', '0956789012', 'thu.vt@gmail.com',    '15 Tran Phu, Hai Phong',     '031091067890'),
('Do Quang Vinh',     '1987-03-22', '0967890123', 'vinh.dq@gmail.com',   '7 Bach Dang, Ha Noi',        '001087078901'),
('Ngo Thi Huong',     '1996-12-14', '0978901234', 'huong.nt@gmail.com',  '60 Nguyen Hue, TP.HCM',      '079096089012'),
('Bui Van Long',      '1982-07-09', '0989012345', 'long.bv@gmail.com',   '14 Tran Hung Dao, Da Nang',  '048082090123'),
('Dang Thi Hien',     '1994-01-27', '0990123456', 'hien.dt@gmail.com',   '9 Hoa Binh, Can Tho',        '092094001234');

-- Accounts
INSERT INTO Accounts (CustomerID, BranchID, AccountType, Balance, OpenDate, Status) VALUES
(1,  1, 'Savings',  45000000,  '2020-01-15', 'Active'),
(2,  1, 'Checking', 12500000,  '2019-06-20', 'Active'),
(3,  2, 'Savings',  88000000,  '2021-03-10', 'Active'),
(4,  3, 'Savings',  23000000,  '2020-09-05', 'Active'),
(5,  4, 'Checking', 5500000,   '2022-01-22', 'Active'),
(6,  5, 'Savings',  67000000,  '2018-11-30', 'Active'),
(7,  1, 'Checking', 31000000,  '2021-07-14', 'Active'),
(8,  2, 'Savings',  150000000, '2017-04-08', 'Active'),
(9,  3, 'Checking', 8200000,   '2023-02-01', 'Active'),
(10, 4, 'Savings',  42000000,  '2019-12-25', 'Active');

-- Transactions
INSERT INTO Transactions (AccountID, EmployeeID, TransactionDate, Amount, TransactionType, Description, BalanceAfter) VALUES
(1, 2,  '2024-01-05 09:15:00', 10000000, 'Deposit',    'Nap tien luong thang 1',     55000000),
(1, 2,  '2024-01-20 14:30:00', 5000000,  'Withdrawal', 'Rut tien mua sam',           50000000),
(2, 2,  '2024-02-01 10:00:00', 3000000,  'Deposit',    'Nap tien tiet kiem',         15500000),
(3, 4,  '2024-02-10 11:20:00', 20000000, 'Deposit',    'Nhan tien thuong Tet',       108000000),
(3, 4,  '2024-02-15 16:45:00', 5000000,  'Withdrawal', 'Rut tien du lich',           103000000),
(4, 6,  '2024-03-01 08:30:00', 8000000,  'Deposit',    'Luong thang 3',              31000000),
(5, 8,  '2024-03-05 13:00:00', 2000000,  'Withdrawal', 'Rut tien sinh hoat',         3500000),
(6, 10, '2024-03-10 09:45:00', 15000000, 'Deposit',    'Thu nhap kinh doanh',        82000000),
(7, 2,  '2024-04-01 10:10:00', 500000000,'Deposit',    'Chuyen tien du an lon',      531000000),
(8, 4,  '2024-04-15 14:00:00', 50000000, 'Transfer',   'Chuyen tien mua bat dong san',100000000);

-- ============================================================
-- PHAN 3: INDEXES
-- ============================================================

CREATE INDEX idx_acc_customer    ON Accounts(CustomerID);
CREATE INDEX idx_acc_branch      ON Accounts(BranchID);
CREATE INDEX idx_txn_account     ON Transactions(AccountID);
CREATE INDEX idx_txn_date        ON Transactions(TransactionDate);
CREATE INDEX idx_txn_type        ON Transactions(TransactionType);
CREATE INDEX idx_emp_branch      ON Employees(BranchID);
CREATE INDEX idx_cust_nationalid ON Customers(NationalID);

-- ============================================================
-- PHAN 4: VIEWS
-- ============================================================

-- View so du khach hang
CREATE OR REPLACE VIEW CustomerBalanceView AS
SELECT
    c.CustomerID,
    c.FullName,
    c.PhoneNumber,
    a.AccountID,
    a.AccountType,
    a.Balance,
    a.Status,
    b.BranchName
FROM Customers c
JOIN Accounts  a ON c.CustomerID = a.CustomerID
JOIN Branches  b ON a.BranchID   = b.BranchID;

-- View lich su giao dich day du
CREATE OR REPLACE VIEW TransactionHistoryView AS
SELECT
    t.TransactionID,
    c.FullName          AS CustomerName,
    a.AccountID,
    t.TransactionType,
    t.Amount,
    t.TransactionDate,
    t.BalanceAfter,
    t.Description,
    e.FullName          AS HandledBy
FROM Transactions t
JOIN Accounts   a ON t.AccountID  = a.AccountID
JOIN Customers  c ON a.CustomerID = c.CustomerID
LEFT JOIN Employees e ON t.EmployeeID = e.EmployeeID;

-- View tong hop giao dich theo ngay
CREATE OR REPLACE VIEW DailyTransactionSummary AS
SELECT
    DATE(TransactionDate)   AS TxnDate,
    TransactionType,
    COUNT(*)                AS TotalCount,
    SUM(Amount)             AS TotalAmount,
    AVG(Amount)             AS AvgAmount
FROM Transactions
GROUP BY DATE(TransactionDate), TransactionType;

-- ============================================================
-- PHAN 5: STORED PROCEDURES
-- ============================================================

DELIMITER $$

-- Nap tien
CREATE PROCEDURE sp_Deposit(
    IN  p_account_id    INT,
    IN  p_amount        DECIMAL(15,2),
    IN  p_employee_id   INT,
    IN  p_description   VARCHAR(255),
    OUT p_new_balance   DECIMAL(15,2)
)
BEGIN
    DECLARE v_status VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT Status INTO v_status FROM Accounts WHERE AccountID = p_account_id FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found';
    END IF;
    IF v_status != 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account is not active';
    END IF;
    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be greater than 0';
    END IF;

    UPDATE Accounts SET Balance = Balance + p_amount WHERE AccountID = p_account_id;
    SELECT Balance INTO p_new_balance FROM Accounts WHERE AccountID = p_account_id;

    INSERT INTO Transactions (AccountID, EmployeeID, Amount, TransactionType, Description, BalanceAfter)
    VALUES (p_account_id, p_employee_id, p_amount, 'Deposit', p_description, p_new_balance);

    COMMIT;
END$$

-- Rut tien
CREATE PROCEDURE sp_Withdraw(
    IN  p_account_id    INT,
    IN  p_amount        DECIMAL(15,2),
    IN  p_employee_id   INT,
    IN  p_description   VARCHAR(255),
    OUT p_new_balance   DECIMAL(15,2)
)
BEGIN
    DECLARE v_balance   DECIMAL(15,2);
    DECLARE v_status    VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT Balance, Status INTO v_balance, v_status
    FROM Accounts WHERE AccountID = p_account_id FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found';
    END IF;
    IF v_status != 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account is not active';
    END IF;
    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be greater than 0';
    END IF;
    IF v_balance < p_amount THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient balance';
    END IF;

    UPDATE Accounts SET Balance = Balance - p_amount WHERE AccountID = p_account_id;
    SELECT Balance INTO p_new_balance FROM Accounts WHERE AccountID = p_account_id;

    INSERT INTO Transactions (AccountID, EmployeeID, Amount, TransactionType, Description, BalanceAfter)
    VALUES (p_account_id, p_employee_id, p_amount, 'Withdrawal', p_description, p_new_balance);

    COMMIT;
END$$

-- Chuyen khoan
CREATE PROCEDURE sp_Transfer(
    IN  p_from_account  INT,
    IN  p_to_account    INT,
    IN  p_amount        DECIMAL(15,2),
    IN  p_employee_id   INT,
    IN  p_description   VARCHAR(255)
)
BEGIN
    DECLARE v_balance   DECIMAL(15,2);
    DECLARE v_status    VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT Balance, Status INTO v_balance, v_status
    FROM Accounts WHERE AccountID = p_from_account FOR UPDATE;

    IF v_status != 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Source account is not active';
    END IF;
    IF v_balance < p_amount THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient balance for transfer';
    END IF;

    UPDATE Accounts SET Balance = Balance - p_amount WHERE AccountID = p_from_account;
    UPDATE Accounts SET Balance = Balance + p_amount WHERE AccountID = p_to_account;

    INSERT INTO Transactions (AccountID, EmployeeID, Amount, TransactionType, Description, BalanceAfter)
    SELECT p_from_account, p_employee_id, p_amount, 'Transfer',
           CONCAT('Transfer to account #', p_to_account, ': ', p_description),
           Balance FROM Accounts WHERE AccountID = p_from_account;

    INSERT INTO Transactions (AccountID, EmployeeID, Amount, TransactionType, Description, BalanceAfter)
    SELECT p_to_account, p_employee_id, p_amount, 'Deposit',
           CONCAT('Received from account #', p_from_account, ': ', p_description),
           Balance FROM Accounts WHERE AccountID = p_to_account;

    COMMIT;
END$$

DELIMITER ;

-- ============================================================
-- PHAN 6: USER DEFINED FUNCTIONS
-- ============================================================

DELIMITER $$

-- Tinh lai suat don gian
CREATE FUNCTION fn_SimpleInterest(
    p_balance   DECIMAL(15,2),
    p_rate      DECIMAL(5,4),   -- lai suat nam, vi du 0.065 = 6.5%
    p_months    INT
) RETURNS DECIMAL(15,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(p_balance * p_rate * p_months / 12, 0);
END$$

-- Kiem tra so du toi thieu (500,000 VND)
CREATE FUNCTION fn_CheckMinBalance(
    p_account_id    INT,
    p_withdraw_amt  DECIMAL(15,2)
) RETURNS TINYINT(1)
READS SQL DATA
BEGIN
    DECLARE v_balance DECIMAL(15,2);
    SELECT Balance INTO v_balance FROM Accounts WHERE AccountID = p_account_id;
    IF (v_balance - p_withdraw_amt) >= 500000 THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END$$

-- Lay tong so tien giao dich cua tai khoan trong thang
CREATE FUNCTION fn_MonthlyTotal(
    p_account_id    INT,
    p_year          INT,
    p_month         INT,
    p_type          VARCHAR(20)
) RETURNS DECIMAL(15,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(15,2) DEFAULT 0;
    SELECT COALESCE(SUM(Amount), 0) INTO v_total
    FROM Transactions
    WHERE AccountID       = p_account_id
      AND YEAR(TransactionDate)  = p_year
      AND MONTH(TransactionDate) = p_month
      AND TransactionType = p_type;
    RETURN v_total;
END$$

DELIMITER ;

-- ============================================================
-- PHAN 7: TRIGGERS
-- ============================================================

DELIMITER $$

-- Canh bao giao dich lon (> 100 trieu)
CREATE TRIGGER trg_suspicious_transaction
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    IF NEW.Amount > 100000000 THEN
        INSERT INTO SuspiciousLog (TransactionID, Reason)
        VALUES (NEW.TransactionID,
                CONCAT('Large transaction: ', FORMAT(NEW.Amount, 0), ' VND'));
    END IF;
END$$

-- Tu dong cap nhat Balance sau khi them Transaction (bao ve tinh toan ven)
CREATE TRIGGER trg_log_negative_balance
BEFORE INSERT ON Transactions
FOR EACH ROW
BEGIN
    DECLARE v_balance DECIMAL(15,2);
    IF NEW.TransactionType = 'Withdrawal' THEN
        SELECT Balance INTO v_balance FROM Accounts WHERE AccountID = NEW.AccountID;
        IF v_balance < NEW.Amount THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Trigger blocked: withdrawal exceeds balance';
        END IF;
    END IF;
END$$

DELIMITER ;

-- ============================================================
-- PHAN 8: PHAN QUYEN NGUOI DUNG
-- ============================================================

-- Tao users (doi mat khau truoc khi dung thuc te)
CREATE USER IF NOT EXISTS 'bank_manager'@'localhost' IDENTIFIED BY 'Manager@2024!';
CREATE USER IF NOT EXISTS 'bank_teller'@'localhost'  IDENTIFIED BY 'Teller@2024!';
CREATE USER IF NOT EXISTS 'bank_auditor'@'localhost' IDENTIFIED BY 'Auditor@2024!';

-- Manager: toan quyen
GRANT ALL PRIVILEGES ON banking.* TO 'bank_manager'@'localhost';

-- Teller: chi duoc doc va them giao dich
GRANT SELECT ON banking.Customers       TO 'bank_teller'@'localhost';
GRANT SELECT ON banking.Accounts        TO 'bank_teller'@'localhost';
GRANT SELECT, INSERT ON banking.Transactions TO 'bank_teller'@'localhost';
GRANT EXECUTE ON PROCEDURE banking.sp_Deposit   TO 'bank_teller'@'localhost';
GRANT EXECUTE ON PROCEDURE banking.sp_Withdraw  TO 'bank_teller'@'localhost';
GRANT EXECUTE ON PROCEDURE banking.sp_Transfer  TO 'bank_teller'@'localhost';

-- Auditor: chi duoc doc tat ca
GRANT SELECT ON banking.* TO 'bank_auditor'@'localhost';

FLUSH PRIVILEGES;

-- ============================================================
-- KIEM TRA NHANH (bo comment de chay)
-- ============================================================

-- SELECT * FROM CustomerBalanceView;
-- SELECT * FROM TransactionHistoryView;
-- SELECT * FROM DailyTransactionSummary;

-- Goi stored procedure nap tien 5 trieu vao account 1:
-- CALL sp_Deposit(1, 5000000, 2, 'Test deposit', @new_bal);
-- SELECT @new_bal AS NewBalance;

-- Tinh lai suat:
-- SELECT fn_SimpleInterest(10000000, 0.065, 6) AS InterestAmount;

-- Kiem tra so du toi thieu:
-- SELECT fn_CheckMinBalance(1, 3000000) AS CanWithdraw;


SELECT * FROM Customers LIMIT 10;
SELECT * FROM Accounts LIMIT 10;
SELECT * FROM Transactions LIMIT 10;
SHOW GRANTS FOR 'bank_auditor'@'localhost';

SELECT * FROM TransactionHistoryView LIMIT 5;


SELECT fn_SimpleInterest(50000000, 0.065, 6)  AS Interest;
SELECT fn_CheckMinBalance(1, 3000000)          AS CanWithdraw;
SELECT fn_MonthlyTotal(1, 2024, 1, 'Deposit') AS TotalDeposit;
SELECT fn_MonthlyTotal(1, 2024, 1, 'Withdrawal') AS TotalWithdraw;

SELECT * FROM DailyTransactionSummary
ORDER BY TxnDate DESC
LIMIT 10;