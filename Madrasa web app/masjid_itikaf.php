<?php
if (session_status() === PHP_SESSION_NONE) { session_start(); }
require_once 'db.php';

$cur_tenant_id = (int)get_current_tenant_id();
$is_admin = (($_SESSION['role'] ?? '') === 'admin');
if (!isset($_SESSION['user_id']) || (!$is_admin && !app_has_perm('manage_requests') && !app_has_perm('manage_admissions') && !app_has_perm('manage_masjid'))) { 
    header("Location: dashboard.php"); 
    exit; 
}

// Self-healing schema checks
try { $pdo->exec("ALTER TABLE masjid_itikaf ADD COLUMN tenant_id INT NOT NULL DEFAULT 1"); } catch (Throwable $e) {}
try { $pdo->exec("ALTER TABLE masjid_itikaf ADD COLUMN is_deleted TINYINT(1) DEFAULT 0"); } catch (Throwable $e) {}
try { $pdo->exec("ALTER TABLE masjid_itikaf ADD COLUMN is_synced TINYINT(1) DEFAULT 0"); } catch (Throwable $e) {}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['action']) && $_POST['action'] === 'delete') {
        $id = (int)$_POST['id'];
        $pdo->prepare("UPDATE masjid_itikaf SET is_deleted = 1, is_synced = 0 WHERE id = ? AND (tenant_id = ? OR tenant_id IS NULL OR tenant_id = 1)")->execute([$id, $cur_tenant_id]);
    } else {
        $name = trim($_POST["name"] ?? "");
        $phone = trim($_POST["phone"] ?? "");
        $year = trim($_POST["year"] ?? date('Y'));
        $status = trim($_POST["status"] ?? "منظور شدہ");

        if (isset($_POST['id']) && !empty($_POST['id'])) {
            $id = (int)$_POST['id'];
            $stmt = $pdo->prepare("UPDATE masjid_itikaf SET name=?, phone=?, year=?, status=?, is_synced=0 WHERE id=? AND (tenant_id=? OR tenant_id IS NULL OR tenant_id=1)");
            $stmt->execute([$name, $phone, $year, $status, $id, $cur_tenant_id]);
        } else {
            $stmt = $pdo->prepare("INSERT INTO masjid_itikaf (name, phone, year, status, tenant_id) VALUES (?, ?, ?, ?, ?)");
            $stmt->execute([$name, $phone, $year, $status, $cur_tenant_id]);
        }
    }
    header("Location: masjid_itikaf.php");
    exit;
}

$records = $pdo->query("SELECT * FROM masjid_itikaf WHERE (is_deleted = 0 OR is_deleted IS NULL) AND (tenant_id = $cur_tenant_id OR tenant_id IS NULL OR tenant_id = 1) ORDER BY id DESC")->fetchAll(PDO::FETCH_ASSOC);

$title = ($lang === 'ur') ? "معتکفین کی فہرست (اعتکاف)" : "Itikaf Registration";
include 'header.php';
?>

