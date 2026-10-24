<?php
require_once 'db.php';
if (session_status() === PHP_SESSION_NONE) { session_start(); }

$system_type = $_SESSION['system_type'] ?? 'Madrasa';
$is_admin = (($_SESSION['role'] ?? '') === 'admin');
$perm_key = ($system_type === 'Masjid') ? 'manage_masjid_in_kind_donations' : 'manage_in_kind_donations';
if (!isset($_SESSION['user_id']) || (!$is_admin && !app_has_perm($perm_key) && !app_has_perm('manage_in_kind_donations') && !app_has_perm('manage_masjid_in_kind_donations'))) {
    header("Location: " . ($system_type === 'Masjid' ? "masjid_dashboard.php" : "dashboard.php"));
    exit;
}

// Self-healing schema checks for in_kind_donations table
try { $pdo->exec("ALTER TABLE in_kind_donations ADD COLUMN computer_receipt_no INT DEFAULT NULL"); } catch (Throwable $e) {}
try { $pdo->exec("ALTER TABLE in_kind_donations ADD COLUMN manual_receipt_no VARCHAR(100) DEFAULT NULL"); } catch (Throwable $e) {}
try { $pdo->exec("ALTER TABLE in_kind_donations ADD COLUMN system_type VARCHAR(50) DEFAULT 'Madrasa'"); } catch (Throwable $e) {}
try { $pdo->exec("ALTER TABLE in_kind_donations ADD COLUMN tenant_id INT NOT NULL DEFAULT 1"); } catch (Throwable $e) {}
try { $pdo->exec("ALTER TABLE in_kind_donations ADD COLUMN is_deleted TINYINT(1) DEFAULT 0"); } catch (Throwable $e) {}
$cur_tenant_id = (int)get_current_tenant_id();
$user_id = $_SESSION['user_id'];
$user_name = $_SESSION['name'] ?? 'Admin';

function next_in_kind_receipt_no(PDO $pdo, $userId, $systemType = 'Madrasa', $tenantId = null) {
    if ($tenantId === null) $tenantId = (int)get_current_tenant_id();
    try { $pdo->exec("ALTER TABLE in_kind_donations ADD COLUMN system_type VARCHAR(50) DEFAULT 'Madrasa' AFTER user_name"); } catch (Exception $e) {}

    $userId = max(1, (int)$userId);
    $minNo = $userId * 100000;
    if ($systemType === 'Masjid') {
        $minNo += 500000;
    }
    $maxNo = $minNo + 100000;
    $stmt = $pdo->prepare("SELECT MAX(computer_receipt_no) FROM in_kind_donations WHERE computer_receipt_no > ? AND computer_receipt_no < ? AND (tenant_id = ? OR tenant_id IS NULL OR tenant_id = 1) AND (is_deleted = 0 OR is_deleted IS NULL)");
    $stmt->execute([$minNo, $maxNo, $tenantId]);
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
    $pdo->prepare("UPDATE in_kind_donations SET is_deleted = 1 WHERE id = ? AND (tenant_id = ? OR tenant_id IS NULL OR tenant_id = 1)")->execute([$delId, $cur_tenant_id]);
    header("Location: in_kind_donations.php?msg=deleted");
    exit;
}

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['add_donation'])) {
    $date = $_POST['date'];
    $donor_name = trim($_POST['donor_name'] ?? '');
    $donor_phone = trim($_POST['donor_phone'] ?? '');
    $donor_address = trim($_POST['donor_address'] ?? '');
    $item_name = trim($_POST['item_name'] ?? '');
    $quantity = trim($_POST['quantity'] ?? '');
    $estimated_value = !empty($_POST['estimated_value']) ? (float)$_POST['estimated_value'] : null;
    $manual_receipt_no = trim($_POST['manual_receipt_no'] ?? '');
    $description = trim($_POST['description'] ?? '');

    $sys_type = $_SESSION['system_type'] ?? 'Madrasa';
    $comp_receipt_no = next_in_kind_receipt_no($pdo, $user_id, $sys_type, $cur_tenant_id);

    $stmt = $pdo->prepare("INSERT INTO in_kind_donations (user_id, user_name, system_type, date, donor_name, donor_phone, donor_address, item_name, quantity, estimated_value, description, manual_receipt_no, computer_receipt_no, tenant_id, is_deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)");
    $stmt->execute([$user_id, $user_name, $sys_type, $date, $donor_name, $donor_phone, $donor_address, $item_name, $quantity, $estimated_value, $description, $manual_receipt_no, $comp_receipt_no, $cur_tenant_id]);
    header("Location: in_kind_donations.php?msg=added");
    exit;
}

