USE banking;

SET SQL_SAFE_UPDATES = 0;

-- Kiem tra cot da ton tai chua, neu chua thi moi them
SET @col_exists = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'banking'
    AND TABLE_NAME = 'Accounts'
    AND COLUMN_NAME = 'Balance_Encrypted'
);

SET @sql = IF(@col_exists = 0,
    'ALTER TABLE Accounts ADD COLUMN Balance_Encrypted VARBINARY(255) DEFAULT NULL AFTER Balance',
    'SELECT ''Cot Balance_Encrypted da ton tai, bo qua buoc nay'' AS ThongBao'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Ma hoa tat ca du lieu
UPDATE Accounts
SET Balance_Encrypted = AES_ENCRYPT(Balance, 'NEU_BANK_SECRET_KEY_2024');

SET SQL_SAFE_UPDATES = 1;

-- Kiem tra 5 dong dau
SELECT
    AccountID,
    Balance AS Balance_Goc,
    CAST(AES_DECRYPT(Balance_Encrypted, 'NEU_BANK_SECRET_KEY_2024') AS DECIMAL(15,2)) AS Balance_Giai_Ma,
    (Balance = CAST(AES_DECRYPT(Balance_Encrypted, 'NEU_BANK_SECRET_KEY_2024') AS DECIMAL(15,2))) AS Khop
FROM Accounts LIMIT 5;

-- Tao View
CREATE OR REPLACE VIEW vw_AccountBalance AS
SELECT
    AccountID, CustomerID, BranchID, AccountType,
    CAST(AES_DECRYPT(Balance_Encrypted, 'NEU_BANK_SECRET_KEY_2024') AS DECIMAL(15,2)) AS Balance,
    OpenDate, Status
FROM Accounts;

-- Tao Trigger
DROP TRIGGER IF EXISTS trg_encrypt_balance_insert;
DROP TRIGGER IF EXISTS trg_encrypt_balance_update;

DELIMITER $$
CREATE TRIGGER trg_encrypt_balance_insert
BEFORE INSERT ON Accounts FOR EACH ROW
BEGIN
    SET NEW.Balance_Encrypted = AES_ENCRYPT(NEW.Balance, 'NEU_BANK_SECRET_KEY_2024');
END$$

CREATE TRIGGER trg_encrypt_balance_update
BEFORE UPDATE ON Accounts FOR EACH ROW
BEGIN
    SET NEW.Balance_Encrypted = AES_ENCRYPT(NEW.Balance, 'NEU_BANK_SECRET_KEY_2024');
END$$
DELIMITER ;

SELECT 'HOAN TAT MA HOA BALANCE!' AS KetQua;