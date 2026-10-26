<?php
if (session_status() === PHP_SESSION_NONE) { session_start(); }
require_once 'db.php';
require_once 'finance_accounting_bridge.php';

if (!isset($_SESSION['user_id']) || !app_has_perm('manage_erp')) {
    header("Location: dashboard.php");
    exit;
}
$role = $_SESSION['role'] ?? '';
$user = ['id' => $_SESSION['user_id'], 'role' => $role];

$cur_tenant_id = get_current_tenant_id($pdo);

// Ensure tables and columns exist with bulletproof self-healing
try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS acc_vouchers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        voucher_no VARCHAR(100) NOT NULL,
        date DATE NOT NULL,
        type VARCHAR(50) DEFAULT 'Journal',
        reference VARCHAR(100) DEFAULT NULL,
        description TEXT DEFAULT NULL,
        department_id INT DEFAULT NULL,
        status VARCHAR(50) DEFAULT 'Pending',
        created_by INT DEFAULT NULL,
        approved_by INT DEFAULT NULL,
        approved_at DATETIME DEFAULT NULL,
        system_type VARCHAR(50) DEFAULT 'Madrasa',
        tenant_id INT NOT NULL DEFAULT 1,
        is_deleted TINYINT(1) DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX (tenant_id),
        INDEX (status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $pdo->exec("CREATE TABLE IF NOT EXISTS acc_ledger_entries (
        id INT AUTO_INCREMENT PRIMARY KEY,
        voucher_id INT NOT NULL,
        account_id INT NOT NULL,
        debit DECIMAL(15,2) DEFAULT 0.00,
        credit DECIMAL(15,2) DEFAULT 0.00,
        department_id INT DEFAULT NULL,
        tenant_id INT NOT NULL DEFAULT 1,
        INDEX (voucher_id),
        INDEX (account_id),
        INDEX (tenant_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $pdo->exec("CREATE TABLE IF NOT EXISTS departments (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        status VARCHAR(50) DEFAULT 'Active',
        system_type VARCHAR(50) DEFAULT 'Madrasa',
        tenant_id INT DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $pdo->exec("CREATE TABLE IF NOT EXISTS acc_audit_log (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id INT NOT NULL DEFAULT 1,
        voucher_id INT NOT NULL,
        voucher_no VARCHAR(100) DEFAULT NULL,
        action VARCHAR(50) NOT NULL,
        user_id INT DEFAULT NULL,
        user_name VARCHAR(100) DEFAULT NULL,
        details TEXT DEFAULT NULL,
        ip_address VARCHAR(50) DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX (voucher_id),
        INDEX (tenant_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $vCols = $pdo->query("SHOW COLUMNS FROM acc_vouchers")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('approved_by', $vCols)) $pdo->exec("ALTER TABLE acc_vouchers ADD COLUMN approved_by INT DEFAULT NULL");
    if (!in_array('approved_at', $vCols)) $pdo->exec("ALTER TABLE acc_vouchers ADD COLUMN approved_at DATETIME DEFAULT NULL");
    if (!in_array('is_deleted', $vCols)) $pdo->exec("ALTER TABLE acc_vouchers ADD COLUMN is_deleted TINYINT(1) DEFAULT 0");
    if (!in_array('system_type', $vCols)) $pdo->exec("ALTER TABLE acc_vouchers ADD COLUMN system_type VARCHAR(50) DEFAULT 'Madrasa'");
    if (!in_array('created_by', $vCols)) $pdo->exec("ALTER TABLE acc_vouchers ADD COLUMN created_by INT DEFAULT NULL");
    if (!in_array('department_id', $vCols)) $pdo->exec("ALTER TABLE acc_vouchers ADD COLUMN department_id INT DEFAULT NULL");
    if (!in_array('tenant_id', $vCols)) $pdo->exec("ALTER TABLE acc_vouchers ADD COLUMN tenant_id INT NOT NULL DEFAULT 1");

    $leCols = $pdo->query("SHOW COLUMNS FROM acc_ledger_entries")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('department_id', $leCols)) $pdo->exec("ALTER TABLE acc_ledger_entries ADD COLUMN department_id INT DEFAULT NULL");
    if (!in_array('tenant_id', $leCols)) $pdo->exec("ALTER TABLE acc_ledger_entries ADD COLUMN tenant_id INT NOT NULL DEFAULT 1");

    $dCols = $pdo->query("SHOW COLUMNS FROM departments")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('status', $dCols)) $pdo->exec("ALTER TABLE departments ADD COLUMN status VARCHAR(50) DEFAULT 'Active'");
    if (!in_array('tenant_id', $dCols)) $pdo->exec("ALTER TABLE departments ADD COLUMN tenant_id INT DEFAULT 1");
} catch (Throwable $e) {}

if (!function_exists('acc_log_audit')) {
    function acc_log_audit($pdo, $voucher_id, $voucher_no, $action, $user_id, $user_name, $details = '') {
        try {
            $stmt = $pdo->prepare("INSERT INTO acc_audit_log (voucher_id, voucher_no, action, user_id, user_name, details, ip_address, tenant_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
            $ip = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
            $tId = function_exists('get_current_tenant_id') ? (int)get_current_tenant_id() : 1;
            $stmt->execute([$voucher_id, $voucher_no, $action, $user_id, $user_name, is_array($details) ? json_encode($details, JSON_UNESCAPED_UNICODE) : (string)$details, $ip, $tId]);
        } catch (Throwable $e) {}
    }
}

// Repair any orphan finance vouchers
try {
    if (function_exists('finance_accounting_repair_vouchers')) {
        finance_accounting_repair_vouchers($pdo);
    }
} catch (Throwable $e) {}

// Handle Actions
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['add_voucher'])) {
    $date = $_POST['date'] ?? date('Y-m-d');
    $type = $_POST['type'] ?? 'Journal';
    $desc = $_POST['description'] ?? '';
    $ref = $_POST['reference'] ?? '';
    
    // Auto-generate voucher number scoped by tenant
    $prefix = strtoupper(substr($type, 0, 1)) . 'V-';
    $stmt = $pdo->prepare("SELECT COUNT(*) FROM acc_vouchers WHERE type = ? AND tenant_id = ?");
    $stmt->execute([$type, $cur_tenant_id]);
    $count = $stmt->fetchColumn() + 1;
    $voucher_no = $prefix . str_pad($count, 5, '0', STR_PAD_LEFT);
    
    $accounts = $_POST['account_id'] ?? [];
    $debits = $_POST['debit'] ?? [];
    $credits = $_POST['credit'] ?? [];
    $department_id = !empty($_POST['department_id']) ? (int)$_POST['department_id'] : null;
    
    try {
        $clean_lines = [];
        $total_debit = 0;
        $total_credit = 0;
        for ($i = 0; $i < count($accounts); $i++) {
            $acc_id = (int)($accounts[$i] ?? 0);
            $dr = (float)($debits[$i] ?? 0);
            $cr = (float)($credits[$i] ?? 0);
            if ($acc_id <= 0 && ($dr > 0 || $cr > 0)) {
                throw new Exception("Ledger line has amount but no account selected.");
            }
            if ($dr < 0 || $cr < 0) {
                throw new Exception("منفی رقوم درج کرنا ممنوع ہے۔ (Negative amounts are not allowed)");
            }
            if ($dr > 0 && $cr > 0) {
                throw new Exception("One ledger line cannot have both debit and credit.");
            }
            if ($acc_id > 0 && ($dr > 0 || $cr > 0)) {
                $clean_lines[] = [$acc_id, $dr, $cr];
                $total_debit += $dr;
                $total_credit += $cr;
            }
        }
        if (count($clean_lines) < 2) {
            throw new Exception("At least two ledger lines are required.");
        }
        if ($total_debit <= 0 || abs($total_debit - $total_credit) > 0.01) {
            throw new Exception("Debits and Credits must balance. Dr: $total_debit, Cr: $total_credit");
        }

        $sys = $_SESSION['system_type'] ?? 'Madrasa';
        $pdo->beginTransaction();
        $stmt = $pdo->prepare("INSERT INTO acc_vouchers (voucher_no, date, type, reference, description, department_id, created_by, status, system_type, tenant_id) VALUES (?, ?, ?, ?, ?, ?, ?, 'Pending', ?, ?)");
        $stmt->execute([$voucher_no, $date, $type, $ref, $desc, $department_id, $user['id'], $sys, $cur_tenant_id]);
        $voucher_id = $pdo->lastInsertId();
        $entry_stmt = $pdo->prepare("INSERT INTO acc_ledger_entries (voucher_id, account_id, debit, credit, department_id, tenant_id) VALUES (?, ?, ?, ?, ?, ?)");
        foreach ($clean_lines as $line) {
            $entry_stmt->execute([$voucher_id, $line[0], $line[1], $line[2], $department_id, $cur_tenant_id]);
        }
        $pdo->commit();
        acc_log_audit($pdo, $voucher_id, $voucher_no, 'CREATED', $user['id'], $_SESSION['name'] ?? 'Admin', ['total' => $total_debit, 'lines' => count($clean_lines)]);
        $msg = "Voucher $voucher_no created successfully!";
    } catch (Exception $e) {
        if ($pdo->inTransaction()) { $pdo->rollBack(); }
        $err = "Failed: " . $e->getMessage();
    }
}

// Four-Eyes Approval
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['update_status']) && $role === 'admin') {
    $v_id = (int)$_POST['voucher_id'];
    $new_status = $_POST['status'];
    if (in_array($new_status, ['Pending', 'Approved', 'Rejected'])) {
        $vStmt = $pdo->prepare("SELECT v.*, (SELECT SUM(debit) FROM acc_ledger_entries WHERE voucher_id = v.id) as total_amount FROM acc_vouchers v WHERE v.id = ? AND v.tenant_id = ?");
        $vStmt->execute([$v_id, $cur_tenant_id]);
        $vRow = $vStmt->fetch(PDO::FETCH_ASSOC);
        if ($vRow) {
            $totalAmt = (float)($vRow['total_amount'] ?? 0);
            $creatorId = (int)($vRow['created_by'] ?? 0);
            if ($new_status === 'Approved' && $totalAmt > 50000 && $creatorId === (int)$user['id']) {
                $err = "50 ہزار سے زائد رقم کے واؤچر (Rs. " . number_format($totalAmt) . ") کی منظوری کے لیے چار آنکھوں کا پروٹوکول (Four-Eyes Principle) لازمی ہے؛ کوئی دوسرا ایڈمنسٹریٹر منظوری دے گا۔";
            } else {
                $pdo->prepare("UPDATE acc_vouchers SET status = ?, approved_by = ?, approved_at = NOW() WHERE id = ? AND tenant_id = ?")->execute([$new_status, $user['id'], $v_id, $cur_tenant_id]);
                acc_log_audit($pdo, $v_id, $vRow['voucher_no'], $new_status === 'Approved' ? 'APPROVED' : ($new_status === 'Rejected' ? 'REJECTED' : 'PENDING'), $user['id'], $_SESSION['name'] ?? 'Admin', ['status' => $new_status, 'amount' => $totalAmt]);
                $msg = "Voucher status updated to $new_status.";
            }
        }
    }
}

