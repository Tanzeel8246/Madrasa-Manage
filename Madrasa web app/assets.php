<?php
if (session_status() === PHP_SESSION_NONE) { session_start(); }
require_once 'db.php';

try {
    $pdo->exec("RENAME TABLE masjid_assets TO assets");
} catch (Exception $e) {}
try {
    $pdo->exec("ALTER TABLE assets ADD COLUMN system_type VARCHAR(50) DEFAULT 'Masjid' AFTER name");
} catch (Exception $e) {}

$system_type = $_SESSION['system_type'] ?? 'Madrasa';
$cur_tenant_id = (int)get_current_tenant_id();
$is_admin = (($_SESSION['role'] ?? '') === 'admin');
$perm_key = ($system_type === 'Masjid') ? 'manage_masjid_assets' : 'manage_assets';
if (!isset($_SESSION['user_id']) || (!$is_admin && !app_has_perm($perm_key) && !app_has_perm('manage_assets') && !app_has_perm('manage_masjid_assets'))) {
    header("Location: " . ($system_type === 'Masjid' ? "masjid_dashboard.php" : "dashboard.php"));
    exit;
}

// Delete via GET or POST
if (isset($_GET['del_id'])) {
    $delId = (int)$_GET['del_id'];
    $pdo->prepare("UPDATE assets SET is_deleted = 1, is_synced = 0 WHERE id = ? AND (tenant_id = ? OR tenant_id IS NULL OR tenant_id = 1)")->execute([$delId, $cur_tenant_id]);
    header("Location: assets.php?msg=deleted");
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['action']) && $_POST['action'] === 'delete') {
        $id = (int)$_POST['id'];
        $pdo->prepare("UPDATE assets SET is_deleted = 1, is_synced = 0 WHERE id = ? AND (tenant_id = ? OR tenant_id IS NULL OR tenant_id = 1)")->execute([$id, $cur_tenant_id]);
    } else {
        $name = trim($_POST["name"] ?? "");
        $category = trim($_POST["category"] ?? "");
        $quantity = (int)($_POST["quantity"] ?? 0);
        $condition_status = trim($_POST["condition_status"] ?? "");
        $asset_type = trim($_POST["asset_type"] ?? "Purchased");
        
        $donor_name = "";
        $donor_father = "";
        $donor_address = "";
        $donor_phone = "";
        
        if ($asset_type === 'Waqf') {
            $donor_name = trim($_POST["donor_name"] ?? "");
            $donor_father = trim($_POST["donor_father"] ?? "");
            $donor_address = trim($_POST["donor_address"] ?? "");
            $donor_phone = trim($_POST["donor_phone"] ?? "");
        }

        if (isset($_POST['id']) && !empty($_POST['id'])) {
            $id = (int)$_POST['id'];
            $stmt = $pdo->prepare("UPDATE assets SET name=?, category=?, quantity=?, condition_status=?, asset_type=?, donor_name=?, donor_father=?, donor_address=?, donor_phone=?, is_synced=0 WHERE id=? AND (tenant_id=? OR tenant_id IS NULL OR tenant_id=1)");
            $stmt->execute([$name, $category, $quantity, $condition_status, $asset_type, $donor_name, $donor_father, $donor_address, $donor_phone, $id, $cur_tenant_id]);
        } else {
            $stmt = $pdo->prepare("INSERT INTO assets (name, system_type, category, quantity, condition_status, asset_type, donor_name, donor_father, donor_address, donor_phone, tenant_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
            $stmt->execute([$name, $system_type, $category, $quantity, $condition_status, $asset_type, $donor_name, $donor_father, $donor_address, $donor_phone, $cur_tenant_id]);
        }
    }
    header("Location: assets.php");
    exit;
}

$sys_cond = ($system_type === 'Masjid') ? "system_type = 'Masjid'" : "(system_type = 'Madrasa' OR system_type IS NULL OR system_type = '')";
$records = $pdo->query("SELECT * FROM assets WHERE (is_deleted = 0 OR is_deleted IS NULL) AND $sys_cond AND (tenant_id = $cur_tenant_id OR tenant_id IS NULL OR tenant_id = 1) ORDER BY id DESC")->fetchAll(PDO::FETCH_ASSOC);
$title = ($system_type === 'Masjid') 
    ? (($lang === 'ur') ? "اثاثہ جات (مسجد)" : "Masjid Assets") 
    : (($lang === 'ur') ? "اثاثہ جات (مدرسہ)" : "Madrasa Assets");
