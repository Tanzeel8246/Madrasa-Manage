<?php
// manage_users.php
session_start();
require_once 'db.php';
if (!isset($_SESSION['user_id']) || $_SESSION['role'] !== 'admin') {
    header("Location: dashboard.php");
    exit;
}

$msg = '';
$err = '';

// Handle add / edit
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['save_user'])) {
        $id = $_POST['user_id'] ?? '';
        $name = trim($_POST['name'] ?? '');
        $username = trim($_POST['username'] ?? '');
        $role = $_POST['role'] ?? 'admin';
        $password = $_POST['password'] ?? '';
        $permissions = isset($_POST['permissions']) ? json_encode($_POST['permissions']) : '[]';
        $allowed_classes = isset($_POST['allowed_classes']) ? json_encode($_POST['allowed_classes']) : '[]';

        try {
            if ($id) { // update
                if (!empty($password)) {
                    $hashed = hash_pass($password);
                    $stmt = $pdo->prepare("UPDATE admins SET name=?, username=?, role=?, permissions=?, allowed_classes=?, password=? WHERE id=?");
                    $stmt->execute([$name, $username, $role, $permissions, $allowed_classes, $hashed, $id]);
                } else {
                    $stmt = $pdo->prepare("UPDATE admins SET name=?, username=?, role=?, permissions=?, allowed_classes=? WHERE id=?");
                    $stmt->execute([$name, $username, $role, $permissions, $allowed_classes, $id]);
                }
                $msg = "یوزر کامیابی سے اپڈیٹ ہو گیا۔";
            } else { // insert
                $hashed = hash_pass($password);
                $stmt = $pdo->prepare("INSERT INTO admins (name, username, password, role, permissions, allowed_classes) VALUES (?, ?, ?, ?, ?, ?)");
                $stmt->execute([$name, $username, $hashed, $role, $permissions, $allowed_classes]);
                $msg = "نیا یوزر شامل کر دیا گیا۔";
            }
        } catch (PDOException $e) {
            $err = "ڈیٹا بیس ایرر: " . $e->getMessage();
        }
    } elseif (isset($_POST['delete_user'])) {
        $id = $_POST['delete_user'];
        if ($id != $_SESSION['user_id']) { // Don't delete self
            $pdo->prepare("DELETE FROM admins WHERE id=?")->execute([$id]);
            $msg = "یوزر حذف کر دیا گیا۔";
        } else {
            $err = "آپ اپنا اکاؤنٹ ڈیلیٹ نہیں کر سکتے۔";
        }
    }
}

$users = $pdo->query("SELECT * FROM admins ORDER BY id")->fetchAll();
$all_classes = $pdo->query("SELECT * FROM classes ORDER BY name ASC")->fetchAll(PDO::FETCH_ASSOC);
include 'header.php';

$all_perms = [
    'manage_classes' => 'کلاسز کا انتظام',
    'manage_students' => 'طلباء کا ریکارڈ',
    'manage_teachers' => 'اساتذہ کا ریکارڈ',
    'manage_attendance' => 'طالب علموں کی حاضری',
    'manage_teacher_attendance' => 'اساتذہ کی حاضری',
    'manage_hifz' => 'حفظ (روزانہ اندراج و رپورٹ)',
    'manage_hifz_daily' => 'حفظ (روزانہ اندراج)',
    'manage_hifz_report' => 'حفظ (تعلیمی رپورٹ)',
    'manage_academic_dashboard' => 'تعلیمی کارکردگی (اندراج ڈیش بورڈ)',
    'manage_academic_entry' => 'تعلیمی رپورٹ (اندراج)',
    'manage_academic_view' => 'تعلیمی کارکردگی (رپورٹ دیکھیں)',
    'manage_academics' => 'تعلیمی رپورٹ (جنرل)',
    'manage_exams' => 'امتحانات و نتائج',
    'manage_finance' => 'آمدن و خرچ (سادہ فنانس)',
    'manage_erp' => 'ای آر پی اکاؤنٹس (ERP Accounting)',
    'manage_admissions' => 'داخلہ درخواستیں',
    'manage_notices' => 'نوٹس بورڈ / اعلانات',
    'manage_requests' => 'درخواستیں و شکایات',
    'add_complaint' => 'شکایت اندراج',
    'manage_complaints' => 'شکایات ریکارڈ',
    'manage_users' => 'یوزرز کا انتظام (User Management)',
];
?>

