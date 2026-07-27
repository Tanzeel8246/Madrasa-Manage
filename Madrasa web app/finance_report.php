<?php require_once 'db.php'; include 'header.php';

if (!app_has_perm('manage_finance')) {
    echo "<script>window.location='dashboard.php';</script>";
    exit;
}

$role = $_SESSION['role'] ?? 'guest';
$current_user_id = $_SESSION['user_id'] ?? 1;

$start_date = isset($_GET['from']) ? $_GET['from'] : date('Y-m-01');
$end_date = isset($_GET['to']) ? $_GET['to'] : date('Y-m-d');
$type_filter = isset($_GET['type']) ? $_GET['type'] : 'All';

// تمام ٹرانزیکشنز
if ($role === 'admin') {
    $sql = "SELECT f.*, h.name AS head_name FROM finance f LEFT JOIN heads h ON h.id = f.head_id WHERE f.date BETWEEN ? AND ? AND f.is_deleted = 0 ORDER BY f.user_id, f.date ASC, f.id ASC";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$start_date, $end_date]);
} else {
    $sql = "SELECT f.*, h.name AS head_name FROM finance f LEFT JOIN heads h ON h.id = f.head_id WHERE f.date BETWEEN ? AND ? AND f.is_deleted = 0 AND f.user_id = ? ORDER BY f.date ASC, f.id ASC";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$start_date, $end_date, $current_user_id]);
}
$all_rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

// یوزر وائز گروپ کریں
$by_user = [];
foreach ($all_rows as $row) {
    $uid = $row['user_id'] ?? 0;
    $uname = $row['user_name'] ?? 'نامعلوم';
    if (!isset($by_user[$uid])) {
        $by_user[$uid] = ['name' => $uname, 'income' => [], 'expense' => []];
    }
    if (strtolower((string)$row['type']) === 'expense') {
        $by_user[$uid]['expense'][] = $row;
    } else {
        $by_user[$uid]['income'][] = $row;
    }
}

// گرینڈ ٹوٹل
$grand_inc = 0; $grand_exp = 0;
foreach ($by_user as $u) {
    foreach ($u['income'] as $r) $grand_inc += (float)$r['amount'];
    foreach ($u['expense'] as $r) $grand_exp += (float)$r['amount'];
}
?>

<div class="d-print-none card p-3 mb-4 bg-light shadow-sm">
    <h4 class="mb-3 text-primary fw-bold"><i class="fas fa-file-invoice-dollar me-2"></i> فنانس رپورٹ (یوزر وائز)</h4>
    <form method="GET" class="row g-2 align-items-end">
        <div class="col-md-3">
            <label class="fw-bold">تاریخ (ابتداء)</label>
            <input type="date" name="from" class="form-control" value="<?php echo $start_date; ?>">
        </div>
        <div class="col-md-3">
            <label class="fw-bold">تاریخ (اختتام)</label>
            <input type="date" name="to" class="form-control" value="<?php echo $end_date; ?>">
        </div>
        <div class="col-md-3">
            <label class="fw-bold">قسم</label>
            <select name="type" class="form-select">
                <option value="All" <?php echo ($type_filter=='All')?'selected':''; ?>>مکمل (All)</option>
                <option value="Income" <?php echo ($type_filter=='Income')?'selected':''; ?>>آمدن (Income)</option>
                <option value="Expense" <?php echo ($type_filter=='Expense')?'selected':''; ?>><?php echo t('type_expense'); ?></option>
            </select>
        </div>
        <div class="col-md-3">
            <button type="submit" class="btn btn-primary w-100 mb-1">تلاش کریں</button>
            <button type="button" onclick="window.print()" class="btn btn-dark w-100">پرنٹ کریں</button>
        </div>
    </form>
</div>

<div id="printableArea" class="bg-white p-4 border rounded">
    <div class="text-center border-bottom border-2 border-dark mb-4 pb-2">
        <h2 class="fw-bold text-success m-0">مدرسہ اشرف المدارس</h2>
        <h4 class="mt-2 text-uppercase fw-bold">فنانس رپورٹ (یوزر وائز)</h4>
        <p class="text-muted mb-1">
            مدت: <strong><?php echo date('d-m-Y', strtotime($start_date)); ?></strong> تا <strong><?php echo date('d-m-Y', strtotime($end_date)); ?></strong>
        </p>
    </div>

    <?php foreach ($by_user as $uid => $user_data): ?>
    <?php
        $u_inc = array_sum(array_column($user_data['income'], 'amount'));
        $u_exp = array_sum(array_column($user_data['expense'], 'amount'));
        $u_bal = $u_inc - $u_exp;
    ?>
    <div class="mb-5 border rounded p-3">
