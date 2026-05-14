from flask import Flask, render_template, request, session, jsonify
import mysql.connector
from mysql.connector import Error
from functools import wraps
from datetime import datetime, date
import decimal, json, hashlib

app = Flask(__name__)
app.secret_key = 'banking_secret_2024'

DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '08122006anhthuDN@@$$',  # <-- doi thanh password MySQL cua ban
    'database': 'banking',
    'charset': 'utf8mb4'
}

USERS = {
    'manager': {'password': 'Manager@2024!', 'role': 'Manager', 'name': 'Nguyen Van An'},
    'teller':  {'password': 'Teller@2024!',  'role': 'Teller',  'name': 'Tran Thi Bich'},
    'auditor': {'password': 'Auditor@2024!', 'role': 'Auditor', 'name': 'Do Thi Phuong'},
}

def get_db():
    try:
        return mysql.connector.connect(**DB_CONFIG)
    except Error as e:
        print(f"[DB ERROR] {e}")
        return None

def login_required(f):
    @wraps(f)
    def d(*a, **k):
        if 'user' not in session: return jsonify({'error':'Unauthorized'}), 401
        return f(*a, **k)
    return d

def manager_required(f):
    @wraps(f)
    def d(*a, **k):
        if 'user' not in session: return jsonify({'error':'Unauthorized'}), 401
        if session.get('role') != 'Manager': return jsonify({'error':'Permission denied'}), 403
        return f(*a, **k)
    return d

def sf(v, d=0.0):
    try: return float(v) if v is not None else d
    except: return d
def si(v, d=0):
    try: return int(v) if v is not None else d
    except: return d

class CustomEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal): return float(o)
        if isinstance(o, (datetime, date)): return str(o)
        return super().default(o)
app.json_encoder = CustomEncoder

def log_action(action, detail=''):
    try:
        conn = get_db()
        if not conn: return
        cur = conn.cursor()
        cur.execute("INSERT INTO AuditLog (Username, Role, Action, Detail, LogTime) VALUES (%s,%s,%s,%s,NOW())",
                    (session.get('user','system'), session.get('role',''), action, detail))
        conn.commit()
        conn.close()
    except: pass

@app.route('/')
def index():
    return render_template('banking_ui.html')

# ─── AUTH ───
@app.route('/api/login', methods=['POST'])
def api_login():
    data = request.get_json()
    u = data.get('username','').strip()
    p = data.get('password','')
    if u in USERS and USERS[u]['password'] == p:
        session['user'] = u
        session['role'] = USERS[u]['role']
        session['name'] = USERS[u]['name']
        log_action('LOGIN', f'User {u} logged in')
        return jsonify({'ok':True,'role':USERS[u]['role'],'name':USERS[u]['name']})
    return jsonify({'ok':False,'error':'Sai tên đăng nhập hoặc mật khẩu!'})

@app.route('/api/logout', methods=['POST'])
def api_logout():
    log_action('LOGOUT', f'User {session.get("user","")} logged out')
    session.clear()
    return jsonify({'ok':True})

@app.route('/api/change-password', methods=['POST'])
@login_required
def api_change_password():
    data = request.get_json()
    u = session['user']
    old_p = data.get('old_password','')
    new_p = data.get('new_password','')
    if USERS[u]['password'] != old_p:
        return jsonify({'error':'Mật khẩu cũ không đúng!'})
    if len(new_p) < 6:
        return jsonify({'error':'Mật khẩu mới phải có ít nhất 6 ký tự!'})
    USERS[u]['password'] = new_p
    log_action('CHANGE_PASSWORD', f'User {u} changed password')
    return jsonify({'ok':True})