<?php if ($msg) echo "<div class='alert alert-success'>$msg</div>"; ?>
<?php if ($err) echo "<div class='alert alert-danger'>$err</div>"; ?>

<div class="row">
    <div class="col-md-4">
        <div class="card shadow-sm mb-4">
            <div class="card-header bg-primary text-white fw-bold" id="form_card_title"><?php echo t('add_new_user'); ?></div>
            <div class="card-body">
                <form method="POST" id="user_form">
                    <input type="hidden" name="user_id" id="form_user_id" value="">
                    <div id="edit_alert" class="alert alert-warning d-none py-2">
                        <i class="fas fa-pen"></i> <strong>ترمیم موڈ</strong> — یوزر کی معلومات تبدیل کریں
                    </div>
                    <div class="mb-3">
                        <label><?php echo t('name'); ?></label>
                        <input type="text" name="name" id="form_name" class="form-control" required>
                    </div>
                    <div class="mb-3">
                        <label><?php echo t('username'); ?></label>
                        <input type="text" name="username" id="form_username" class="form-control" required>
                    </div>
                    <div class="mb-3">
                        <label>پاس ورڈ <small class="text-muted">(تبدیل نہ کرنے کی صورت میں خالی چھوڑیں)</small></label>
                        <input type="password" name="password" class="form-control">
                    </div>
                    <div class="mb-3">
                        <label>رول (Role)</label>
                        <select name="role" id="form_role" class="form-select">
                            <option value="admin">ایڈمن (Admin - Full Access)</option>
                            <option value="nazim">ناظم (Nazim)</option>
                            <option value="teacher">استاد (Teacher)</option>
                        </select>
                    </div>
                    <div class="mb-3">
                        <div class="d-flex justify-content-between align-items-center mb-1">
                            <label class="fw-bold"><?php echo t('permissions'); ?></label>
                            <div>
                                <button type="button" class="btn btn-sm btn-link p-0 text-decoration-none" onclick="toggleAllPerms(true)">تمام منتخب کریں</button>
                                <span class="text-muted">|</span>
                                <button type="button" class="btn btn-sm btn-link p-0 text-decoration-none text-danger" onclick="toggleAllPerms(false)">تمام ختم کریں</button>
                            </div>
                        </div>
                        <div class="border p-2 rounded" style="max-height: 220px; overflow-y:auto; background: #fafafa;">
                            <?php foreach ($all_perms as $key => $val): ?>
                            <div class="form-check mb-1">
                                <input class="form-check-input perm-cb" type="checkbox" name="permissions[]" value="<?php echo $key; ?>" id="perm_<?php echo $key; ?>">
                                <label class="form-check-label" for="perm_<?php echo $key; ?>"><?php echo $val; ?></label>
                            </div>
                            <?php endforeach; ?>
                        </div>
                        <small class="text-muted mt-1 d-block"><?php echo t('admin_perm_notice'); ?></small>
                    </div>
                    
                    <div class="mb-3">
                        <div class="d-flex justify-content-between align-items-center mb-1">
                            <label class="fw-bold">متعلقہ کلاسز (Allowed Classes)</label>
                            <div>
                                <button type="button" class="btn btn-sm btn-link p-0 text-decoration-none" onclick="toggleAllClasses(true)">تمام منتخب کریں</button>
                                <span class="text-muted">|</span>
                                <button type="button" class="btn btn-sm btn-link p-0 text-decoration-none text-danger" onclick="toggleAllClasses(false)">تمام ختم کریں</button>
                            </div>
                        </div>
                        <div class="border p-2 rounded" style="max-height: 200px; overflow-y:auto; background: #fafafa;">
                            <?php foreach ($all_classes as $cls): ?>
                            <div class="form-check mb-1">
                                <input class="form-check-input class-cb" type="checkbox" name="allowed_classes[]" value="<?php echo $cls['id']; ?>" id="class_<?php echo $cls['id']; ?>">
                                <label class="form-check-label" for="class_<?php echo $cls['id']; ?>"><?php echo e($cls['name']); ?> <?php echo !empty($cls['section']) ? ' - ' . e($cls['section']) : ''; ?></label>
                            </div>
                            <?php endforeach; ?>
                        </div>
                        <small class="text-muted mt-1 d-block">جن کلاسز کی اجازت دینا چاہتے ہیں انہیں منتخب کریں۔ (ایڈمن کے لیے یہ ضروری نہیں)</small>
                    </div>
                    
                    <button type="submit" name="save_user" class="btn btn-success w-100"><?php echo t('btn_save_ur'); ?></button>
                    <button type="button" class="btn btn-outline-secondary w-100 mt-2" onclick="resetForm()"><?php echo t('clear_form'); ?></button>
                </form>
            </div>
        </div>
    </div>
    
    <div class="col-md-8">
        <div class="card shadow-sm">
            <div class="card-header bg-dark text-white fw-bold"><?php echo t('current_users_staff'); ?></div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-hover mb-0 text-center align-middle">
                        <thead class="table-light">
                            <tr>
                                <th><?php echo t('name'); ?></th>
                                <th><?php echo t('username'); ?></th>
                                <th><?php echo t('role'); ?></th>
                                <th><?php echo t('permissions'); ?></th>
                                <th><?php echo t('action_col'); ?></th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($users as $u): ?>
                            <tr>
                                <td><?php echo e($u['name']); ?></td>
                                <td><?php echo e($u['username']); ?></td>
                                <td>
                                    <?php 
                                    if($u['role']=='admin') echo '<span class="badge bg-danger">' . t('role_admin') . '</span>';
                                    elseif($u['role']=='nazim') echo '<span class="badge bg-primary">' . t('role_nazim') . '</span>';
                                    else echo '<span class="badge bg-info">' . t('role_teacher') . '</span>';
                                    ?>
                                </td>
                                <td>
                                    <?php if ($u['role'] === 'admin'): ?>
                                        <small class="text-muted">تمام اختیارات (All)</small>
                                    <?php else: ?>
                                        <small class="text-muted"><?php echo count(json_decode($u['permissions'] ?? '[]', true) ?: []); ?> پرمیشنز</small>
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <button class="btn btn-sm btn-outline-primary" onclick='editUser(<?php echo json_encode($u); ?>)'><i class="fas fa-edit"></i></button>
                                    <?php if ($u['id'] != $_SESSION['user_id']): ?>
                                    <form method="POST" class="d-inline" onsubmit="return confirm('<?php echo t('confirm_del_user'); ?>');">
                                        <input type="hidden" name="delete_user" value="<?php echo $u['id']; ?>">
                                        <button class="btn btn-sm btn-outline-danger"><i class="fas fa-trash"></i></button>
                                    </form>
                                    <?php endif; ?>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
