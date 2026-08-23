<?php
require_once 'db.php';
require_once 'finance_accounting_bridge.php';
session_start();

if (!isset($_SESSION['user_id']) || !app_has_perm('manage_finance')) {
    header("Location: dashboard.php");
    exit;
}

$user_id = $_SESSION['user_id'];
$user_name = $_SESSION['name'] ?? 'Admin';

function next_user_receipt_no(PDO $pdo, $userId) {
    $userId = max(1, (int)$userId);
    $minNo = $userId * 100000;
    $maxNo = ($userId + 1) * 100000;
    $stmt = $pdo->prepare("SELECT MAX(computer_receipt_no) FROM finance WHERE computer_receipt_no > ? AND computer_receipt_no < ?");
    $stmt->execute([$minNo, $maxNo]);
    $currentMax = (int)$stmt->fetchColumn();
    $nextNo = ($currentMax > $minNo) ? ($currentMax + 1) : ($minNo + 1);
    if ($nextNo >= $maxNo) {
        throw new Exception("Receipt number quota exhausted for this user.");
    }
    return $nextNo;
}

// Delete
if (isset($_GET['del_id'])) {
    $delId = (int)$_GET['del_id'];
    $pdo->prepare("UPDATE finance SET is_deleted = 1 WHERE id = ?")->execute([$delId]);
    finance_accounting_delete_voucher($pdo, $delId);
    header("Location: simple_finance.php?msg=deleted");
    exit;
}

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['add_record'])) {
    $type = $_POST['type'];
    $date = $_POST['date'];
    $head_id = (int)$_POST['head_id'];
    $amount = (float)$_POST['amount'];
    $donor_name = $_POST['donor_name'];
    $donor_address = $_POST['donor_address'] ?? '';
    $manual_receipt_no = $_POST['manual_receipt_no'];
    $description = $_POST['description'];
    
    $comp_receipt_no = ($type == 'Income') ? next_user_receipt_no($pdo, $user_id) : null;
    
    $stmt = $pdo->prepare("INSERT INTO finance (user_id, user_name, type, head_id, amount, date, donor_name, donor_address, manual_receipt_no, computer_receipt_no, description, is_deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)");
    $stmt->execute([$user_id, $user_name, $type, $head_id, $amount, $date, $donor_name, $donor_address, $manual_receipt_no, $comp_receipt_no, $description]);
    finance_accounting_post($pdo, (int)$pdo->lastInsertId());
    header("Location: simple_finance.php?msg=added");
    exit;
}

// Add new head
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['add_head'])) {
    $head_name = trim($_POST['head_name']);
    $head_type = $_POST['head_type'];
    if (!empty($head_name) && !empty($head_type)) {
        $stmt = $pdo->prepare("INSERT INTO heads (name, type) VALUES (?, ?)");
        $stmt->execute([$head_name, $head_type]);
        header("Location: simple_finance.php?msg=head_added");
        exit;
    }
}


// Fetch heads
sync_all_heads_with_chart_and_departments($pdo);
$heads = $pdo->query("SELECT * FROM heads WHERE is_deleted = 0 ORDER BY name ASC")->fetchAll(PDO::FETCH_ASSOC);

// Fetch recent records
$limit_val = isset($_GET['all']) ? 5000 : 500;
if (($_SESSION['role'] ?? '') === 'admin') {
    $records = $pdo->query("SELECT f.*, h.name as head_name FROM finance f LEFT JOIN heads h ON f.head_id = h.id WHERE f.is_deleted = 0 ORDER BY f.date DESC, f.id DESC LIMIT $limit_val")->fetchAll(PDO::FETCH_ASSOC);
} else {
    $current_user_id = intval($_SESSION['user_id'] ?? 0);
    $records = $pdo->query("SELECT f.*, h.name as head_name FROM finance f LEFT JOIN heads h ON f.head_id = h.id WHERE f.is_deleted = 0 AND f.user_id = $current_user_id ORDER BY f.date DESC, f.id DESC LIMIT $limit_val")->fetchAll(PDO::FETCH_ASSOC);
}

$title = "Simple Finance";
include 'header.php';
?>