$current_user_id = $_SESSION['user_id'] ?? 1;

$start_date = isset($_GET['from']) ? $_GET['from'] : date('Y-m-01');
$end_date = isset($_GET['to']) ? $_GET['to'] : date('Y-m-d');
$type_filter = isset($_GET['type']) ? $_GET['type'] : 'All';

// تمام ٹرانزیکشنز
if ($role === 'admin') {
    $sql = "SELECT f.*, h.name AS head_name FROM finance f LEFT JOIN heads h ON h.id = f.head_id WHERE f.date BETWEEN ? AND ? AND f.is_deleted = 0 ORDER BY f.user_id, f.date ASC, f.id ASC";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$start_date, $end_date]);
} else {
    $sql = "SELECT f.*, h.name AS head_name FROM finance f LEFT JOIN heads h ON h.id = f.head_id WHERE f.date BETWEEN ? AND ? AND f.is_deleted = 0 AND f.user_id = ? ORDER BY f.date ASC, f.id ASC";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$start_date, $end_date, $current_user_id]);
}
$all_rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

// یوزر وائز گروپ کریں
$by_user = [];
foreach ($all_rows as $row) {
    $uid = $row['user_id'] ?? 0;
    $uname = $row['user_name'] ?? 'نامعلوم';
    if (!isset($by_user[$uid])) {
        $by_user[$uid] = ['name' => $uname, 'income' => [], 'expense' => []];
    }
    if (strtolower((string)$row['type']) === 'expense') {
        $by_user[$uid]['expense'][] = $row;
    } else {
        $by_user[$uid]['income'][] = $row;
    }
}

// گرینڈ ٹوٹل
$grand_inc = 0; $grand_exp = 0;
foreach ($by_user as $u) {
    foreach ($u['income'] as $r) $grand_inc += (float)$r['amount'];
    foreach ($u['expense'] as $r) $grand_exp += (float)$r['amount'];
}
?>

<div class="d-print-none card p-3 mb-4 bg-light shadow-sm">
    <h4 class="mb-3 text-primary fw-bold"><i class="fas fa-file-invoice-dollar me-2"></i> فنانس رپورٹ (یوزر وائز)</h4>
    <form method="GET" class="row g-2 align-items-end">
        <div class="col-md-3">
            <label class="fw-bold">تاریخ (ابتداء)</label>
            <input type="date" name="from" class="form-control" value="<?php echo $start_date; ?>">
        </div>
        <div class="col-md-3">
            <label class="fw-bold">تاریخ (اختتام)</label>
            <input type="date" name="to" class="form-control" value="<?php echo $end_date; ?>">
        </div>
        <div class="col-md-3">
            <label class="fw-bold">قسم</label>
            <select name="type" class="form-select">
                <option value="All" <?php echo ($type_filter=='All')?'selected':''; ?>>مکمل (All)</option>
                <option value="Income" <?php echo ($type_filter=='Income')?'selected':''; ?>>آمدن (Income)</option>
                <option value="Expense" <?php echo ($type_filter=='Expense')?'selected':''; ?>><?php echo t('type_expense'); ?></option>
            </select>
        </div>
        <div class="col-md-3">
            <button type="submit" class="btn btn-primary w-100 mb-1">تلاش کریں</button>
            <button type="button" onclick="window.print()" class="btn btn-dark w-100">پرنٹ کریں</button>
        </div>
    </form>
</div>