# ─── AUDIT LOG ───
@app.route('/api/audit-log')
@login_required
def api_audit_log():
    conn = get_db()
    if not conn: return jsonify([])
    try:
        cur = conn.cursor(dictionary=True)
        page = si(request.args.get('page',1))
        per = 20
        offset = (page-1)*per
        cur.execute("SELECT COUNT(*) AS total FROM AuditLog")
        total = si(cur.fetchone()['total'])
        cur.execute("SELECT * FROM AuditLog ORDER BY LogTime DESC LIMIT %s OFFSET %s", (per, offset))
        rows = cur.fetchall()
        return jsonify({'data':[{'id':r['LogID'],'user':r['Username'],'role':r['Role'],
                                  'action':r['Action'],'detail':r['Detail'],
                                  'time':str(r['LogTime'])} for r in rows],
                        'total':total,'page':page,'per':per})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

# ─── GLOBAL SEARCH ───
@app.route('/api/search')
@login_required
def api_search():
    q = request.args.get('q','').strip()
    if len(q) < 2: return jsonify({'customers':[],'accounts':[],'transactions':[]})
    conn = get_db()
    if not conn: return jsonify({'customers':[],'accounts':[],'transactions':[]})
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""SELECT CustomerID AS id, FullName AS name, PhoneNumber AS phone, NationalID AS nid
                       FROM Customers WHERE FullName LIKE %s OR PhoneNumber LIKE %s OR NationalID LIKE %s LIMIT 5""",
                    (f'%{q}%',f'%{q}%',f'%{q}%'))
        customers = cur.fetchall()
        cur.execute("""SELECT a.AccountID AS id, c.FullName AS cname, a.Balance AS balance, a.Status AS status
                       FROM Accounts a JOIN Customers c ON a.CustomerID=c.CustomerID
                       WHERE a.AccountID LIKE %s OR c.FullName LIKE %s LIMIT 5""",
                    (f'%{q}%',f'%{q}%'))
        accounts = [{'id':r['id'],'cname':r['cname'],'balance':sf(r['balance']),'status':r['status']} for r in cur.fetchall()]
        cur.execute("""SELECT t.TransactionID AS id, c.FullName AS cname, t.TransactionType AS type, t.Amount AS amount
                       FROM Transactions t JOIN Accounts a ON t.AccountID=a.AccountID
                       JOIN Customers c ON a.CustomerID=c.CustomerID
                       WHERE t.TransactionID LIKE %s OR c.FullName LIKE %s LIMIT 5""",
                    (f'%{q}%',f'%{q}%'))
        transactions = [{'id':r['id'],'cname':r['cname'],'type':r['type'],'amount':sf(r['amount'])} for r in cur.fetchall()]
        return jsonify({'customers':customers,'accounts':accounts,'transactions':transactions})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

# ─── DASHBOARD ───
@app.route('/api/dashboard')
@login_required
def api_dashboard():
    conn = get_db()
    if not conn: return jsonify({'error':'DB connection failed'}), 500
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT COUNT(*) AS v FROM Customers"); customers=si(cur.fetchone()['v'])
        cur.execute("SELECT COUNT(*) AS v FROM Accounts WHERE Status='Active'"); accounts=si(cur.fetchone()['v'])
        cur.execute("SELECT COALESCE(SUM(Balance),0) AS v FROM Accounts WHERE Status='Active'"); total_balance=sf(cur.fetchone()['v'])
        cur.execute("SELECT COUNT(*) AS v FROM Transactions WHERE DATE(TransactionDate)=CURDATE()"); today_txn=si(cur.fetchone()['v'])
        cur.execute("SELECT COUNT(*) AS v FROM Employees"); employees=si(cur.fetchone()['v'])
        cur.execute("SELECT COUNT(*) AS v FROM Branches"); branches=si(cur.fetchone()['v'])
        cur.execute("""SELECT TransactionType, COUNT(*) AS cnt, COALESCE(SUM(Amount),0) AS total
                       FROM Transactions GROUP BY TransactionType""")
        txn_summary=[{'type':r['TransactionType'],'cnt':si(r['cnt']),'total':sf(r['total'])} for r in cur.fetchall()]
        cur.execute("""SELECT t.TransactionID AS id, c.FullName AS cname, t.TransactionType AS type,
                              t.Amount AS amount, t.TransactionDate AS date
                       FROM Transactions t JOIN Accounts a ON t.AccountID=a.AccountID
                       JOIN Customers c ON a.CustomerID=c.CustomerID
                       ORDER BY t.TransactionDate DESC LIMIT 5""")
        recent=[{'id':r['id'],'cname':r['cname'],'type':r['type'],'amount':sf(r['amount']),'date':str(r['date'])} for r in cur.fetchall()]
        cur.execute("SELECT COUNT(*) AS v FROM SuspiciousLog WHERE DATE(FlaggedAt)>=DATE_SUB(CURDATE(),INTERVAL 7 DAY)")
        alerts=si(cur.fetchone()['v'])
        cur.execute("""SELECT DATE(TransactionDate) AS d, COALESCE(SUM(Amount),0) AS total
                       FROM Transactions WHERE DATE(TransactionDate)>=DATE_SUB(CURDATE(),INTERVAL 7 DAY)
                       GROUP BY DATE(TransactionDate) ORDER BY d""")
        chart_data=[{'date':str(r['d']),'total':sf(r['total'])} for r in cur.fetchall()]
        return jsonify({'customers':customers,'accounts':accounts,'total_balance':total_balance,
                        'today_txn':today_txn,'employees':employees,'branches':branches,
                        'txn_summary':txn_summary,'recent':recent,'alerts':alerts,'chart_data':chart_data})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

# ─── CUSTOMERS ───
@app.route('/api/customers')
@login_required
def api_customers():
    conn = get_db()
    if not conn: return jsonify({'data':[],'total':0})
    try:
        cur = conn.cursor(dictionary=True)
        search = request.args.get('search','').strip()
        page = si(request.args.get('page',1)); per = 10
        offset = (page-1)*per
        where = "WHERE c.FullName LIKE %s OR c.PhoneNumber LIKE %s OR c.NationalID LIKE %s" if search else ""
        params = (f'%{search}%',f'%{search}%',f'%{search}%') if search else ()
        cur.execute(f"SELECT COUNT(DISTINCT c.CustomerID) AS total FROM Customers c {where}", params)
        total = si(cur.fetchone()['total'])
        cur.execute(f"""SELECT c.*, COUNT(a.AccountID) AS num_accounts
                       FROM Customers c LEFT JOIN Accounts a ON c.CustomerID=a.CustomerID
                       {where} GROUP BY c.CustomerID ORDER BY c.CreatedAt DESC LIMIT %s OFFSET %s""",
                    (*params, per, offset))
        rows = cur.fetchall()
        return jsonify({'data':[{'id':r['CustomerID'],'name':r['FullName'],'phone':r['PhoneNumber'],
                                  'email':r['Email'] or '','address':r['Address'] or '',
                                  'nid':r['NationalID'],'dob':str(r['DateOfBirth']) if r['DateOfBirth'] else '',
                                  'created':str(r['CreatedAt'])[:10] if r['CreatedAt'] else '',
                                  'accounts':si(r['num_accounts'])} for r in rows],
                        'total':total,'page':page,'per':per})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

@app.route('/api/customers', methods=['POST'])
@login_required
def api_add_customer():
    conn = get_db()
    if not conn: return jsonify({'error':'DB connection failed'}), 500
    try:
        data = request.get_json()
        cur = conn.cursor()
        cur.execute("INSERT INTO Customers (FullName,DateOfBirth,PhoneNumber,Email,Address,NationalID) VALUES (%s,%s,%s,%s,%s,%s)",
                    (data['name'],data.get('dob') or None,data['phone'],data.get('email') or None,data.get('address') or None,data['nid']))
        conn.commit()
        log_action('ADD_CUSTOMER', f"Added customer: {data['name']}")
        return jsonify({'ok':True,'id':cur.lastrowid})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

@app.route('/api/customers/<int:cid>', methods=['PUT'])
@login_required
def api_update_customer(cid):
    conn = get_db()
    if not conn: return jsonify({'error':'DB connection failed'}), 500
    try:
        data = request.get_json()
        cur = conn.cursor()
        cur.execute("UPDATE Customers SET FullName=%s,DateOfBirth=%s,PhoneNumber=%s,Email=%s,Address=%s WHERE CustomerID=%s",
                    (data['name'],data.get('dob') or None,data['phone'],data.get('email') or None,data.get('address') or None,cid))
        conn.commit()
        log_action('UPDATE_CUSTOMER', f"Updated customer ID: {cid}")
        return jsonify({'ok':True})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

@app.route('/api/customers/<int:cid>/accounts')
@login_required
def api_customer_accounts(cid):
    conn = get_db()
    if not conn: return jsonify([])
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT a.*,b.BranchName FROM Accounts a JOIN Branches b ON a.BranchID=b.BranchID WHERE a.CustomerID=%s ORDER BY a.AccountID DESC",(cid,))
        rows = cur.fetchall()
        return jsonify([{'id':r['AccountID'],'type':r['AccountType'],'balance':sf(r['Balance']),
                         'open':str(r['OpenDate']) if r['OpenDate'] else '','status':r['Status'],'branch':r['BranchName']} for r in rows])
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

# ─── ACCOUNTS ───
@app.route('/api/accounts')
@login_required
def api_accounts():
    conn = get_db()
    if not conn: return jsonify({'data':[],'total':0})
    try:
        cur = conn.cursor(dictionary=True)
        status_filter = request.args.get('status','')
        page = si(request.args.get('page',1)); per = 10; offset = (page-1)*per
        where = "WHERE a.Status=%s" if status_filter else ""
        params = (status_filter,) if status_filter else ()
        cur.execute(f"SELECT COUNT(*) AS total FROM Accounts a {where}", params)
        total = si(cur.fetchone()['total'])
        cur.execute(f"""SELECT a.AccountID AS id, a.CustomerID AS cid, c.FullName AS cname,
                              a.AccountType AS type, a.Balance AS balance, a.OpenDate AS open_date,
                              a.Status AS status, b.BranchName AS branch, b.BranchID AS bid
                       FROM Accounts a JOIN Customers c ON a.CustomerID=c.CustomerID
                       JOIN Branches b ON a.BranchID=b.BranchID {where}
                       ORDER BY a.AccountID DESC LIMIT %s OFFSET %s""", (*params, per, offset))
        rows = cur.fetchall()
        return jsonify({'data':[{'id':r['id'],'cid':r['cid'],'cname':r['cname'],'type':r['type'],
                                  'balance':sf(r['balance']),'open':str(r['open_date']) if r['open_date'] else '',
                                  'status':r['status'],'branch':r['branch'],'bid':r['bid']} for r in rows],
                        'total':total,'page':page,'per':per})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

@app.route('/api/accounts/all')
@login_required
def api_accounts_all():
    conn = get_db()
    if not conn: return jsonify([])
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT a.AccountID AS id, c.FullName AS cname, a.Balance AS balance, a.AccountType AS type FROM Accounts a JOIN Customers c ON a.CustomerID=c.CustomerID WHERE a.Status='Active' ORDER BY c.FullName")
        rows = cur.fetchall()
        return jsonify([{'id':r['id'],'cname':r['cname'],'balance':sf(r['balance']),'type':r['type']} for r in rows])
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

@app.route('/api/accounts', methods=['POST'])
@login_required
def api_open_account():
    conn = get_db()
    if not conn: return jsonify({'error':'DB connection failed'}), 500
    try:
        data = request.get_json()
        cur = conn.cursor()
        cur.execute("INSERT INTO Accounts (CustomerID,BranchID,AccountType,Balance,OpenDate,Status) VALUES (%s,%s,%s,%s,CURDATE(),'Active')",
                    (data['customer_id'],data['branch_id'],data['account_type'],sf(data.get('initial_balance',0))))
        conn.commit()
        log_action('OPEN_ACCOUNT', f"Opened account for customer ID: {data['customer_id']}")
        return jsonify({'ok':True,'id':cur.lastrowid})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

@app.route('/api/accounts/<int:aid>/close', methods=['PUT'])
@manager_required
def api_close_account(aid):
    conn = get_db()
    if not conn: return jsonify({'error':'DB connection failed'}), 500
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT Balance FROM Accounts WHERE AccountID=%s",(aid,))
        row = cur.fetchone()
        if not row: return jsonify({'error':'Account not found'}), 404
        if sf(row['Balance']) > 0:
            return jsonify({'error':f'Tài khoản còn số dư {sf(row["Balance"]):,.0f} VND. Vui lòng rút hết trước khi đóng.'}), 400
        cur2 = conn.cursor()
        cur2.execute("UPDATE Accounts SET Status='Closed' WHERE AccountID=%s",(aid,))
        conn.commit()
        log_action('CLOSE_ACCOUNT', f"Closed account ID: {aid}")
        return jsonify({'ok':True})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

# ─── TRANSACTIONS ───
@app.route('/api/transactions')
@login_required
def api_transactions():
    conn = get_db()
    if not conn: return jsonify({'data':[],'total':0})
    try:
        cur = conn.cursor(dictionary=True)
        date_from = request.args.get('from',''); date_to = request.args.get('to','')
        txn_type = request.args.get('type','')
        acc_id_filter = request.args.get('acc','')
        page = si(request.args.get('page',1)); per = si(request.args.get('per',15)); offset = (page-1)*per
        where = "WHERE 1=1"; params = []
        if date_from: where += " AND DATE(t.TransactionDate)>=%s"; params.append(date_from)
        if date_to: where += " AND DATE(t.TransactionDate)<=%s"; params.append(date_to)
        if txn_type: where += " AND t.TransactionType=%s"; params.append(txn_type)
        if acc_id_filter: where += " AND t.AccountID=%s"; params.append(acc_id_filter)
        cur.execute(f"SELECT COUNT(*) AS total FROM Transactions t {where}", params)
        total = si(cur.fetchone()['total'])
        cur.execute(f"""SELECT t.TransactionID AS txn_id, t.AccountID AS acc_id, c.FullName AS cname,
                              t.TransactionType AS txn_type, t.Amount AS amount, t.BalanceAfter AS bal_after,
                              t.Description AS txn_desc, t.TransactionDate AS txn_date,
                              COALESCE(e.FullName,'System') AS emp
                       FROM Transactions t JOIN Accounts a ON t.AccountID=a.AccountID
                       JOIN Customers c ON a.CustomerID=c.CustomerID
                       LEFT JOIN Employees e ON t.EmployeeID=e.EmployeeID
                       {where} ORDER BY t.TransactionDate DESC LIMIT %s OFFSET %s""",
                    (*params, per, offset))
        rows = cur.fetchall()
        return jsonify({'data':[{'id':r['txn_id'],'accId':r['acc_id'],'cname':r['cname'],'type':r['txn_type'],
                                  'amount':sf(r['amount']),'balAfter':sf(r['bal_after']),'desc':r['txn_desc'] or '',
                                  'date':str(r['txn_date']) if r['txn_date'] else '','emp':r['emp']} for r in rows],
                        'total':total,'page':page,'per':per})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

@app.route('/api/transactions', methods=['POST'])
@login_required
def api_new_transaction():
    if session.get('role') == 'Auditor':
        return jsonify({'error':'Auditor không có quyền tạo giao dịch'}), 403
    conn = get_db()
    if not conn: return jsonify({'error':'DB connection failed'}), 500
    try:
        data = request.get_json()
        acc_id = int(data['account_id']); amount = float(data['amount'])
        txn_type = data['txn_type']; desc = data.get('description','') or ''
        to_acc = data.get('to_account_id')
        cur = conn.cursor()
        if txn_type == 'Deposit':
            cur.callproc('sp_Deposit',[acc_id,amount,1,desc,0])
        elif txn_type == 'Withdrawal':
            cur.callproc('sp_Withdraw',[acc_id,amount,1,desc,0])
        elif txn_type == 'Transfer' and to_acc:
            cur.callproc('sp_Transfer',[acc_id,int(to_acc),amount,1,desc])
        else:
            return jsonify({'error':'Thông tin giao dịch không hợp lệ'}), 400
        conn.commit()
        cur2 = conn.cursor(dictionary=True)
        cur2.execute("SELECT Balance FROM Accounts WHERE AccountID=%s",(acc_id,))
        row = cur2.fetchone()
        new_balance = sf(row['Balance']) if row else 0
        cur2.execute("SELECT MAX(TransactionID) AS id FROM Transactions WHERE AccountID=%s",(acc_id,))
        txn_row = cur2.fetchone()
        txn_id = si(txn_row['id']) if txn_row else 0
        log_action('TRANSACTION', f"{txn_type} {amount:,.0f} VND - Account #{acc_id}")
        return jsonify({'ok':True,'new_balance':new_balance,'txn_id':txn_id,
                        'amount':amount,'type':txn_type,'account_id':acc_id})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

# ─── EMPLOYEES ───
@app.route('/api/employees')
@login_required
def api_employees():
    conn = get_db()
    if not conn: return jsonify([])
    try:
        cur = conn.cursor(dictionary=True)
        branch = request.args.get('branch',''); pos = request.args.get('position','')
        where = "WHERE 1=1"; params = []
        if branch: where += " AND e.BranchID=%s"; params.append(branch)
        if pos: where += " AND e.Position=%s"; params.append(pos)
        cur.execute(f"SELECT e.*,b.BranchName FROM Employees e JOIN Branches b ON e.BranchID=b.BranchID {where} ORDER BY e.EmployeeID", params)
        rows = cur.fetchall()
        return jsonify([{'id':r['EmployeeID'],'name':r['FullName'],'position':r['Position'],
                         'branch':r['BranchName'],'bid':r['BranchID'],
                         'hire':str(r['HireDate']) if r['HireDate'] else '',
                         'salary':sf(r['Salary']),'email':r['Email'] or ''} for r in rows])
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

@app.route('/api/employees', methods=['POST'])
@manager_required
def api_add_employee():
    conn = get_db()
    if not conn: return jsonify({'error':'DB connection failed'}), 500
    try:
        data = request.get_json()
        cur = conn.cursor()
        cur.execute("INSERT INTO Employees (BranchID,FullName,Position,HireDate,Salary,Email) VALUES (%s,%s,%s,%s,%s,%s)",
                    (data['branch_id'],data['name'],data['position'],data.get('hire_date') or None,sf(data.get('salary',0)),data.get('email') or None))
        conn.commit()
        log_action('ADD_EMPLOYEE', f"Added employee: {data['name']}")
        return jsonify({'ok':True,'id':cur.lastrowid})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

@app.route('/api/employees/<int:eid>', methods=['PUT'])
@manager_required
def api_update_employee(eid):
    conn = get_db()
    if not conn: return jsonify({'error':'DB connection failed'}), 500
    try:
        data = request.get_json()
        cur = conn.cursor()
        cur.execute("UPDATE Employees SET FullName=%s,Position=%s,BranchID=%s,Salary=%s,Email=%s WHERE EmployeeID=%s",
                    (data['name'],data['position'],data['branch_id'],sf(data.get('salary',0)),data.get('email') or None,eid))
        conn.commit()
        log_action('UPDATE_EMPLOYEE', f"Updated employee ID: {eid}")
        return jsonify({'ok':True})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

# ─── BRANCHES ───
@app.route('/api/branches')
@login_required
def api_branches():
    conn = get_db()
    if not conn: return jsonify([])
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""SELECT b.*,e.FullName AS manager_name,
                              COUNT(DISTINCT emp.EmployeeID) AS emp_count,
                              COUNT(DISTINCT a.AccountID) AS acc_count,
                              COALESCE(SUM(a.Balance),0) AS total_balance
                       FROM Branches b LEFT JOIN Employees e ON b.ManagerID=e.EmployeeID
                       LEFT JOIN Employees emp ON b.BranchID=emp.BranchID
                       LEFT JOIN Accounts a ON b.BranchID=a.BranchID AND a.Status='Active'
                       GROUP BY b.BranchID""")
        rows = cur.fetchall()
        return jsonify([{'id':r['BranchID'],'name':r['BranchName'],'address':r['Address'] or '',
                         'phone':r['Phone'] or '','manager':r['manager_name'] or 'Chưa có',
                         'manager_id':r['ManagerID'],'emp_count':si(r['emp_count']),
                         'acc_count':si(r['acc_count']),'total_balance':sf(r['total_balance'])} for r in rows])
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