if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['edit_donation'])) {
    $id = (int)$_POST['id'];
    $date = $_POST['date'];
    $donor_name = trim($_POST['donor_name'] ?? '');
    $donor_phone = trim($_POST['donor_phone'] ?? '');
    $donor_address = trim($_POST['donor_address'] ?? '');
    $item_name = trim($_POST['item_name'] ?? '');
    $quantity = trim($_POST['quantity'] ?? '');
    $estimated_value = !empty($_POST['estimated_value']) ? (float)$_POST['estimated_value'] : null;
    $manual_receipt_no = trim($_POST['manual_receipt_no'] ?? '');
    $description = trim($_POST['description'] ?? '');
    
    $sys_type = $_SESSION['system_type'] ?? 'Madrasa';

    $stmt = $pdo->prepare("UPDATE in_kind_donations SET date=?, donor_name=?, donor_phone=?, donor_address=?, item_name=?, quantity=?, estimated_value=?, description=?, manual_receipt_no=? WHERE id=? AND system_type=? AND (tenant_id=? OR tenant_id IS NULL OR tenant_id=1)");
    $stmt->execute([$date, $donor_name, $donor_phone, $donor_address, $item_name, $quantity, $estimated_value, $description, $manual_receipt_no, $id, $sys_type, $cur_tenant_id]);
    header("Location: in_kind_donations.php?msg=edited");
    exit;
}

$system_type = $_SESSION['system_type'] ?? 'Madrasa';

// Fetch Records
$limit = 50;
$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
if ($page < 1) $page = 1;
$offset = ($page - 1) * $limit;

if ($system_type === 'Masjid') {
    $search_query = " AND system_type = 'Masjid'";
    $params = [];
} else {
    $search_query = " AND (system_type = 'Madrasa' OR system_type IS NULL OR system_type = '')";
    $params = [];
}

if (isset($_GET['search']) && !empty(trim($_GET['search']))) {
    $s = trim($_GET['search']);
    $search_query .= " AND (donor_name LIKE ? OR item_name LIKE ? OR computer_receipt_no LIKE ? OR manual_receipt_no LIKE ?)";
    $params[] = "%$s%";
    $params[] = "%$s%";
    $params[] = "%$s%";
    $params[] = "%$s%";
}

if (isset($_GET['filter_date']) && !empty($_GET['filter_date'])) {
    $search_query .= " AND date = ?";
    $params[] = $_GET['filter_date'];
}

$total_stmt = $pdo->prepare("SELECT COUNT(*) FROM in_kind_donations WHERE (is_deleted = 0 OR is_deleted IS NULL) AND (tenant_id = $cur_tenant_id OR tenant_id IS NULL OR tenant_id = 1)" . $search_query);
$total_stmt->execute($params);
$total_records = $total_stmt->fetchColumn();
$total_pages = ceil($total_records / $limit);

$stmt = $pdo->prepare("SELECT * FROM in_kind_donations WHERE (is_deleted = 0 OR is_deleted IS NULL) AND (tenant_id = $cur_tenant_id OR tenant_id IS NULL OR tenant_id = 1)" . $search_query . " ORDER BY date DESC, id DESC LIMIT $limit OFFSET $offset");
$stmt->execute($params);
$records = $stmt->fetchAll(PDO::FETCH_ASSOC);

