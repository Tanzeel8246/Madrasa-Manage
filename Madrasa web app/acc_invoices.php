<?php
require_once 'db.php';
require_once __DIR__ . '/finance_accounting_bridge.php';
session_start();

if (!isset($_SESSION['user_id']) || !app_has_perm('manage_erp')) {
    header("Location: dashboard.php");
    exit;
}
$role = $_SESSION['role'] ?? '';
$user = ['id' => $_SESSION['user_id'], 'role' => $role];

$cur_tenant_id = get_current_tenant_id($pdo);

// Create table if not exists
try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS acc_invoices (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id INT NOT NULL DEFAULT 1,
        student_id INT NOT NULL,
        invoice_no VARCHAR(50),
        month_year VARCHAR(20),
        amount DECIMAL(15,2),
        status ENUM('Unpaid', 'Paid', 'Cancelled') DEFAULT 'Unpaid',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_by INT,
        INDEX (tenant_id)
    )");
} catch (Exception $e) {}

// Handle Generation
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['generate_invoices'])) {
    $month_year = $_POST['month_year'] ?? date('Y-m');
    $amount = (float)($_POST['default_amount'] ?? 0);
    $uid = $_SESSION['user_id'];
    
    if ($amount > 0) {
        $st_stmt = $pdo->prepare("SELECT id, name FROM students WHERE status = 'Active' AND (is_deleted = 0 OR is_deleted IS NULL) AND tenant_id = ?");
        $st_stmt->execute([$cur_tenant_id]);
        $students = $st_stmt->fetchAll(PDO::FETCH_ASSOC);

        foreach ($students as $st) {
            $check = $pdo->prepare("SELECT id FROM acc_invoices WHERE student_id = ? AND month_year = ? AND tenant_id = ?");
            $check->execute([$st['id'], $month_year, $cur_tenant_id]);
            if ($check->rowCount() == 0) {
                // Check active hostel allocation
                $hostel_fee = 0.0;
                try {
                    $hStmt = $pdo->prepare("SELECT a.*, r.monthly_fee, r.room_number FROM hostel_allocations a JOIN hostel_rooms r ON a.room_id = r.id WHERE a.student_id = ? AND a.tenant_id = ? AND a.status = 'Occupied' AND (a.is_deleted = 0 OR a.is_deleted IS NULL) LIMIT 1");
                    $hStmt->execute([$st['id'], $cur_tenant_id]);
                    $hRoom = $hStmt->fetch(PDO::FETCH_ASSOC);
                    if ($hRoom && !empty($hRoom['monthly_fee'])) {
                        $hostel_fee = (float)$hRoom['monthly_fee'];
                    }
                } catch (Exception $e) {}

                $final_amount = $amount + $hostel_fee;
                $inv_no = "INV-" . date('ym') . "-" . rand(1000, 9999);
                $stmt = $pdo->prepare("INSERT INTO acc_invoices (student_id, invoice_no, month_year, amount, status, created_by, tenant_id) VALUES (?, ?, ?, ?, 'Unpaid', ?, ?)");
                $stmt->execute([$st['id'], $inv_no, $month_year, $final_amount, $uid, $cur_tenant_id]);
                $inv_id = (int)$pdo->lastInsertId();

                // D9 Golden Accounting Rule: Auto-post Accrual Journal Voucher
                // Dr 11001 Student Fees Receivable / Cr 40001 Fee Income
                try {
                    $recAccId = finance_accounting_ensure_account($pdo, '11001', 'Student Fees Receivable', 'Asset', $cur_tenant_id);
                    $feeIncId = finance_accounting_ensure_account($pdo, '40001', 'Fee Income', 'Revenue', $cur_tenant_id);
                    $invDate = date('Y-m-01', strtotime($month_year . '-01'));
                    $vRef = 'INV-ACCRUAL-' . $inv_id;
                    $vNo = 'JV-INV-' . str_pad((string)$inv_id, 6, '0', STR_PAD_LEFT);
                    $vDesc = "Fee invoice generated: $inv_no ({$st['name']} - $month_year)";

                    $vStmt = $pdo->prepare("INSERT INTO acc_vouchers (voucher_no, date, type, reference, description, status, created_by, tenant_id, is_deleted) VALUES (?, ?, 'Journal', ?, ?, 'Approved', ?, ?, 0)");
                    $vStmt->execute([$vNo, $invDate, $vRef, $vDesc, $uid, $cur_tenant_id]);
                    $vId = (int)$pdo->lastInsertId();

                    $lStmt = $pdo->prepare("INSERT INTO acc_ledger_entries (voucher_id, account_id, debit, credit, tenant_id) VALUES (?, ?, ?, ?, ?)");
                    $lStmt->execute([$vId, $recAccId, $final_amount, 0, $cur_tenant_id]);
                    $lStmt->execute([$vId, $feeIncId, 0, $final_amount, $cur_tenant_id]);
                } catch (Throwable $eAcc) {}
            }
        }
        $msg = "Invoices generated successfully for $month_year (Hostel charges auto-included where applicable)!";
    }
}