# ─── REPORTS ───
@app.route('/api/reports')
@login_required
def api_reports():
    conn = get_db()
    if not conn: return jsonify({})
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""SELECT DATE(TransactionDate) AS date, TransactionType AS type,
                              COUNT(*) AS cnt, COALESCE(SUM(Amount),0) AS total
                       FROM Transactions GROUP BY DATE(TransactionDate), TransactionType
                       ORDER BY date DESC LIMIT 30""")
        daily = [{'date':str(r['date']),'type':r['type'],'cnt':si(r['cnt']),'total':sf(r['total'])} for r in cur.fetchall()]
        cur.execute("""SELECT b.BranchName AS name,COUNT(DISTINCT a.AccountID) AS accounts,
                              COALESCE(SUM(a.Balance),0) AS balance,COUNT(DISTINCT e.EmployeeID) AS employees
                       FROM Branches b LEFT JOIN Accounts a ON b.BranchID=a.BranchID
                       LEFT JOIN Employees e ON b.BranchID=e.BranchID
                       GROUP BY b.BranchID,b.BranchName ORDER BY balance DESC""")
        branches = [{'name':r['name'],'accounts':si(r['accounts']),'balance':sf(r['balance']),'employees':si(r['employees'])} for r in cur.fetchall()]
        cur.execute("""SELECT c.FullName AS name,a.AccountID AS id,a.Balance AS balance,
                              fn_SimpleInterest(a.Balance,0.065,6) AS interest
                       FROM Accounts a JOIN Customers c ON a.CustomerID=c.CustomerID
                       WHERE a.AccountType='Savings' AND a.Status='Active' ORDER BY a.Balance DESC""")
        interest = [{'name':r['name'],'id':r['id'],'balance':sf(r['balance']),'interest':sf(r['interest'])} for r in cur.fetchall()]
        cur.execute("SELECT * FROM SuspiciousLog ORDER BY FlaggedAt DESC LIMIT 20")
        suspicious = [{'id':r['LogID'],'txnId':r['TransactionID'],'reason':r['Reason'],'time':str(r['FlaggedAt'])} for r in cur.fetchall()]
        cur.execute("""SELECT TransactionType AS type,COUNT(*) AS cnt,COALESCE(SUM(Amount),0) AS total,COALESCE(AVG(Amount),0) AS avg
                       FROM Transactions GROUP BY TransactionType""")
        summary = [{'type':r['type'],'cnt':si(r['cnt']),'total':sf(r['total']),'avg':sf(r['avg'])} for r in cur.fetchall()]
        cur.execute("""SELECT DATE(TransactionDate) AS d, COALESCE(SUM(Amount),0) AS total
                       FROM Transactions WHERE DATE(TransactionDate)>=DATE_SUB(CURDATE(),INTERVAL 30 DAY)
                       GROUP BY DATE(TransactionDate) ORDER BY d""")
        chart = [{'date':str(r['d']),'total':sf(r['total'])} for r in cur.fetchall()]
        return jsonify({'daily':daily,'branches':branches,'interest':interest,'suspicious':suspicious,'summary':summary,'chart':chart})
    except Error as e:
        return jsonify({'error':str(e)}), 500
    finally:
        conn.close()

if __name__ == '__main__':
    # Tao bang AuditLog neu chua co
    try:
        conn = get_db()
        if conn:
            cur = conn.cursor()
            cur.execute("""CREATE TABLE IF NOT EXISTS AuditLog (
                LogID INT AUTO_INCREMENT PRIMARY KEY,
                Username VARCHAR(50), Role VARCHAR(20),
                Action VARCHAR(100), Detail VARCHAR(500),
                LogTime DATETIME DEFAULT CURRENT_TIMESTAMP
            )""")
            conn.commit()
            conn.close()
    except: pass
    app.run(debug=True, port=5000)