$msg = '';
if (isset($_GET['msg'])) {
    if ($_GET['msg'] == 'added') $msg = ($lang == 'ur') ? "جنسی عطیہ کامیابی سے درج کر لیا گیا!" : "In-kind donation added successfully!";
    if ($_GET['msg'] == 'edited') $msg = ($lang == 'ur') ? "جنسی عطیہ میں ترمیم محفوظ کر لی گئی!" : "In-kind donation updated successfully!";
    if ($_GET['msg'] == 'deleted') $msg = ($lang == 'ur') ? "جنسی عطیہ کامیابی سے حذف کر دیا گیا!" : "In-kind donation deleted successfully!";
}

$title = ($system_type === 'Masjid') 
    ? (($lang === 'ur') ? "جنسی عطیات (مسجد)" : "Masjid In-Kind Donations") 
    : (($lang === 'ur') ? "جنسی عطیات (مدرسہ)" : "Madrasa In-Kind Donations");
include 'header.php';
?>

<div class="container-fluid py-4" dir="<?php echo ($lang === 'ur') ? 'rtl' : 'ltr'; ?>">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h4 class="text-primary fw-bold mb-0">
            <i class="fas fa-box-open me-2"></i><?php echo ($lang == 'ur') ? 'جنسی عطیات (In-Kind Donations)' : 'In-Kind Donations Management'; ?>
        </h4>
        <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addModal">
            <i class="fas fa-plus-circle me-1"></i><?php echo ($lang == 'ur') ? 'نیا جنسی عطیہ درج کریں' : 'Add In-Kind Donation'; ?>
        </button>
    </div>

    <?php if ($msg): ?>
        <div class="alert alert-success alert-dismissible fade show shadow-sm" role="alert">
            <i class="fas fa-check-circle me-2"></i> <?php echo $msg; ?>
            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
        </div>
    <?php endif; ?>

    <div class="card shadow-sm border-0 mb-4">
        <div class="card-body bg-light">
            <form method="GET" class="row g-3">
                <div class="col-md-5">
                    <input type="text" name="search" class="form-control" placeholder="<?php echo ($lang == 'ur') ? 'دہندہ، چیز کا نام، یا رسید نمبر سے تلاش کریں...' : 'Search by donor, item, or receipt no...'; ?>" value="<?php echo htmlspecialchars($_GET['search'] ?? ''); ?>">
                </div>
                <div class="col-md-3">
                    <input type="date" name="filter_date" class="form-control" value="<?php echo htmlspecialchars($_GET['filter_date'] ?? ''); ?>">
                </div>
                <div class="col-md-4">
                    <button type="submit" class="btn btn-secondary w-100"><i class="fas fa-search me-1"></i><?php echo ($lang == 'ur') ? 'تلاش کریں' : 'Search'; ?></button>
                </div>
            </form>
        </div>
    </div>

    <div class="card shadow-sm border-0">
        <div class="card-body p-0">
            <div class="table-responsive">
                <table class="table table-hover table-striped align-middle mb-0">
                    <thead class="table-light">
                        <tr>
                            <th class="text-center"><?php echo ($lang == 'ur') ? 'رسید نمبر' : 'Receipt No'; ?></th>
                            <th><?php echo ($lang == 'ur') ? 'تاریخ' : 'Date'; ?></th>
                            <th><?php echo ($lang == 'ur') ? 'دہندہ کی تفصیل' : 'Donor Details'; ?></th>
                            <th><?php echo ($lang == 'ur') ? 'چیز / سامان کا نام' : 'Item Name'; ?></th>
                            <th><?php echo ($lang == 'ur') ? 'مقدار / وزن' : 'Quantity / Weight'; ?></th>
                            <th><?php echo ($lang == 'ur') ? 'تفصیل' : 'Description'; ?></th>
                            <th class="text-center"><?php echo ($lang == 'ur') ? 'ایکشن' : 'Actions'; ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if(count($records) > 0): ?>
                            <?php foreach ($records as $r): ?>
                            <tr>
                                <td class="text-center fw-bold text-secondary">
                                    <?php echo htmlspecialchars((string)($r['computer_receipt_no'] ?: $r['id'])); ?>
                                    <?php if(!empty($r['manual_receipt_no'])): ?>
                                        <br><small class="text-muted">(<?php echo ($lang == 'ur') ? 'دستی: ' : 'Manual: '; ?><?php echo htmlspecialchars($r['manual_receipt_no']); ?>)</small>
                                    <?php endif; ?>
                                </td>
                                <td><span class="badge bg-light text-dark border"><i class="far fa-calendar-alt me-1"></i> <?php echo date('d-m-Y', strtotime($r['date'])); ?></span></td>
                                <td>
                                    <div class="fw-bold text-primary"><?php echo htmlspecialchars($r['donor_name']); ?></div>
                                    <?php if(!empty($r['donor_phone'])): ?><small class="text-muted"><i class="fas fa-phone-alt me-1"></i><?php echo htmlspecialchars($r['donor_phone']); ?></small><?php endif; ?>
                                </td>
                                <td><span class="fw-bold"><?php echo htmlspecialchars($r['item_name']); ?></span></td>
                                <td><?php echo htmlspecialchars($r['quantity']); ?></td>
                                <td><?php echo htmlspecialchars($r['description']); ?></td>
                                <td class="text-center">
                                    <div class="btn-group">
                                        <button class="btn btn-sm btn-outline-secondary" data-bs-toggle="modal" data-bs-target="#editModal<?php echo $r['id']; ?>" title="<?php echo ($lang == 'ur') ? 'ترمیم' : 'Edit'; ?>"><i class="fas fa-edit"></i></button>
                                        <a href="print_in_kind_receipt.php?id=<?php echo $r['id']; ?>" class="btn btn-sm btn-outline-primary" target="_blank" title="<?php echo ($lang == 'ur') ? 'رسید پرنٹ کریں' : 'Print Receipt'; ?>"><i class="fas fa-print"></i></a>
                                        <?php if(app_has_perm('delete_records') || in_array($_SESSION['role'] ?? '', ['admin','nazim'])): ?>
                                        <a href="in_kind_donations.php?del_id=<?php echo $r['id']; ?>" class="btn btn-sm btn-outline-danger" onclick="return confirm('<?php echo ($lang == 'ur') ? 'کیا آپ واقعی اس عطیے کو حذف کرنا چاہتے ہیں؟' : 'Are you sure you want to delete this donation?'; ?>');" title="<?php echo ($lang == 'ur') ? 'حذف' : 'Delete'; ?>"><i class="fas fa-trash"></i></a>
                                        <?php endif; ?>
                                    </div>
                                    
                                    <!-- Edit Modal for ID <?php echo $r['id']; ?> -->
                                    <div class="modal fade text-start" id="editModal<?php echo $r['id']; ?>" tabindex="-1">
                                        <div class="modal-dialog modal-lg">
                                            <div class="modal-content">
                                                <div class="modal-header bg-secondary text-white">
                                                    <h5 class="modal-title"><i class="fas fa-edit me-2"></i><?php echo ($lang == 'ur') ? 'جنسی عطیہ میں ترمیم کریں' : 'Edit In-Kind Donation'; ?></h5>
                                                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                                                </div>
                                                <form method="POST">
                                                    <input type="hidden" name="id" value="<?php echo $r['id']; ?>">
                                                    <div class="modal-body" dir="<?php echo ($lang === 'ur') ? 'rtl' : 'ltr'; ?>">
                                                        <div class="row g-3">
                                                            <div class="col-md-6">
                                                                <label class="form-label"><?php echo ($lang == 'ur') ? 'تاریخ' : 'Date'; ?> <span class="text-danger">*</span></label>
                                                                <input type="date" name="date" class="form-control" value="<?php echo $r['date']; ?>" required>
                                                            </div>
                                                            <div class="col-md-6">
                                                                <label class="form-label"><?php echo ($lang == 'ur') ? 'دستی رسید نمبر (اختیاری)' : 'Manual Receipt No (Optional)'; ?></label>
                                                                <input type="text" name="manual_receipt_no" class="form-control" value="<?php echo htmlspecialchars($r['manual_receipt_no']); ?>">
                                                            </div>
                                                            <div class="col-md-6">
                                                                <label class="form-label"><?php echo ($lang == 'ur') ? 'نام دہندہ' : 'Donor Name'; ?> <span class="text-danger">*</span></label>
                                                                <input type="text" name="donor_name" class="form-control" value="<?php echo htmlspecialchars($r['donor_name']); ?>" required>
                                                            </div>
                                                            <div class="col-md-6">
                                                                <label class="form-label"><?php echo ($lang == 'ur') ? 'رابطہ فون نمبر' : 'Phone Number'; ?></label>
                                                                <input type="text" name="donor_phone" class="form-control" value="<?php echo htmlspecialchars($r['donor_phone']); ?>">
                                                            </div>
                                                            <div class="col-12">
                                                                <label class="form-label"><?php echo ($lang == 'ur') ? 'پتہ' : 'Address'; ?></label>
                                                                <input type="text" name="donor_address" class="form-control" value="<?php echo htmlspecialchars($r['donor_address']); ?>">
                                                            </div>
                                                            <div class="col-md-6">
                                                                <label class="form-label"><?php echo ($lang == 'ur') ? 'چیز / سامان کا نام' : 'Item Name'; ?> <span class="text-danger">*</span></label>
                                                                <input type="text" name="item_name" class="form-control" value="<?php echo htmlspecialchars($r['item_name']); ?>" required>
                                                            </div>
                                                            <div class="col-md-6">
                                                                <label class="form-label"><?php echo ($lang == 'ur') ? 'مقدار / وزن / تعداد' : 'Quantity / Weight'; ?> <span class="text-danger">*</span></label>
                                                                <input type="text" name="quantity" class="form-control" value="<?php echo htmlspecialchars($r['quantity']); ?>" required>
                                                            </div>
                                                            <div class="col-md-6">
                                                                <label class="form-label"><?php echo ($lang == 'ur') ? 'تخمینی مالیت (روپے - اختیاری)' : 'Estimated Value (PKR - Optional)'; ?></label>
                                                                <input type="number" step="0.01" name="estimated_value" class="form-control" value="<?php echo $r['estimated_value']; ?>">
                                                            </div>
                                                            <div class="col-md-6">
                                                                <label class="form-label"><?php echo ($lang == 'ur') ? 'اضافی تفصیل / نوٹ' : 'Additional Description / Notes'; ?></label>
                                                                <input type="text" name="description" class="form-control" value="<?php echo htmlspecialchars($r['description']); ?>">
                                                            </div>
                                                        </div>
                                                    </div>
                                                    <div class="modal-footer bg-light">
                                                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal"><?php echo ($lang == 'ur') ? 'منسوخ' : 'Cancel'; ?></button>
                                                        <button type="submit" name="edit_donation" class="btn btn-primary"><i class="fas fa-save me-1"></i><?php echo ($lang == 'ur') ? 'محفوظ کریں' : 'Save Changes'; ?></button>
                                                    </div>
                                                </form>
                                            </div>
                                        </div>
                                    </div>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                        <?php else: ?>
                            <tr><td colspan="7" class="text-center text-muted py-4"><?php echo ($lang == 'ur') ? 'کوئی جنسی عطیہ موجود نہیں ہے۔' : 'No in-kind donations found.'; ?></td></tr>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
        
        <?php if ($total_pages > 1): ?>
        <div class="card-footer bg-white text-center">
            <ul class="pagination pagination-sm justify-content-center mb-0">
                <?php for($i=1; $i<=$total_pages; $i++): ?>
                    <li class="page-item <?php echo $i == $page ? 'active' : ''; ?>">
                        <a class="page-link" href="?page=<?php echo $i; ?>&search=<?php echo urlencode($_GET['search']??''); ?>&filter_date=<?php echo urlencode($_GET['filter_date']??''); ?>"><?php echo $i; ?></a>
                    </li>
                <?php endfor; ?>
            </ul>
        </div>
        <?php endif; ?>
    </div>