// Reversal Voucher
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['reverse_voucher']) && $role === 'admin') {
    $v_id = (int)$_POST['voucher_id'];
    try {
        $vStmt = $pdo->prepare("SELECT * FROM acc_vouchers WHERE id = ? AND tenant_id = ? AND (is_deleted = 0 OR is_deleted IS NULL)");
        $vStmt->execute([$v_id, $cur_tenant_id]);
        $orig = $vStmt->fetch(PDO::FETCH_ASSOC);
        if (!$orig) throw new Exception("Voucher not found.");
        if ($orig['status'] !== 'Approved') throw new Exception("Only Approved vouchers can be reversed.");

        $linesStmt = $pdo->prepare("SELECT * FROM acc_ledger_entries WHERE voucher_id = ? AND tenant_id = ?");
        $linesStmt->execute([$v_id, $cur_tenant_id]);
        $lines = $linesStmt->fetchAll(PDO::FETCH_ASSOC);
        if (empty($lines)) throw new Exception("No ledger entries found to reverse.");

        $pdo->beginTransaction();
        $revNo = 'REV-' . $orig['voucher_no'];
        $revDesc = "Reversal of " . $orig['voucher_no'] . ": " . ($orig['description'] ?? '');
        $sys = $orig['system_type'] ?? 'Madrasa';
        $insV = $pdo->prepare("INSERT INTO acc_vouchers (voucher_no, date, type, reference, description, department_id, created_by, approved_by, approved_at, status, system_type, tenant_id) VALUES (?, ?, 'Journal', ?, ?, ?, ?, ?, NOW(), 'Approved', ?, ?)");
        $insV->execute([$revNo, date('Y-m-d'), $orig['voucher_no'], $revDesc, $orig['department_id'], $user['id'], $user['id'], $sys, $cur_tenant_id]);
        $newVoucherId = (int)$pdo->lastInsertId();

        $insE = $pdo->prepare("INSERT INTO acc_ledger_entries (voucher_id, account_id, debit, credit, department_id, tenant_id) VALUES (?, ?, ?, ?, ?, ?)");
        foreach ($lines as $ln) {
            // Swap debit and credit
            $insE->execute([$newVoucherId, $ln['account_id'], $ln['credit'], $ln['debit'], $ln['department_id'], $cur_tenant_id]);
        }

        $pdo->prepare("UPDATE acc_vouchers SET status = 'Reversed' WHERE id = ? AND tenant_id = ?")->execute([$v_id, $cur_tenant_id]);

        acc_log_audit($pdo, $v_id, $orig['voucher_no'], 'REVERSED', $user['id'], $_SESSION['name'] ?? 'Admin', "Reversed by voucher $revNo");
        acc_log_audit($pdo, $newVoucherId, $revNo, 'REVERSAL_CREATED', $user['id'], $_SESSION['name'] ?? 'Admin', "Reversal of " . $orig['voucher_no']);

        $pdo->commit();
        $msg = "واؤچر {$orig['voucher_no']} کا ریورسل واؤچر ($revNo) کامیابی سے جاری کر دیا گیا ہے۔";
    } catch (Exception $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        $err = "Reversal Failed: " . $e->getMessage();
    }
}