// Handle Individual Invoice Generation
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['generate_single_invoice'])) {
    $student_id = (int)($_POST['student_id'] ?? 0);
    $month_year = trim($_POST['month_year'] ?? date('Y-m'));
    $amount = (float)($_POST['amount'] ?? 0);
    $uid = (int)($_SESSION['user_id'] ?? 1);

    if ($student_id > 0 && $amount > 0) {
        $st_stmt = $pdo->prepare("SELECT id, name FROM students WHERE id = ? AND tenant_id = ? LIMIT 1");
        $st_stmt->execute([$student_id, $cur_tenant_id]);
        $st = $st_stmt->fetch(PDO::FETCH_ASSOC);

        if ($st) {
            $inv_no = "INV-" . date('ym') . "-" . rand(1000, 9999);
            $stmt = $pdo->prepare("INSERT INTO acc_invoices (student_id, invoice_no, month_year, amount, status, created_by, tenant_id) VALUES (?, ?, ?, ?, 'Unpaid', ?, ?)");
            $stmt->execute([$st['id'], $inv_no, $month_year, $amount, $uid, $cur_tenant_id]);
            $inv_id = (int)$pdo->lastInsertId();

            try {
                $recAccId = finance_accounting_ensure_account($pdo, '11001', 'Student Fees Receivable', 'Asset', $cur_tenant_id);
                $feeIncId = finance_accounting_ensure_account($pdo, '40001', 'Fee Income', 'Revenue', $cur_tenant_id);
                $invDate = date('Y-m-01', strtotime($month_year . '-01'));
                $vRef = 'INV-ACCRUAL-' . $inv_id;
                $vNo = 'JV-INV-' . str_pad((string)$inv_id, 6, '0', STR_PAD_LEFT);
                $vDesc = "Fee invoice generated: $inv_no ({$st['name']} - $month_year)";

                $vStmt = $pdo->prepare("INSERT INTO acc_vouchers (voucher_no, date, type, reference, description, status, created_by, tenant_id, is_deleted) VALUES (?, ?, 'Journal', ?, ?, 'Approved', ?, ?, 0)");
                $vStmt->execute([$vNo, $invDate, $vRef, $vDesc, $uid, $cur_tenant_id]);
                $vId = (int)$pdo->lastInsertId();

                $lStmt = $pdo->prepare("INSERT INTO acc_ledger_entries (voucher_id, account_id, debit, credit, tenant_id) VALUES (?, ?, ?, ?, ?)");
                $lStmt->execute([$vId, $recAccId, $amount, 0, $cur_tenant_id]);
                $lStmt->execute([$vId, $feeIncId, 0, $amount, $cur_tenant_id]);
            } catch (Throwable $eAcc) {}

            $msg = ($lang === 'ur') ? "طالب علم {$st['name']} کی انوائس کامیابی سے بن گئی!" : "Invoice generated successfully for {$st['name']}!";
        }
    }
}