<div class="container py-4" dir="<?php echo ($lang === 'ur') ? 'rtl' : 'ltr'; ?>">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h3 class="fw-bold text-success">
            <i class="fas fa-mosque me-2"></i><?php echo ($lang === 'ur') ? 'معتکفین کی فہرست (اعتکاف)' : 'Itikaf Registration'; ?>
        </h3>
        <button class="btn btn-success fw-bold" data-bs-toggle="modal" data-bs-target="#addModal">
            <i class="fas fa-plus me-1"></i><?php echo ($lang === 'ur') ? 'نیا معتکف شامل کریں' : 'Add Itikaf Registration'; ?>
        </button>
    </div>

    <div class="card shadow-sm border-0 neobox h-100">
        <div class="table-responsive">
            <table class="table table-hover align-middle mb-0">
                <thead class="table-light">
                    <tr>
                        <th><?php echo ($lang === 'ur') ? 'نام معتکف' : 'Name'; ?></th>
                        <th><?php echo ($lang === 'ur') ? 'رابطہ فون نمبر' : 'Phone Number'; ?></th>
                        <th><?php echo ($lang === 'ur') ? 'سال' : 'Year'; ?></th>
                        <th><?php echo ($lang === 'ur') ? 'حیثیت' : 'Status'; ?></th>
                        <th class="text-center"><?php echo ($lang === 'ur') ? 'ایکشن' : 'Actions'; ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach($records as $row): ?>
                    <tr>
                        <td class="fw-bold"><?php echo htmlspecialchars((string)$row["name"]); ?></td>
                        <td><?php echo htmlspecialchars((string)$row["phone"]); ?></td>
                        <td><span class="badge bg-light text-dark border"><?php echo htmlspecialchars((string)$row["year"]); ?></span></td>
                        <td><span class="badge bg-success"><?php echo htmlspecialchars((string)$row["status"]); ?></span></td>
                        <td class="text-center">
                            <form method="POST" class="d-inline" onsubmit="return confirm('<?php echo ($lang === 'ur') ? 'کیا آپ واقعی اس ریکارڈ کو حذف کرنا چاہتے ہیں؟' : 'Are you sure you want to delete this record?'; ?>');">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="id" value="<?php echo $row['id']; ?>">
                                <button type="submit" class="btn btn-sm btn-outline-danger" title="<?php echo ($lang === 'ur') ? 'حذف' : 'Delete'; ?>"><i class="fas fa-trash"></i></button>
                            </form>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                    <?php if (empty($records)): ?>
                    <tr><td colspan="5" class="text-center text-muted py-4"><?php echo ($lang === 'ur') ? 'کوئی معتکف رجسٹرڈ نہیں ہے۔' : 'No Itikaf records found.'; ?></td></tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<div class="modal fade" id="addModal" tabindex="-1">
  <div class="modal-dialog">
    <div class="modal-content">
      <form method="POST">
        <div class="modal-header bg-success text-white">
          <h5 class="modal-title"><?php echo ($lang === 'ur') ? 'نیا معتکف شامل کریں' : 'Add Itikaf Registration'; ?></h5>
          <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
        </div>
        <div class="modal-body" dir="<?php echo ($lang === 'ur') ? 'rtl' : 'ltr'; ?>">
            <div class="mb-3">
                <label class="form-label fw-bold"><?php echo ($lang === 'ur') ? 'نام معتکف' : 'Name'; ?> <span class="text-danger">*</span></label>
                <input type="text" name="name" class="form-control" required>
            </div>
            <div class="mb-3">
                <label class="form-label fw-bold"><?php echo ($lang === 'ur') ? 'رابطہ فون نمبر' : 'Phone Number'; ?> <span class="text-danger">*</span></label>
                <input type="text" name="phone" class="form-control" dir="ltr" required>
            </div>
            <div class="mb-3">
                <label class="form-label fw-bold"><?php echo ($lang === 'ur') ? 'سال' : 'Year'; ?> <span class="text-danger">*</span></label>
                <input type="number" name="year" class="form-control" value="<?php echo date('Y'); ?>" required>
            </div>
            <div class="mb-3">
                <label class="form-label fw-bold"><?php echo ($lang === 'ur') ? 'حیثیت' : 'Status'; ?> <span class="text-danger">*</span></label>
                <select name="status" class="form-select" required>
                    <option value="منظور شدہ"><?php echo ($lang === 'ur') ? 'منظور شدہ' : 'Approved'; ?></option>
                    <option value="زیرِ غور"><?php echo ($lang === 'ur') ? 'زیرِ غور' : 'Pending'; ?></option>
                    <option value="مکمل"><?php echo ($lang === 'ur') ? 'مکمل' : 'Completed'; ?></option>
                </select>
            </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-bs-dismiss="modal"><?php echo ($lang === 'ur') ? 'منسوخ' : 'Cancel'; ?></button>
          <button type="submit" class="btn btn-success"><?php echo ($lang === 'ur') ? 'محفوظ کریں' : 'Save Record'; ?></button>
        </div>
      </form>
    </div>
  </div>
</div>

<?php include 'footer.php'; ?>