include 'header.php';
?>

<div class="container py-4" dir="<?php echo ($lang === 'ur') ? 'rtl' : 'ltr'; ?>">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h3 class="fw-bold text-danger">
            <i class="fas fa-boxes me-2"></i><?php echo ($lang === 'ur') ? 'اثاثہ جات (Assets)' : 'Assets Management'; ?>
        </h3>
        <button class="btn btn-danger fw-bold" onclick="openAddModal()">
            <i class="fas fa-plus me-1"></i><?php echo ($lang === 'ur') ? 'نیا اثاثہ شامل کریں' : 'Add New Asset'; ?>
        </button>
    </div>

    <div class="card shadow-sm border-0 neobox">
        <div class="table-responsive">
            <table class="table table-hover align-middle mb-0">
                <thead class="table-light">
                    <tr>
                        <th><?php echo ($lang === 'ur') ? 'نام اثاثہ' : 'Asset Name'; ?></th>
                        <th><?php echo ($lang === 'ur') ? 'کیٹیگری' : 'Category'; ?></th>
                        <th><?php echo ($lang === 'ur') ? 'تعداد و حالت' : 'Quantity / Condition'; ?></th>
                        <th><?php echo ($lang === 'ur') ? 'قسم (Type)' : 'Type'; ?></th>
                        <th><?php echo ($lang === 'ur') ? 'وقف دہندہ (اگر وقف ہو)' : 'Donor (If Waqf)'; ?></th>
                        <th class="text-center"><?php echo ($lang === 'ur') ? 'ایکشن' : 'Actions'; ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach($records as $row): ?>
                    <tr>
                        <td class="fw-bold"><?php echo htmlspecialchars((string)$row["name"]); ?></td>
                        <td><span class="badge bg-secondary"><?php echo htmlspecialchars((string)$row["category"]); ?></span></td>
                        <td>
                            <?php echo ($lang === 'ur') ? 'تعداد: ' : 'Qty: '; ?><strong><?php echo htmlspecialchars((string)$row["quantity"]); ?></strong><br>
                            <small class="text-muted"><?php echo ($lang === 'ur') ? 'حالت: ' : 'Condition: '; ?><?php echo htmlspecialchars((string)$row["condition_status"]); ?></small>
                        </td>
                        <td>
                            <?php if($row['asset_type'] == 'Waqf'): ?>
                                <span class="badge bg-success"><?php echo ($lang === 'ur') ? 'وقف (Waqf)' : 'Waqf'; ?></span>
                            <?php else: ?>
                                <span class="badge bg-primary"><?php echo ($lang === 'ur') ? 'خریدا گیا (Purchased)' : 'Purchased'; ?></span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <?php if($row['asset_type'] == 'Waqf' && !empty($row["donor_name"])): ?>
                                <strong><?php echo ($lang === 'ur') ? 'نام: ' : 'Name: '; ?></strong><?php echo htmlspecialchars((string)$row["donor_name"]); ?> 
                                <?php if($row['donor_father']): ?> (ولدیت: <?php echo htmlspecialchars((string)$row["donor_father"]); ?>)<?php endif; ?><br>
                                <small class="text-muted">
                                    <?php if($row['donor_phone']): ?><i class="fas fa-phone ms-1 me-1"></i><?php echo htmlspecialchars((string)$row["donor_phone"]); ?><?php endif; ?>
                                    <?php if($row['donor_address']): ?><i class="fas fa-map-marker-alt ms-1 me-1"></i><?php echo htmlspecialchars((string)$row["donor_address"]); ?><?php endif; ?>
                                </small>
                            <?php else: ?>
                                <span class="text-muted">-</span>
                            <?php endif; ?>
                        </td>
                        <td class="text-center">
                            <button type="button" class="btn btn-sm btn-outline-primary" title="<?php echo ($lang === 'ur') ? 'ترمیم' : 'Edit'; ?>" onclick='editRecord(<?php echo json_encode($row, JSON_HEX_APOS | JSON_HEX_QUOT); ?>)'><i class="fas fa-edit"></i></button>
                            <a href="assets.php?del_id=<?php echo $row['id']; ?>" class="btn btn-sm btn-outline-danger" onclick="return confirm('<?php echo ($lang === 'ur') ? 'کیا آپ واقعی اس اثاثے کو حذف کرنا چاہتے ہیں؟' : 'Are you sure you want to delete this asset?'; ?>');" title="<?php echo ($lang === 'ur') ? 'حذف' : 'Delete'; ?>"><i class="fas fa-trash"></i></a>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                    <?php if(empty($records)): ?>
                    <tr><td colspan="6" class="text-center text-muted py-4"><?php echo ($lang === 'ur') ? 'کوئی اثاثہ ریکارڈ موجود نہیں ہے۔' : 'No asset records found.'; ?></td></tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<div class="modal fade" id="assetModal" tabindex="-1">
  <div class="modal-dialog modal-lg">
    <div class="modal-content">
      <form method="POST" id="assetForm">
        <input type="hidden" name="id" id="asset_id">
        <div class="modal-header bg-danger text-white">
          <h5 class="modal-title" id="modalTitle"><?php echo ($lang === 'ur') ? 'نیا اثاثہ شامل کریں' : 'Add Asset'; ?></h5>
          <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
        </div>
        <div class="modal-body">
            <div class="row mb-3">
                <div class="col-md-6">
                    <label class="form-label fw-bold"><?php echo ($lang === 'ur') ? 'نام اثاثہ' : 'Asset Name'; ?> <span class="text-danger">*</span></label>
                    <input type="text" name="name" id="asset_name" class="form-control" required>
                </div>
                <div class="col-md-6">
                    <label class="form-label fw-bold"><?php echo ($lang === 'ur') ? 'کیٹیگری (مثلاً فرنیچر، برقیات)' : 'Category (e.g. Furniture, Electronics)'; ?> <span class="text-danger">*</span></label>
                    <input type="text" name="category" id="asset_category" class="form-control" required>
                </div>
            </div>
            
            <div class="row mb-3">
                <div class="col-md-6">
                    <label class="form-label fw-bold"><?php echo ($lang === 'ur') ? 'تعداد' : 'Quantity'; ?> <span class="text-danger">*</span></label>
                    <input type="number" name="quantity" id="asset_qty" class="form-control" required min="1" value="1">
                </div>
                <div class="col-md-6">
                    <label class="form-label fw-bold"><?php echo ($lang === 'ur') ? 'حالت (Condition)' : 'Condition'; ?> <span class="text-danger">*</span></label>
                    <select name="condition_status" id="asset_condition" class="form-select" required>
                        <option value="نیا (New)"><?php echo ($lang === 'ur') ? 'نیا (New)' : 'New'; ?></option>
                        <option value="استعمال شدہ - بہترین (Used - Good)"><?php echo ($lang === 'ur') ? 'استعمال شدہ - بہترین (Used - Good)' : 'Used - Good'; ?></option>
                        <option value="مرمت طلب (Needs Repair)"><?php echo ($lang === 'ur') ? 'مرمت طلب (Needs Repair)' : 'Needs Repair'; ?></option>
                        <option value="خراب / ٹوٹا ہوا (Damaged/Broken)"><?php echo ($lang === 'ur') ? 'خراب / ٹوٹا ہوا (Damaged/Broken)' : 'Damaged/Broken'; ?></option>
                    </select>
                </div>
            </div>

            <div class="mb-3">
                <label class="form-label fw-bold"><?php echo ($lang === 'ur') ? 'قسم اثاثہ (Asset Type)' : 'Asset Type'; ?></label>
                <div class="d-flex gap-4">
                    <div class="form-check">
                        <input class="form-check-input" type="radio" name="asset_type" id="typePurchased" value="Purchased" checked onchange="toggleWaqfFields()">
                        <label class="form-check-label" for="typePurchased"><?php echo ($lang === 'ur') ? 'خریدا گیا (Purchased)' : 'Purchased'; ?></label>
                    </div>
                    <div class="form-check">
                        <input class="form-check-input" type="radio" name="asset_type" id="typeWaqf" value="Waqf" onchange="toggleWaqfFields()">
                        <label class="form-check-label" for="typeWaqf"><?php echo ($lang === 'ur') ? 'وقف شدہ (Waqf)' : 'Waqf'; ?></label>
                    </div>
                </div>
            </div>

            <div id="waqfFields" style="display: none; background: #f8f9fa; padding: 15px; border-radius: 8px; border: 1px solid #dee2e6;">
                <h6 class="fw-bold text-success mb-3"><i class="fas fa-hand-holding-heart me-2"></i><?php echo ($lang === 'ur') ? 'وقف دہندہ کی تفصیلات' : 'Waqf Donor Details'; ?></h6>
                <div class="row mb-3">
                    <div class="col-md-6">
                        <label class="form-label"><?php echo ($lang === 'ur') ? 'نام وقف دہندہ' : 'Donor Name'; ?></label>
                        <input type="text" name="donor_name" id="donor_name" class="form-control">
                    </div>
                    <div class="col-md-6">
                        <label class="form-label"><?php echo ($lang === 'ur') ? 'ولدیت' : 'Father Name'; ?></label>
                        <input type="text" name="donor_father" id="donor_father" class="form-control">
                    </div>
                </div>
                <div class="row mb-2">
                    <div class="col-md-6">
                        <label class="form-label"><?php echo ($lang === 'ur') ? 'رابطہ فون نمبر' : 'Phone Number'; ?></label>
                        <input type="text" name="donor_phone" id="donor_phone" class="form-control" dir="ltr">
                    </div>
                    <div class="col-md-6">
                        <label class="form-label"><?php echo ($lang === 'ur') ? 'پتہ' : 'Address'; ?></label>
                        <input type="text" name="donor_address" id="donor_address" class="form-control">
                    </div>
                </div>
            </div>

        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-bs-dismiss="modal"><?php echo ($lang === 'ur') ? 'منسوخ' : 'Cancel'; ?></button>
          <button type="submit" class="btn btn-danger"><?php echo ($lang === 'ur') ? 'محفوظ کریں' : 'Save Asset'; ?></button>
        </div>
      </form>
    </div>
  </div>