<div class="container-fluid py-4">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h3 class="fw-bold text-primary"><i class="fas fa-coins me-2"></i> سادہ آمدن و اخراجات</h3>
        <div>
            <a href="finance_report.php" class="btn btn-outline-primary"><i class="fas fa-chart-bar me-1"></i> فنانس رپورٹ</a>
        </div>
    </div>

    <?php if(isset($_GET['msg'])): ?>
    <div class="alert alert-success">✅ کارروائی کامیابی سے مکمل ہو گئی۔</div>
    <?php endif; ?>

    <div class="row">
        <!-- Add Record Form -->
        <div class="col-md-4">
            <div class="card shadow-sm border-0 neobox mb-4">
                <div class="card-header bg-primary text-white">
                    <h5 class="mb-0 fw-bold"><i class="fas fa-plus-circle me-2"></i> نیا ریکارڈ درج کریں</h5>
                </div>
                <div class="card-body">
                    <form method="POST">
                        <div class="mb-3">
                            <label class="fw-bold">قسم (Type)</label>
                            <select name="type" class="form-select" id="record_type" onchange="onTypeChange()" required>
                                <option value="Income">آمدن (Income)</option>
                                <option value="Expense">اخراجات (Expense)</option>
                            </select>
                        </div>
                        <div class="mb-3">
                            <label class="fw-bold">تاریخ</label>
                            <input type="date" name="date" class="form-control" value="<?php echo date('Y-m-d'); ?>" required>
                        </div>
                        <div class="mb-3">
                            <label class="fw-bold">مد (Head)</label>
                            <div class="input-group">
                                <select name="head_id" class="form-select" id="head_id" required>
                                    <option value="">مد منتخب کریں</option>
                                    <?php foreach($heads as $h): ?>
                                        <option value="<?php echo $h['id']; ?>" data-type="<?php echo htmlspecialchars($h['type'] ?? ''); ?>"><?php echo htmlspecialchars($h['name']); ?></option>
                                    <?php endforeach; ?>
                                </select>
                                <button type="button" class="btn btn-outline-secondary" data-bs-toggle="modal" data-bs-target="#addHeadModal" title="نئی مد شامل کریں">
                                    <i class="fas fa-plus"></i>
                                </button>
                            </div>
                        </div>
                        <div class="mb-3">
                            <label class="fw-bold">رقم (Amount)</label>
                            <input type="number" name="amount" class="form-control" required>
                        </div>
                        
                        <div id="donor_fields">
                            <div class="mb-3">
                                <label class="fw-bold">دینے والے کا نام</label>
                                <input type="text" name="donor_name" class="form-control">
                            </div>
                            <div class="mb-3">
                                <label class="fw-bold">پتہ (Address)</label>
                                <input type="text" name="donor_address" class="form-control">
                            </div>
                            <div class="mb-3">
                                <label class="fw-bold">دستی رسید نمبر (Manual Receipt No)</label>
                                <input type="text" name="manual_receipt_no" class="form-control">
                            </div>
                        </div>

                        <div class="mb-3">
                            <label class="fw-bold">تفصیل (Description)</label>
                            <textarea name="description" class="form-control" rows="2"></textarea>
                        </div>

                        <button type="submit" name="add_record" class="btn btn-primary w-100 fw-bold"><i class="fas fa-save me-1"></i> ریکارڈ محفوظ کریں</button>
                    </form>
                </div>
            </div>
        </div>

        <!-- Recent Records -->
        <div class="col-md-8">
            <div class="card shadow-sm border-0 neobox">
                <div class="card-header bg-dark text-white d-flex justify-content-between align-items-center flex-wrap gap-2">
                    <h5 class="mb-0 fw-bold"><i class="fas fa-list me-2"></i> تمام ریکارڈز (کل: <?php echo count($records); ?>)</h5>
                    <input type="text" id="searchFinance" class="form-control form-control-sm w-auto" placeholder="تلاش کریں (Search)..." onkeyup="filterFinanceTable()">
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover align-middle mb-0 text-center" id="financeTable">
                            <thead class="table-light">
                                <tr>
                                    <th>تاریخ</th>
                                    <th>قسم</th>
                                    <th>مد</th>
                                    <th>رقم</th>
                                    <th>تفصیل / نام</th>
                                    <th>ایکشن</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach($records as $r): ?>
                                <tr>
                                    <td><?php echo date('d-M-Y', strtotime($r['date'])); ?></td>
                                    <td>
                                        <?php if($r['type'] == 'Income'): ?>
                                            <span class="badge bg-success">آمدن</span>
                                        <?php else: ?>
                                            <span class="badge bg-danger">خرچ</span>
                                        <?php endif; ?>
                                    </td>
                                    <td class="fw-bold"><?php echo htmlspecialchars($r['head_name'] ?: '---'); ?></td>
                                    <td class="fw-bold">Rs. <?php echo number_format($r['amount']); ?></td>
                                    <td class="small text-start">
                                        <?php if($r['type'] == 'Income' && !empty($r['donor_name'])): ?>
                                            <span class="text-primary fw-bold"><?php echo htmlspecialchars($r['donor_name']); ?></span><br>
                                        <?php endif; ?>
                                        <span class="text-muted"><?php echo htmlspecialchars($r['description']); ?></span>
                                    </td>
                                    <td>
                                        <?php if($r['type'] == 'Income'): ?>
                                            <a href="print_receipt.php?id=<?php echo $r['id']; ?>" class="btn btn-sm btn-outline-primary" target="_blank" title="رسید پرنٹ کریں"><i class="fas fa-print"></i></a>
                                        <?php endif; ?>
                                        <a href="edit_finance.php?id=<?php echo $r['id']; ?>" class="btn btn-sm btn-outline-warning me-1" title="ترمیم (Edit)"><i class="fas fa-edit"></i></a>
                                        <a href="?del_id=<?php echo $r['id']; ?>" class="btn btn-sm btn-outline-danger" onclick="return confirm('کیا واقعی حذف کرنا چاہتے ہیں؟')" title="ڈیلیٹ"><i class="fas fa-trash"></i></a>
                                    </td>
                                </tr>
                                <?php endforeach; ?>
                                <?php if(count($records) == 0): ?>
                                <tr><td colspan="6" class="text-center p-4">کوئی ریکارڈ موجود نہیں</td></tr>
                                <?php endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Add Head Modal -->