// Delete Voucher (Only for Pending or Rejected)
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['delete_voucher']) && $role === 'admin') {
    $v_id = (int)$_POST['voucher_id'];
    try {
        $chk = $pdo->prepare("SELECT status, voucher_no FROM acc_vouchers WHERE id = ? AND tenant_id = ?");
        $chk->execute([$v_id, $cur_tenant_id]);
        $row = $chk->fetch(PDO::FETCH_ASSOC);
        if ($row && in_array($row['status'], ['Approved', 'Reversed'], true)) {
            throw new Exception("منظور شدہ یا ریورس شدہ واؤچر حذف نہیں کیا جا سکتا۔ آڈٹ ٹریل برقرار رکھنے کے لیے ریورسل واؤچر استعمال کریں۔");
        }
        $pdo->prepare("UPDATE acc_vouchers SET is_deleted = 1 WHERE id = ? AND tenant_id = ?")->execute([$v_id, $cur_tenant_id]);
        if ($row) {
            acc_log_audit($pdo, $v_id, $row['voucher_no'], 'DELETED', $user['id'], $_SESSION['name'] ?? 'Admin');
        }
        $msg = "Voucher deleted successfully.";
    } catch (Exception $e) {
        $err = $e->getMessage();
    }
}

// Fetch Vouchers with System Type and Tenant Isolation
$sys = $_SESSION['system_type'] ?? 'Madrasa';
$sys_cond = ($sys === 'Masjid') ? "v.system_type = 'Masjid'" : "(v.system_type = 'Madrasa' OR v.system_type IS NULL OR v.system_type = '')";