</div>

<script>
function toggleWaqfFields() {
    if (document.getElementById('typeWaqf').checked) {
        document.getElementById('waqfFields').style.display = 'block';
        document.getElementById('donor_name').required = true;
    } else {
        document.getElementById('waqfFields').style.display = 'none';
        document.getElementById('donor_name').required = false;
    }
}

function openAddModal() {
    document.getElementById('assetForm').reset();
    document.getElementById('asset_id').value = '';
    document.getElementById('modalTitle').innerText = '<?php echo ($lang === 'ur') ? 'نیا اثاثہ شامل کریں' : 'Add New Asset'; ?>';
    document.getElementById('typePurchased').checked = true;
    toggleWaqfFields();
    new bootstrap.Modal(document.getElementById('assetModal')).show();
}

function editRecord(row) {
    document.getElementById('asset_id').value = row.id || '';
    document.getElementById('asset_name').value = row.name || '';
    document.getElementById('asset_category').value = row.category || '';
    document.getElementById('asset_qty').value = row.quantity || '1';
    
    let conditionSelect = document.getElementById('asset_condition');
    let conditionVal = row.condition_status || '';
    let found = false;
    for(let i = 0; i < conditionSelect.options.length; i++) {
        if(conditionSelect.options[i].value === conditionVal || conditionSelect.options[i].text === conditionVal) {
            conditionSelect.selectedIndex = i;
            found = true;
            break;
        }
    }
    if(!found) {
        conditionSelect.selectedIndex = 0;
    }

    if (row.asset_type === 'Waqf') {
        document.getElementById('typeWaqf').checked = true;
        document.getElementById('donor_name').value = row.donor_name || '';
        document.getElementById('donor_father').value = row.donor_father || '';
        document.getElementById('donor_phone').value = row.donor_phone || '';
        document.getElementById('donor_address').value = row.donor_address || '';
    } else {
        document.getElementById('typePurchased').checked = true;
    }
    
    toggleWaqfFields();
    document.getElementById('modalTitle').innerText = '<?php echo ($lang === 'ur') ? 'اثاثہ میں ترمیم کریں' : 'Edit Asset'; ?>';
    new bootstrap.Modal(document.getElementById('assetModal')).show();
}
</script>

<?php include 'footer.php'; ?>