function toggleAllPerms(checked) {
    document.querySelectorAll('.perm-cb').forEach(cb => cb.checked = checked);
}
function toggleAllClasses(checked) {
    document.querySelectorAll('.class-cb').forEach(cb => cb.checked = checked);
}
function resetForm() {
    document.getElementById('form_user_id').value = '';
    document.getElementById('form_name').value = '';
    document.getElementById('form_username').value = '';
    document.getElementById('form_role').value = 'teacher';
    document.querySelectorAll('.perm-cb').forEach(cb => cb.checked = false);
    document.querySelectorAll('.class-cb').forEach(cb => cb.checked = false);
    document.getElementById('form_card_title').textContent = '<?php echo t("add_new_user"); ?>';
    document.getElementById('form_card_title').className = 'card-header bg-primary text-white fw-bold';
    document.getElementById('edit_alert').classList.add('d-none');
}
function editUser(u) {
    document.getElementById('form_user_id').value = u.id;
    document.getElementById('form_name').value = u.name;
    document.getElementById('form_username').value = u.username;
    document.getElementById('form_role').value = u.role || 'admin';
    
    // Update card header to show edit mode
    document.getElementById('form_card_title').textContent = 'یوزر اپڈیٹ کریں: ' + u.name;
    document.getElementById('form_card_title').className = 'card-header bg-warning text-dark fw-bold';
    document.getElementById('edit_alert').classList.remove('d-none');
    
    document.querySelectorAll('.perm-cb').forEach(cb => cb.checked = false);
    try {
        let perms = JSON.parse(u.permissions);
        if (Array.isArray(perms)) {
            perms.forEach(p => {
                let cb = document.getElementById('perm_' + p);
                if (cb) cb.checked = true;
            });
        }
    } catch(e) {}

    document.querySelectorAll('.class-cb').forEach(cb => cb.checked = false);
    try {
        let classes = JSON.parse(u.allowed_classes);
        if (Array.isArray(classes)) {
            classes.forEach(c => {
                let cb = document.getElementById('class_' + c);
                if (cb) cb.checked = true;
            });
        }
    } catch(e) {}
    
    // Scroll to form
    document.getElementById('user_form').scrollIntoView({behavior: 'smooth', block: 'start'});
}
</script>

<?php include 'footer.php'; ?>