$vouchers = [];
try {
    $v_stmt = $pdo->prepare("SELECT v.*, u.name as creator_name, (SELECT SUM(debit) FROM acc_ledger_entries WHERE voucher_id = v.id) as total_amount FROM acc_vouchers v LEFT JOIN admins u ON v.created_by = u.id WHERE (v.is_deleted = 0 OR v.is_deleted IS NULL) AND $sys_cond AND (v.tenant_id = ? OR v.tenant_id IS NULL OR v.tenant_id = 0) ORDER BY v.date DESC, v.id DESC LIMIT 200");
    $v_stmt->execute([$cur_tenant_id]);
    $vouchers = $v_stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $e) {
    error_log('[acc_vouchers.php] v_stmt error: ' . $e->getMessage());
    try {
        $v_stmt = $pdo->prepare("SELECT v.*, (SELECT SUM(debit) FROM acc_ledger_entries WHERE voucher_id = v.id) as total_amount FROM acc_vouchers v WHERE (v.is_deleted = 0 OR v.is_deleted IS NULL) ORDER BY v.id DESC LIMIT 200");
        $v_stmt->execute();
        $vouchers = $v_stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $e2) {
        $vouchers = [];
    }
}

// Fetch Chart of Accounts for Dropdown (Tenant scoped)
$accounts_list = [];
try {
    $acc_list_stmt = $pdo->prepare("SELECT id, code, name FROM acc_chart_of_accounts WHERE (is_deleted = 0 OR is_deleted IS NULL) AND (tenant_id = ? OR tenant_id IS NULL OR tenant_id = 0) ORDER BY code");
    $acc_list_stmt->execute([$cur_tenant_id]);
    $accounts_list = $acc_list_stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $e) {
    try {
        $accounts_list = $pdo->query("SELECT id, code, name FROM acc_chart_of_accounts WHERE (is_deleted = 0 OR is_deleted IS NULL) ORDER BY code")->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $e2) {
        $accounts_list = [];
    }
}