<div id="printableArea" class="bg-white p-4 border rounded">
    <div class="text-center border-bottom border-2 border-dark mb-4 pb-2">
        <h2 class="fw-bold text-success m-0">مدرسہ اشرف المدارس</h2>
        <h4 class="mt-2 text-uppercase fw-bold">فنانس رپورٹ (یوزر وائز)</h4>
        <p class="text-muted mb-1">
            مدت: <strong><?php echo date('d-m-Y', strtotime($start_date)); ?></strong> تا <strong><?php echo date('d-m-Y', strtotime($end_date)); ?></strong>
        </p>
    </div>

    <?php foreach ($by_user as $uid => $user_data): ?>
    <?php
        $u_inc = array_sum(array_column($user_data['income'], 'amount'));
        $u_exp = array_sum(array_column($user_data['expense'], 'amount'));
        $u_bal = $u_inc - $u_exp;
    ?>
    <div class="mb-5 border rounded p-3">
        <!-- یوزر ہیڈر -->
        <div class="finance-user-header d-flex justify-content-between align-items-center bg-dark text-white p-2 rounded mb-3">
            <h5 class="finance-user-name mb-0 text-white"><i class="fas fa-user-circle me-2"></i> <?php echo htmlspecialchars($user_data['name']); ?></h5>
    <?php endforeach; ?>

    <?php if ($role === 'admin'): ?>
    <!-- گرینڈ ٹوٹل سمری -->
    <div class="row mt-4 avoid-break">
        <div class="col-md-6 ms-auto">
            <div class="card border-dark">
                <div class="card-header bg-dark text-white text-center fw-bold">حتمی خلاصہ - تمام یوزرز (Grand Summary)</div>
                <div class="card-body p-0">
                    <table class="table table-bordered mb-0">
                        <?php if($type_filter == 'All' || $type_filter == 'Income'): ?>
                        <tr>
                            <td class="text-success fw-bold ps-3 fs-5">کل آمدن (Total Income)</td>
                            <td class="text-end pe-3 fs-5 fw-bold"><?php echo number_format($grand_inc); ?></td>
                        </tr>
                        <?php endif; ?>
                        <?php if($type_filter == 'All' || $type_filter == 'Expense'): ?>
                        <tr>
                            <td class="text-danger fw-bold ps-3 fs-5">کل خرچ (Total Expense)</td>
                            <td class="text-end pe-3 fs-5 fw-bold"><?php echo number_format($grand_exp); ?></td>
                        </tr>
                        <?php endif; ?>
                        <?php if($type_filter == 'All'): ?>
                        <tr class="bg-light">
                            <th class="text-primary ps-3 fs-4">بچت / موجودہ بیلنس</th>
                            <th class="text-end pe-3 fs-4"><?php echo number_format($grand_inc - $grand_exp); ?></th>
                        </tr>
                        <?php endif; ?>
                    </table>
                </div>
            </div>
        </div>
    </div>
    <?php endif; ?>

    <div class="row mt-5 pt-5 text-center avoid-break">
        <div class="col-4 border-top border-dark pt-2 fw-bold">اکاؤنٹنٹ</div>
        <div class="col-4"></div>
        <div class="col-4 border-top border-dark pt-2 fw-bold">مہتمم / ناظم</div>
    </div>
    <div class="text-center mt-4 small text-muted">
        تاریخ تیاری: <?php echo date('d-m-Y H:i A'); ?>
    </div>
</div>

<style>
#printableArea { font-family: 'Noto Nastaliq Urdu', serif !important; font-style: normal !important; }
#printableArea .finance-user-header,
#printableArea .finance-user-header * { color: #fff !important; }
#printableArea .finance-user-header .badge { font-weight: 800; border: 1px solid transparent !important; }
#printableArea .finance-user-header .bg-success { background: #e7f6e8 !important; color: #10712f !important; border-color: #9bd3a5 !important; }
#printableArea .finance-user-header .bg-danger { background: #fde8eb !important; color: #b4232f !important; border-color: #f3a6ae !important; }
#printableArea .finance-user-header .bg-primary { background: #08284d !important; color: #fff !important; border-color: #356694 !important; }
#printableArea .finance-user-header .bg-warning { background: #fff3cd !important; color: #5f4200 !important; border-color: #e8c76d !important; }
@media print {
    @page { size: A4 portrait; margin: 10mm; }
    body * { visibility: hidden; }
    #printableArea, #printableArea * { visibility: visible; }
    #printableArea { position: absolute; left: 0; top: 0; width: 100%; border: none !important; }
    .d-print-none, .sidebar, .navbar { display: none !important; }
    body { -webkit-print-color-adjust: exact; }
    table { width: 100% !important; border-collapse: collapse; }
    th, td { border: 1px solid #000 !important; padding: 5px; font-style: normal !important; }
    .avoid-break { page-break-inside: avoid; }
    .border { border: 1px solid #999 !important; }
    .finance-user-header { background: #111 !important; }
    .finance-user-header,
    .finance-user-header * { color: #fff !important; }
    .finance-user-header .badge { font-weight: 800; border: 1px solid transparent !important; }
    .finance-user-header .bg-success { background: #e7f6e8 !important; color: #10712f !important; border-color: #9bd3a5 !important; }
    .finance-user-header .bg-danger { background: #fde8eb !important; color: #b4232f !important; border-color: #f3a6ae !important; }
    .finance-user-header .bg-primary { background: #08284d !important; color: #fff !important; border-color: #356694 !important; }
    .finance-user-header .bg-warning { background: #fff3cd !important; color: #5f4200 !important; border-color: #e8c76d !important; }
    .badge { border: 1px solid #333 !important; }
}
</style>

<?php include 'footer.php'; ?>