<div class="modal fade" id="addHeadModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <form method="POST">
                <div class="modal-header bg-primary text-white">
                    <h5 class="modal-title">نئی مد شامل کریں</h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="mb-3">
                        <label class="fw-bold">مد کا نام</label>
                        <input type="text" name="head_name" class="form-control" required>
                    </div>
                    <div class="mb-3">
                        <label class="fw-bold">قسم</label>
                        <select name="head_type" class="form-select" id="modal_head_type" required>
                            <option value="Income">آمدن</option>
                            <option value="Expense">خرچ</option>
                        </select>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">منسوخ</button>
                    <button type="submit" name="add_head" class="btn btn-primary">محفوظ کریں</button>
                </div>
            </form>
        </div>
    </div>
</div>

<script>
function toggleDonor() {
    var type = document.getElementById('record_type').value;
    if(type === 'Income') {
        document.getElementById('donor_fields').style.display = 'block';
    } else {
        document.getElementById('donor_fields').style.display = 'none';
    }
}

function filterHeads() {
    var type = document.getElementById('record_type').value;
    var headSelect = document.getElementById('head_id');
    var options = headSelect.options;
    
    var currentSelected = headSelect.value;
    var anySelected = false;
    
    for (var i = 0; i < options.length; i++) {
        var opt = options[i];
        if (opt.value === "") {
            opt.hidden = false;
            opt.disabled = false;
            opt.style.display = '';
            continue;
        }
        var optType = (opt.getAttribute('data-type') || '').toLowerCase();
        var selectedType = (type || '').toLowerCase();
        if (optType === selectedType) {
            opt.hidden = false;
            opt.disabled = false;
            opt.style.display = '';
            if (opt.value === currentSelected) {
                anySelected = true;
            }
        } else {
            opt.hidden = true;
            opt.disabled = true;
            opt.style.display = 'none';
        }
    }
    
    if (!anySelected) {
        headSelect.value = "";
    }
}

function onTypeChange() {
    toggleDonor();
    filterHeads();
    var modalType = document.getElementById('modal_head_type');
    var recordType = document.getElementById('record_type');
    if (modalType && recordType) modalType.value = recordType.value;
}

// Run on load
document.addEventListener('DOMContentLoaded', function() {
    toggleDonor();
    filterHeads();
    var addHeadModal = document.getElementById('addHeadModal');
    if (addHeadModal) {
        addHeadModal.addEventListener('show.bs.modal', function () {
            var modalType = document.getElementById('modal_head_type');
            var recordType = document.getElementById('record_type');
            if (modalType && recordType) modalType.value = recordType.value;
        });
    }
});

function filterFinanceTable() {
    var input = document.getElementById("searchFinance");
    var filter = input.value.toLowerCase();
    var table = document.getElementById("financeTable");
    if (!table) return;
    var tr = table.getElementsByTagName("tr");
    for (var i = 1; i < tr.length; i++) {
        var txt = tr[i].textContent || tr[i].innerText;
        if (txt.toLowerCase().indexOf(filter) > -1) {
            tr[i].style.display = "";
        } else {
            tr[i].style.display = "none";
        }
    }
}
</script>

<?php include 'footer.php'; ?>