// Fetch Departments (Tenant scoped)
$departments_list = [];
try {
    $dept_stmt = $pdo->prepare("SELECT id, name FROM departments WHERE (status = 'Active' OR status IS NULL) AND (tenant_id = ? OR tenant_id IS NULL OR tenant_id = 0) ORDER BY name");
    $dept_stmt->execute([$cur_tenant_id]);
    $departments_list = $dept_stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $e) {
    try {
        $departments_list = $pdo->query("SELECT id, name FROM departments ORDER BY name")->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $e2) {
        $departments_list = [];
    }
}

$title = "Vouchers - ERP Accounting";
include 'header.php';
?>

<div class="container py-4">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h3 class="fw-bold text-primary"><i class="fas fa-receipt me-2"></i> Accounting Vouchers</h3>
        <button class="btn btn-success fw-bold" data-bs-toggle="modal" data-bs-target="#newVoucherModal">
            <i class="fas fa-plus me-1"></i> New Voucher
        </button>
    </div>

    <?php if (!empty($msg)): ?>
        <div class="alert alert-success alert-dismissible fade show"><?php echo e($msg); ?><button class="btn-close" data-bs-dismiss="alert"></button></div>
    <?php endif; ?>
    <?php if (!empty($err)): ?>
        <div class="alert alert-danger alert-dismissible fade show"><?php echo e($err); ?><button class="btn-close" data-bs-dismiss="alert"></button></div>
    <?php endif; ?>

    <!-- Vouchers List -->
    <div class="card shadow-sm border-0 neobox">
        <div class="table-responsive">
            <table class="table table-hover align-middle mb-0">
                <thead class="table-dark">
                    <tr>
                        <th>Date</th>
                        <th>Voucher #</th>
                        <th>Type</th>
                        <th>Reference</th>
                        <th>Description</th>
                        <th class="text-end">Amount</th>
                        <th>Status</th>
                        <th>Creator</th>
                        <th class="text-center">Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($vouchers)): ?>
                        <tr><td colspan="9" class="text-center py-4 text-muted">No vouchers found. Click "New Voucher" to create one.</td></tr>
                    <?php else: ?>
                        <?php foreach ($vouchers as $v): ?>
                        <tr>
                            <td><?php echo date('d-M-Y', strtotime($v['date'])); ?></td>
                            <td class="fw-bold text-primary"><?php echo e($v['voucher_no']); ?></td>
                            <td><span class="badge bg-secondary"><?php echo e($v['type']); ?></span></td>
                            <td><small class="text-muted"><?php echo e($v['reference'] ?? '---'); ?></small></td>
                            <td><small><?php echo e($v['description'] ?? '---'); ?></small></td>
                            <td class="text-end fw-bold">Rs. <?php echo number_format($v['total_amount'] ?? 0, 2); ?></td>
                            <td>
                                <span class="badge bg-<?php echo $v['status']=='Approved'?'success':($v['status']=='Rejected'?'danger':($v['status']=='Reversed'?'dark':($v['status']=='Void'?'secondary':'warning'))); ?>">
                                    <?php echo !empty($v['status']) ? e($v['status']) : 'Void'; ?>
                                </span>
                            </td>
                            <td><small><?php echo e($v['creator_name'] ?? 'System'); ?></small></td>
                            <td class="text-center">
                                <button class="btn btn-sm btn-outline-primary me-1" onclick="viewVoucher(<?php echo $v['id']; ?>)" title="تفصیلات"><i class="fas fa-eye"></i></button>
                                
                                <?php if ($v['status'] === 'Pending'): ?>
                                    <a href="acc_voucher_edit.php?id=<?php echo $v['id']; ?>" class="btn btn-sm btn-outline-warning me-1" title="ترمیم"><i class="fas fa-edit"></i></a>
                                    <?php if ($role === 'admin'): ?>
                                        <form method="POST" class="d-inline" onsubmit="return confirm('Delete this voucher?')">
                                            <input type="hidden" name="voucher_id" value="<?php echo $v['id']; ?>">
                                            <button type="submit" name="delete_voucher" class="btn btn-sm btn-outline-danger" title="حذف"><i class="fas fa-trash"></i></button>
                                        </form>
                                        <form method="POST" class="d-inline ms-1">
                                            <input type="hidden" name="voucher_id" value="<?php echo $v['id']; ?>">
                                            <input type="hidden" name="status" value="Approved">
                                            <button type="submit" name="update_status" class="btn btn-sm btn-success" title="منظور کریں"><i class="fas fa-check"></i></button>
                                        </form>
                                    <?php endif; ?>
                                <?php elseif ($v['status'] === 'Approved'): ?>
                                    <?php if ($role === 'admin'): ?>
                                        <form method="POST" class="d-inline ms-1" onsubmit="return confirm('کیا آپ واقعی اس منظور شدہ واؤچر کا ریورسل واؤچر (Reversal Voucher) جاری کرنا چاہتے ہیں؟')">
                                            <input type="hidden" name="voucher_id" value="<?php echo $v['id']; ?>">
                                            <button type="submit" name="reverse_voucher" class="btn btn-sm btn-outline-danger" title="ریورسل واؤچر بنائیں"><i class="fas fa-undo"></i> ریورس</button>
                                        </form>
                                    <?php endif; ?>
                                <?php endif; ?>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<!-- Modal for New Voucher -->
