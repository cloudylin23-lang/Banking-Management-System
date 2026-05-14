# 🏦 Banking Management System
### Project 09 — DATCOM Lab, National Economics University

![Python](https://img.shields.io/badge/Python-3.x-3776AB?style=flat&logo=python&logoColor=white)
![Flask](https://img.shields.io/badge/Flask-3.x-000000?style=flat&logo=flask&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-8.4-4479A1?style=flat&logo=mysql&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)

A comprehensive banking management system built with **MySQL 8.4** and **Python Flask**, featuring a modern web dashboard with role-based access control for bank managers, tellers, and auditors.

---

## 📋 Table of Contents

- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Database Design](#-database-design)
- [Installation](#-installation)
- [Usage](#-usage)
- [Demo Accounts](#-demo-accounts)
- [Screenshots](#-screenshots)
- [Project Structure](#-project-structure)
- [Security](#-security)

---

## ✨ Features

### Core Banking Operations
- **Customer Management** — Add, edit, search customer profiles with full pagination
- **Account Management** — Open/close accounts, real-time balance tracking, account detail panel
- **Transaction Processing** — Deposit, withdrawal, and transfer via 3-step wizard with confirmation
- **Employee Management** — Staff records, role assignments, branch management
- **Branch Administration** — Multi-branch support with KPI statistics

### Reporting & Analytics
- Interactive bar chart (7-day transaction volume)
- Balance summary donut chart
- Risk distribution dashboard
- Top performing branches table
- Savings interest projections using `fn_SimpleInterest()`
- Suspicious transaction alerts
- Full audit log with timestamps
- Export to **CSV**, **Excel (.xlsx)**, and **PDF**

### Advanced UI/UX
- 🌙 Dark mode (preference saved in localStorage)
- 🔔 Real-time notification system with sound
- ✨ Animated stat counters on Dashboard
- 💀 Skeleton loading screens
- 📈 Sparkline balance history chart in Account Detail panel
- 🖱️ Interactive chart — click bar → filter transactions by date
- ⌨️ Keyboard shortcuts: `Ctrl+K` search · `Escape` close modal · `Ctrl+P` print
- ☑️ Bulk transaction selection and export

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| Database | MySQL 8.4 |
| Backend | Python 3.x + Flask |
| DB Driver | mysql-connector-python |
| Frontend | HTML5 / CSS3 / JavaScript |
| Charts | Chart.js 4.4 |
| 3D Landing | Three.js r128 |
| PDF Export | jsPDF 2.5 |
| Excel Export | SheetJS (xlsx) |
| Icons | Font Awesome 6.4 |

---

## 🗄 Database Design

### Tables (7 total)

| Table | Description |
|---|---|
| `Branches` | Bank branch locations and manager assignments |
| `Employees` | Staff records with roles and salary |
| `Customers` | Customer profiles with AES-encrypted NationalID |
| `Accounts` | Bank accounts with AES-encrypted Balance |
| `Transactions` | All financial transactions with full audit trail |
| `SuspiciousLog` | Auto-flagged transactions > 100,000,000 VND |
| `AuditLog` | Complete system action history |

### Advanced Database Objects

```
Indexes    : 7  — optimized for account lookups and transaction history
Views      : 3  — CustomerBalanceView, TransactionHistoryView, DailyTransactionSummary
Procedures : 3  — sp_Deposit, sp_Withdraw, sp_Transfer (ACID + ROLLBACK)
Functions  : 3  — fn_SimpleInterest, fn_CheckMinBalance, fn_MonthlyTotal
Triggers   : 4  — suspicious activity detection + AES balance encryption
```

---

## ⚙️ Installation

### Prerequisites
- Python 3.8+
- MySQL 8.4
- pip

### 1. Clone the repository
```bash
git clone https://github.com/YOUR_USERNAME/banking-management-system.git
cd banking-management-system
```

### 2. Install Python dependencies
```bash
pip install flask mysql-connector-python
```

### 3. Set up the database
Open MySQL Workbench and run the SQL files in order:

```bash
# Step 1: Create schema, tables, procedures, triggers
banking_schema.sql

# Step 2: Insert 150 rows of sample data
add_150_data.sql

# Step 3: Enable AES encryption on Balance column
encrypt_v3.sql
```

### 4. Configure database connection
Open `app.py` and update the database credentials:

```python
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'YOUR_PASSWORD',   # ← change this
    'database': 'banking',
    'charset': 'utf8mb4'
}
```

### 5. Run the application
```bash
cd banking_app
python app.py
```

Open your browser and navigate to:
```
http://localhost:5000
```

---

## 🚀 Usage

### Demo Accounts

| Role | Username | Password | Access Level |
|---|---|---|---|
| **Manager** | `manager` | `Manager@2024!` | Full access — all modules |
| **Teller** | `teller` | `Teller@2024!` | Transactions + customer view |
| **Auditor** | `auditor` | `Auditor@2024!` | Read-only — all modules |

### Creating a Transaction

1. Click **New Transaction** in the sidebar
2. **Step 1** — Select type: Deposit / Withdrawal / Transfer
3. **Step 2** — Choose account, enter amount (balance shown live)
4. **Step 3** — Verify details and click **Authorize Transfer**

> ⚠️ Transactions over **100,000,000 VND** are automatically flagged by a database trigger and logged to `SuspiciousLog` with a real-time notification.

### Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl + K` | Open global search |
| `Escape` | Close any open modal |
| `Ctrl + P` | Print current page (clean layout) |

---

## 📸 Screenshots

| Landing Page | Dashboard |
|---|---|
| *(Insert screenshot)* | *(Insert screenshot)* |

| Customer Management | Account Management |
|---|---|
| *(Insert screenshot)* | *(Insert screenshot)* |

| New Transaction | Reports & Analytics |
|---|---|
| *(Insert screenshot)* | *(Insert screenshot)* |

> 📁 All screenshots available in `/screenshots` folder

---

## 📁 Project Structure

```
banking-management-system/
│
├── banking_app/
│   ├── app.py                  # Flask backend — all API endpoints
│   └── templates/
│       └── banking_ui.html     # Single-page frontend application
│
├── banking_schema.sql          # Full database schema with all objects
├── add_150_data.sql            # 150 rows sample data per table
├── encrypt_v3.sql              # AES encryption setup for Balance column
├── backup_auto.bat             # Windows automated backup script
└── README.md
```

---

## 🔐 Security

### Authentication & Authorization
- Session-based login with Flask server-side sessions
- Three MySQL user accounts with granular `GRANT` permissions
- Web UI adapts dynamically to logged-in user role

### Data Encryption
- **NationalID** — AES-256 encrypted at rest using `AES_ENCRYPT()`
- **Balance** — AES-encrypted copy maintained in `Balance_Encrypted` column
- BEFORE INSERT / UPDATE triggers keep encrypted column synchronized automatically

### Automated Backup
- `backup_auto.bat` runs `mysqldump` with `--single-transaction --routines --triggers`
- Scheduled via **Windows Task Scheduler** — daily at 23:00
- 7-day retention policy with automatic cleanup
- Backup log written to `C:\backup\banking\backup_log.txt`

---

## 📄 API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/login` | Authenticate user |
| POST | `/api/logout` | End session |
| GET | `/api/dashboard` | Dashboard statistics |
| GET/POST | `/api/customers` | List / add customers |
| PUT | `/api/customers/<id>` | Update customer |
| GET/POST | `/api/accounts` | List / open accounts |
| PUT | `/api/accounts/<id>/close` | Close account |
| GET/POST | `/api/transactions` | List / create transactions |
| GET | `/api/employees` | List employees |
| GET | `/api/branches` | List branches |
| GET | `/api/reports` | Full analytics report |
| GET | `/api/audit-log` | System audit trail |
| GET | `/api/search` | Global search |

---

## 👥 Team

| Name | Student ID | Role |
|---|---|---|
| [Your Name] | [Student ID] | Developer |

**Instructor:** MSc. Hung Tran · hung.tran@neu.edu.vn
**Institution:** National Economics University — DATCOM Lab

---

## 📚 References

- [MySQL 8.4 Documentation](https://dev.mysql.com/doc/refman/8.4/en/)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [mysql-connector-python Guide](https://dev.mysql.com/doc/connector-python/en/)
- [Chart.js Documentation](https://www.chartjs.org/)
- [Three.js Documentation](https://threejs.org/)

---

## 📹 Demo

▶️ [Watch full demo on YouTube](https://youtu.be/e2ybr-8e7bU)

---

*National Economics University · DATCOM Lab · 2025*