// Update Status (Mark Paid)
if (isset($_GET['mark_paid']) && is_numeric($_GET['mark_paid'])) {
    $inv_id = (int)$_GET['mark_paid'];
    $chkStmt = $pdo->prepare("SELECT i.*, s.name as student_name FROM acc_invoices i JOIN students s ON i.student_id = s.id WHERE i.id = ? AND i.tenant_id = ? LIMIT 1");
    $chkStmt->execute([$inv_id, $cur_tenant_id]);
    $inv = $chkStmt->fetch(PDO::FETCH_ASSOC);

    if ($inv && $inv['status'] !== 'Paid') {
        $pdo->prepare("UPDATE acc_invoices SET status = 'Paid' WHERE id = ? AND tenant_id = ?")->execute([$inv_id, $cur_tenant_id]);

        // D9 Golden Accounting Rule: Auto-post Settlement Receipt Voucher
        // Dr 1001 Cash in Hand / Cr 1101 Student Fees Receivable
        try {
            $cashAccId = finance_accounting_ensure_account($pdo, '10001', 'Cash in Hand', 'Asset', $cur_tenant_id);
            $recAccId = finance_accounting_ensure_account($pdo, '11001', 'Student Fees Receivable', 'Asset', $cur_tenant_id);
            $payDate = date('Y-m-d');
            $vRef = 'INV-PAYMENT-' . $inv_id;
            $vNo = 'RV-INV-' . str_pad((string)$inv_id, 6, '0', STR_PAD_LEFT);
            $vDesc = "Fee invoice payment: {$inv['invoice_no']} ({$inv['student_name']} - {$inv['month_year']})";
            $payAmt = (float)$inv['amount'];

            $vStmt = $pdo->prepare("INSERT INTO acc_vouchers (voucher_no, date, type, reference, description, status, created_by, tenant_id, is_deleted) VALUES (?, ?, 'Receipt', ?, ?, 'Approved', ?, ?, 0)");
            $vStmt->execute([$vNo, $payDate, $vRef, $vDesc, (int)($_SESSION['user_id'] ?? 1), $cur_tenant_id]);
            $vId = (int)$pdo->lastInsertId();

            $lStmt = $pdo->prepare("INSERT INTO acc_ledger_entries (voucher_id, account_id, debit, credit, tenant_id) VALUES (?, ?, ?, ?, ?)");
            $lStmt->execute([$vId, $cashAccId, $payAmt, 0, $cur_tenant_id]);
            $lStmt->execute([$vId, $recAccId, 0, $payAmt, $cur_tenant_id]);
        } catch (Throwable $ePay) {}
    }

    header("Location: acc_invoices.php");
    exit;
}