<div class="modal fade" id="newVoucherModal" tabindex="-1">
    <div class="modal-dialog modal-lg">
        <form method="POST" class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h5 class="modal-title fw-bold"><i class="fas fa-plus-circle me-2"></i> Create New Voucher</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <div class="row g-3 mb-3">
                    <div class="col-md-4">
                        <label class="fw-bold">Date</label>
                        <input type="date" name="date" class="form-control" value="<?php echo date('Y-m-d'); ?>" required>
                    </div>
                    <div class="col-md-4">
                        <label class="fw-bold">Voucher Type</label>
                        <select name="type" class="form-select" required>
                            <option value="Journal">Journal Voucher (JV)</option>
                            <option value="Payment">Payment Voucher (PV)</option>
                            <option value="Receipt">Receipt Voucher (RV)</option>
                        </select>
                    </div>
                    <div class="col-md-4">
                        <label class="fw-bold">Department (Optional)</label>
                        <select name="department_id" class="form-select">
                            <option value="">-- General / None --</option>
                            <?php foreach($departments_list as $d): ?>
                                <option value="<?php echo $d['id']; ?>"><?php echo e($d['name']); ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div class="col-md-6">
                        <label class="fw-bold">Reference # / Bill #</label>
                        <input type="text" name="reference" class="form-control" placeholder="e.g. INV-1002">
                    </div>
                    <div class="col-md-6">
                        <label class="fw-bold">Description / Narration</label>
                        <input type="text" name="description" class="form-control" placeholder="Narration for this transaction">
                    </div>
                </div>

                <h6 class="fw-bold text-secondary border-bottom pb-2 mb-3">Ledger Entries (Minimum 2 Lines, Debits must equal Credits)</h6>
                <div id="ledgerLines">
                    <div class="row g-2 mb-2 line-row">
                        <div class="col-md-6">
                            <select name="account_id[]" class="form-select select2" required>
                                <option value="">-- Select Account --</option>
                                <?php foreach($accounts_list as $a): ?>
                                    <option value="<?php echo $a['id']; ?>"><?php echo e($a['code'] . ' - ' . $a['name']); ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div class="col-md-3">
                            <input type="number" step="0.01" name="debit[]" class="form-control debit-input" placeholder="Debit (Dr)" value="0">
                        </div>
                        <div class="col-md-3">
                            <input type="number" step="0.01" name="credit[]" class="form-control credit-input" placeholder="Credit (Cr)" value="0">
                        </div>
                    </div>
                    <div class="row g-2 mb-2 line-row">
                        <div class="col-md-6">
                            <select name="account_id[]" class="form-select select2" required>
                                <option value="">-- Select Account --</option>
                                <?php foreach($accounts_list as $a): ?>
                                    <option value="<?php echo $a['id']; ?>"><?php echo e($a['code'] . ' - ' . $a['name']); ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div class="col-md-3">
                            <input type="number" step="0.01" name="debit[]" class="form-control debit-input" placeholder="Debit (Dr)" value="0">
                        </div>
                        <div class="col-md-3">
                            <input type="number" step="0.01" name="credit[]" class="form-control credit-input" placeholder="Credit (Cr)" value="0">
                        </div>
                    </div>
                </div>
                <button type="button" class="btn btn-sm btn-outline-secondary mt-2" onclick="addLedgerLine()"><i class="fas fa-plus me-1"></i> Add Another Line</button>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" name="add_voucher" class="btn btn-primary fw-bold"><i class="fas fa-save me-1"></i> Save Voucher</button>
            </div>
        </form>
    </div>