</div>

<!-- Add Modal -->
<div class="modal fade" id="addModal" tabindex="-1">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header bg-primary text-white">
                <h5 class="modal-title"><i class="fas fa-plus-circle me-2"></i><?php echo ($lang == 'ur') ? 'نیا جنسی عطیہ درج کریں' : 'Add In-Kind Donation'; ?></h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
            </div>
            <form method="POST">
                <div class="modal-body" dir="<?php echo ($lang === 'ur') ? 'rtl' : 'ltr'; ?>">
                    <div class="row g-3">
                        <div class="col-md-6">
                            <label class="form-label"><?php echo ($lang == 'ur') ? 'تاریخ' : 'Date'; ?> <span class="text-danger">*</span></label>
                            <input type="date" name="date" class="form-control" value="<?php echo date('Y-m-d'); ?>" required>
                        </div>
                        <div class="col-md-6">
                            <label class="form-label"><?php echo ($lang == 'ur') ? 'دستی رسید نمبر (اختیاری)' : 'Manual Receipt No (Optional)'; ?></label>
                            <input type="text" name="manual_receipt_no" class="form-control">
                        </div>
                        <div class="col-md-6">
                            <label class="form-label"><?php echo ($lang == 'ur') ? 'نام دہندہ' : 'Donor Name'; ?> <span class="text-danger">*</span></label>
                            <input type="text" name="donor_name" class="form-control" required>
                        </div>
                        <div class="col-md-6">
                            <label class="form-label"><?php echo ($lang == 'ur') ? 'رابطہ فون نمبر' : 'Phone Number'; ?></label>
                            <input type="text" name="donor_phone" class="form-control">
                        </div>
                        <div class="col-12">
                            <label class="form-label"><?php echo ($lang == 'ur') ? 'پتہ' : 'Address'; ?></label>
                            <input type="text" name="donor_address" class="form-control">
                        </div>
                        <div class="col-md-6">
                            <label class="form-label"><?php echo ($lang == 'ur') ? 'چیز / سامان کا نام (مثلاً چاول، قالین)' : 'Item Name (e.g. Rice, Carpet)'; ?> <span class="text-danger">*</span></label>
                            <input type="text" name="item_name" class="form-control" required>
                        </div>
                        <div class="col-md-6">
                            <label class="form-label"><?php echo ($lang == 'ur') ? 'مقدار / وزن / تعداد (مثلاً 50 کلو، 10 تھان)' : 'Quantity / Weight (e.g. 50 kg, 10 pcs)'; ?> <span class="text-danger">*</span></label>
                            <input type="text" name="quantity" class="form-control" placeholder="<?php echo ($lang == 'ur') ? 'مثلاً: 50 کلو یا 10 عدد' : 'e.g. 50 kg or 10 pcs'; ?>" required>
                        </div>
                        <div class="col-md-6">
                            <label class="form-label"><?php echo ($lang == 'ur') ? 'تخمینی مالیت (روپے - اختیاری)' : 'Estimated Value (PKR - Optional)'; ?></label>
                            <input type="number" step="0.01" name="estimated_value" class="form-control">
                        </div>
                        <div class="col-md-6">
                            <label class="form-label"><?php echo ($lang == 'ur') ? 'اضافی تفصیل / نوٹ' : 'Additional Description / Notes'; ?></label>
                            <input type="text" name="description" class="form-control">
                        </div>
                    </div>
                </div>
                <div class="modal-footer bg-light">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal"><?php echo ($lang == 'ur') ? 'منسوخ' : 'Cancel'; ?></button>
                    <button type="submit" name="add_donation" class="btn btn-primary"><i class="fas fa-save me-1"></i><?php echo ($lang == 'ur') ? 'محفوظ کریں' : 'Save Donation'; ?></button>
                </div>
            </form>
        </div>
    </div>
</div>

<?php include 'footer.php'; ?>