// Auto-backfill ledger entries for any unposted invoices to guarantee 11001 ledger presence
try {
    $recAccId = finance_accounting_ensure_account($pdo, '11001', 'Student Fees Receivable', 'Asset', $cur_tenant_id);
    $feeIncId = finance_accounting_ensure_account($pdo, '40001', 'Fee Income', 'Revenue', $cur_tenant_id);

    $unpostedInvs = $pdo->prepare("
        SELECT i.*, s.name as student_name 
        FROM acc_invoices i
        LEFT JOIN students s ON i.student_id = s.id
        WHERE i.tenant_id = ? AND i.amount > 0
    ");
    $unpostedInvs->execute([$cur_tenant_id]);
    $allInvs = $unpostedInvs->fetchAll(PDO::FETCH_ASSOC);

    foreach ($allInvs as $inv) {
        $inv_id = (int)$inv['id'];
        $vRef = 'INV-ACCRUAL-' . $inv_id;
        $checkV = $pdo->prepare("SELECT id FROM acc_vouchers WHERE reference = ? AND tenant_id = ? AND (is_deleted = 0 OR is_deleted IS NULL) LIMIT 1");
        $checkV->execute([$vRef, $cur_tenant_id]);
        if (!$checkV->fetchColumn()) {
            $invDate = date('Y-m-01', strtotime(($inv['month_year'] ?? date('Y-m')) . '-01'));
            $vNo = 'JV-INV-' . str_pad((string)$inv_id, 6, '0', STR_PAD_LEFT);
            $stName = $inv['student_name'] ?? ('Student #' . $inv['student_id']);
            $vDesc = "Fee invoice generated: {$inv['invoice_no']} ({$stName} - {$inv['month_year']})";
            $vStmt = $pdo->prepare("INSERT INTO acc_vouchers (voucher_no, date, type, reference, description, status, created_by, tenant_id, is_deleted) VALUES (?, ?, 'Journal', ?, ?, 'Approved', ?, ?, 0)");
            $vStmt->execute([$vNo, $invDate, $vRef, $vDesc, (int)($_SESSION['user_id'] ?? 1), $cur_tenant_id]);
            $vId = (int)$pdo->lastInsertId();

            $lStmt = $pdo->prepare("INSERT INTO acc_ledger_entries (voucher_id, account_id, debit, credit, tenant_id) VALUES (?, ?, ?, ?, ?)");
            $lStmt->execute([$vId, $recAccId, (float)$inv['amount'], 0, $cur_tenant_id]);
            $lStmt->execute([$vId, $feeIncId, 0, (float)$inv['amount'], $cur_tenant_id]);
        }
    }
} catch (Throwable $eBf) {}

// Fetch active students for individual invoice generation
$studentList = [];
try {
    $stdStmt = $pdo->prepare("SELECT id, name, admission_number, class FROM students WHERE tenant_id = ? AND (is_deleted = 0 OR is_deleted IS NULL) AND (LOWER(TRIM(status)) IN ('active', 'present', 'حاضر', '') OR status IS NULL) ORDER BY name ASC");
    $stdStmt->execute([$cur_tenant_id]);
    $studentList = $stdStmt->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $eStd) {}

$inv_stmt = $pdo->prepare("
    SELECT i.*, s.name as student_name, s.admission_number 
    FROM acc_invoices i
    JOIN students s ON i.student_id = s.id
    WHERE (s.is_deleted = 0 OR s.is_deleted IS NULL) AND i.tenant_id = ? AND s.tenant_id = ?
    ORDER BY i.id DESC LIMIT 100
");
$inv_stmt->execute([$cur_tenant_id, $cur_tenant_id]);
$invoices = $inv_stmt->fetchAll(PDO::FETCH_ASSOC);

$title = "Fee Invoices - ERP";
include 'header.php';
?>

<div class="container py-4">
    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
        <h3 class="fw-bold text-warning mb-0"><i class="fas fa-file-invoice me-2"></i> <?php echo t('fee_invoices'); ?></h3>
        <div class="d-flex gap-2">
            <button class="btn btn-outline-warning fw-bold text-dark shadow-sm" data-bs-toggle="modal" data-bs-target="#singleInvoiceModal">
                <i class="fas fa-user-plus me-1"></i> <?php echo ($lang === 'ur') ? 'انفرادی انوائس' : 'Individual Invoice'; ?>
            </button>
            <button class="btn btn-warning fw-bold text-dark shadow" data-bs-toggle="modal" data-bs-target="#generateModal">
                <i class="fas fa-magic me-1"></i> <?php echo t('generate'); ?>
            </button>
        </div>
    </div>

    <?php if(isset($msg)): ?>
    <div class="alert alert-success shadow-sm"><i class="fas fa-check-circle me-2"></i> <?php echo $msg; ?></div>
    <?php endif; ?>

    <div class="card shadow-sm border-0 neobox">
        <div class="card-body p-4">
            <div class="table-responsive">
                <table class="table table-hover align-middle table-sm">
                    <thead class="table-light">
                        <tr>
                            <th><?php echo t('invoice_no'); ?></th>
                            <th><?php echo t('month'); ?></th>
                            <th><?php echo t('student'); ?></th>
                            <th><?php echo t('amount'); ?></th>
                            <th><?php echo t('status'); ?></th>
                            <th><?php echo t('actions'); ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach($invoices as $inv): ?>
                        <tr>
                            <td class="fw-bold text-primary"><?php echo htmlspecialchars($inv['invoice_no']); ?></td>
                            <td><span class="badge bg-secondary"><?php echo htmlspecialchars($inv['month_year']); ?></span></td>
                            <td><?php echo htmlspecialchars($inv['student_name']); ?> <small class="text-muted">(<?php echo htmlspecialchars($inv['admission_number']); ?>)</small></td>
                            <td class="fw-bold">Rs. <?php echo number_format($inv['amount'], 2); ?></td>
                            <td>
                                <?php if($inv['status'] == 'Paid'): ?>
                                    <span class="badge bg-success"><i class="fas fa-check"></i> <?php echo t('paid'); ?></span>
                                <?php elseif($inv['status'] == 'Cancelled'): ?>
                                    <span class="badge bg-danger"><?php echo t('cancelled'); ?></span>
                                <?php else: ?>
                                    <span class="badge bg-warning text-dark"><i class="fas fa-clock"></i> <?php echo t('unpaid'); ?></span>
                                <?php endif; ?>
                            </td>
                            <td>
                                <?php if($inv['status'] == 'Unpaid'): ?>
                                    <a href="?mark_paid=<?php echo $inv['id']; ?>" class="btn btn-sm btn-success" title="Mark as Paid" onclick="return confirm('Confirm payment received?')"><i class="fas fa-check"></i></a>
                                <?php endif; ?>
                                <button class="btn btn-sm btn-outline-primary" onclick="window.print()" title="Print"><i class="fas fa-print"></i></button>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                        <?php if(empty($invoices)): ?>
                        <tr><td colspan="6" class="text-center text-muted py-4"><?php echo t('no_invoices_found'); ?></td></tr>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<!-- Generate Modal -->
<div class="modal fade" id="generateModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <form method="POST">
                <div class="modal-header bg-warning text-dark">
                    <h5 class="modal-title fw-bold"><i class="fas fa-magic me-2"></i> <?php echo t('generate_bulk_invoices'); ?></h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="mb-3">
                        <label class="fw-bold mb-1"><?php echo t('invoice_month'); ?></label>
                        <input type="month" name="month_year" class="form-control" value="<?php echo date('Y-m'); ?>" required>
                    </div>
                    <div class="mb-3">
                        <label class="fw-bold mb-1"><?php echo t('default_fee_amount'); ?></label>
                        <input type="number" step="0.01" name="default_amount" class="form-control" required placeholder="e.g. 1500">
                        <small class="text-muted"><?php echo t('billed_to_all'); ?></small>
                    </div>
                </div>
                <div class="modal-footer bg-light">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal"><?php echo t('cancel'); ?></button>
                    <button type="submit" name="generate_invoices" class="btn btn-warning fw-bold text-dark"><i class="fas fa-cogs me-1"></i> <?php echo t('generate_now'); ?></button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Individual Invoice Modal -->
<div class="modal fade" id="singleInvoiceModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <form method="POST">
                <div class="modal-header bg-warning text-dark">
                    <h5 class="modal-title fw-bold"><i class="fas fa-user-plus me-2"></i> <?php echo ($lang === 'ur') ? 'انفرادی انوائس جنریٹ کریں' : 'Generate Individual Invoice'; ?></h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body" dir="<?php echo ($lang === 'ur') ? 'rtl' : 'ltr'; ?>">
                    <div class="mb-3">
                        <label class="fw-bold mb-1"><?php echo ($lang === 'ur') ? 'طالب علم منتخب کریں' : 'Select Student'; ?> <span class="text-danger">*</span></label>
                        <select name="student_id" class="form-select select2" required>
                            <option value=""><?php echo ($lang === 'ur') ? '-- طالب علم منتخب کریں --' : '-- Choose Student --'; ?></option>
                            <?php foreach ($studentList as $stItem): ?>
                                <option value="<?php echo $stItem['id']; ?>">
                                    <?php echo htmlspecialchars($stItem['name']); ?> (رول: <?php echo htmlspecialchars($stItem['admission_number']); ?> - کلاس: <?php echo htmlspecialchars($stItem['class']); ?>)
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div class="mb-3">
                        <label class="fw-bold mb-1"><?php echo t('invoice_month'); ?> <span class="text-danger">*</span></label>
                        <input type="month" name="month_year" class="form-control" value="<?php echo date('Y-m'); ?>" required>
                    </div>
                    <div class="mb-3">
                        <label class="fw-bold mb-1"><?php echo ($lang === 'ur') ? 'فیس کی رقم (Rs.)' : 'Fee Amount (Rs.)'; ?> <span class="text-danger">*</span></label>
                        <input type="number" step="0.01" name="amount" class="form-control fw-bold" required placeholder="مثلاً: 2000">
                    </div>
                </div>
                <div class="modal-footer bg-light">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal"><?php echo t('cancel'); ?></button>
                    <button type="submit" name="generate_single_invoice" class="btn btn-warning fw-bold text-dark"><i class="fas fa-check-circle me-1"></i> <?php echo ($lang === 'ur') ? 'انوائس تیار کریں' : 'Create Invoice'; ?></button>
                </div>
            </form>
        </div>
    </div>
</div>

<?php include 'footer.php'; ?>