</div>

<!-- Modal for View Voucher -->
<div class="modal fade" id="voucherModal" tabindex="-1">
    <div class="modal-dialog modal-lg">
        <div class="modal-content" id="voucherModalContent"></div>
    </div>
</div>

<script>
function addLedgerLine() {
    var div = document.createElement('div');
    div.className = 'row g-2 mb-2 line-row';
    div.innerHTML = `
        <div class="col-md-6">
            <select name="account_id[]" class="form-select" required>
                <option value="">-- Select Account --</option>
                <?php foreach($accounts_list as $a): ?>
                    <option value="<?php echo $a['id']; ?>"><?php echo e($a['code'] . ' - ' . $a['name']); ?></option>
                <?php endforeach; ?>
            </select>
        </div>
        <div class="col-md-3">
            <input type="number" step="0.01" name="debit[]" class="form-control debit-input" placeholder="Debit (Dr)" value="0">
        </div>
        <div class="col-md-3">
            <input type="number" step="0.01" name="credit[]" class="form-control credit-input" placeholder="Credit (Cr)" value="0">
        </div>
    `;
    document.getElementById('ledgerLines').appendChild(div);
}

function viewVoucher(id) {
    fetch('ajax_acc_voucher_details.php?id=' + id)
        .then(response => response.text())
        .then(html => {
            document.getElementById('voucherModalContent').innerHTML = html;
            new bootstrap.Modal(document.getElementById('voucherModal')).show();
        });
}
</script>

<?php include 'footer.php'; ?>
