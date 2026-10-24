<?php
if (session_status() === PHP_SESSION_NONE) { session_start(); }
require_once 'db.php';
$is_admin = (($_SESSION['role'] ?? '') === 'admin');
if (!isset($_SESSION['user_id']) || (!$is_admin && !app_has_perm('manage_exams') && !app_has_perm('manage_masjid_exams'))) {
    $sys = $_SESSION['system_type'] ?? 'Madrasa';
    header("Location: " . ($sys === 'Masjid' ? "masjid_dashboard.php" : "dashboard.php"));
    exit;
}

$cur_tenant_id = (int)get_current_tenant_id();
$msg_exam = '';
$err_exam = '';

if (isset($_POST['add_exam'])) {
    try {
        $sys_post = $_SESSION['system_type'] ?? 'Madrasa';
        $stmt = $pdo->prepare("INSERT INTO exams (exam_name, exam_date, total_marks, passing_marks, system_type, tenant_id) VALUES (?, ?, ?, ?, ?, ?)");
        $stmt->execute([$_POST['name'], $_POST['date'], $_POST['total_marks'], $_POST['passing_marks'], $sys_post, $cur_tenant_id]);
        $msg_exam = 'نیا امتحان کامیابی سے شامل کر دیا گیا!';
    } catch (Exception $e) {
        error_log('[exams.php] add_exam error: ' . $e->getMessage());
        $err_exam = 'امتحان شامل کرنے میں غلطی ہوئی۔ براہ کرم دوبارہ کوشش کریں۔';
    }
}

include 'header.php';
?>
<?php if ($msg_exam): ?>
<div class='alert alert-success shadow-sm fw-bold'>✅ <?php echo htmlspecialchars($msg_exam); ?></div>
<?php endif; ?>
<?php if ($err_exam): ?>
<div class='alert alert-danger shadow-sm fw-bold'>❌ <?php echo htmlspecialchars($err_exam); ?></div>
<?php endif; ?>

<h2 class="mb-4">امتحانات کی فہرست (Exams List)</h2>
<div class="card p-4 mb-4">
    <form method="POST" class="row g-3">
        <div class="col-md-4">
            <label class="form-label fw-bold">امتحان کا نام</label>
            <input type="text" name="name" class="form-control" placeholder="مثلاً: سالانہ امتحان 2024" required>
        </div>
        <div class="col-md-2">
            <label class="form-label fw-bold">تاریخ</label>
            <input type="date" name="date" class="form-control" value="<?php echo date('Y-m-d'); ?>" required>
        </div>
        <div class="col-md-2">
            <label class="form-label fw-bold">کل نمبر</label>
            <input type="number" name="total_marks" class="form-control" value="100" required>
        </div>
        <div class="col-md-2">
            <label class="form-label fw-bold">پاسنگ مارکس</label>
            <input type="number" name="passing_marks" class="form-control" value="33" required>
        </div>
        <div class="col-md-2 d-flex align-items-end">
            <button type="submit" name="add_exam" class="btn btn-primary w-100 fw-bold">شامل کریں</button>
        </div>
    </form>
</div>
<div class="neobox p-0 overflow-hidden shadow-sm">
    <table class="table table-hover mb-0 align-middle">
        <thead class="table-dark">
            <tr>
                <th class="px-4">ID</th>
                <th>امتحان کا نام</th>
                <th>تاریخ</th>
                <th class="text-center">ایکشن</th>
            </tr>
        </thead>
        <tbody>
            <?php
            $sys = $_SESSION['system_type'] ?? 'Madrasa';
            $sys_cond = ($sys === 'Masjid') ? "system_type = 'Masjid'" : "(system_type = 'Madrasa' OR system_type IS NULL OR system_type = '')";
            $allowed_classes = get_allowed_classes($pdo);
            $allowed_class_names = array_column($allowed_classes, 'name');
            $class_condition = empty($allowed_class_names) ? "1=0" : "class IN (" . implode(',', array_map(function($c) use ($pdo) { return $pdo->quote($c); }, $allowed_class_names)) . ")";
            
            $sql = "SELECT e.*, 
                    (SELECT COUNT(*) FROM exam_results WHERE exam_id = e.id AND tenant_id = $cur_tenant_id) as result_count,
                    (SELECT COUNT(*) FROM students WHERE tenant_id = $cur_tenant_id AND status='Active' AND (is_deleted=0 OR is_deleted IS NULL) AND $sys_cond AND ($class_condition)) as total_students
                    FROM exams e WHERE e.tenant_id = $cur_tenant_id AND (is_deleted = 0 OR is_deleted IS NULL) AND $sys_cond ORDER BY id DESC";
            try {
                $exams_rows = $pdo->query($sql);
                $any_exam = false;
                foreach($exams_rows as $row) {
                    $any_exam = true;
                    $perc = $row['total_students'] > 0 ? round(($row['result_count'] / $row['total_students']) * 100) : 0;
                    $status_color = ($perc == 100) ? 'success' : 'warning';
                    $result_count = (int)$row['result_count'];
                    $total_students = (int)$row['total_students'];
                    $exam_id = (int)$row['id'];
                    $exam_name = htmlspecialchars($row['exam_name']);
                    $exam_date = htmlspecialchars($row['exam_date']);
                    $total_marks = (int)$row['total_marks'];
                    $passing_marks = (int)$row['passing_marks'];
                    echo "<tr>
                            <td class='px-4'>$exam_id</td>
                            <td>
                                <div class='fw-bold text-dark'>$exam_name</div>
                                <div class='progress mt-1' style='height: 5px; width: 100px;'>
                                    <div class='progress-bar bg-$status_color' style='width: $perc%'></div>
                                </div>
                                <small class='text-muted' style='font-size: 10px;'>رزلٹ: $perc% ($result_count/$total_students)</small>
                            </td>
                            <td>
                                <div class='fw-bold'>$exam_date</div>
                                <small class='text-muted' style='font-size: 10px;'>کل نمبر: $total_marks | پاس: $passing_marks</small>
                            </td>
                            <td class='text-center'>
                                <div class='btn-group shadow-sm'>
                                    <a href='exam_results_entry.php?exam_id=$exam_id' class='btn btn-sm btn-primary' title='رزلٹ درج کریں (عام / حفظ)'><i class='fas fa-edit'></i></a>
                                    <a href='academic_results_entry.php?exam_id=$exam_id' class='btn btn-sm btn-info text-white' title='نتائج درس نظامی و عصری علوم'><i class='fas fa-graduation-cap'></i></a>
                                    <a href='result_register.php?exam_id=$exam_id' class='btn btn-sm btn-success' title='رزلٹ رجسٹر'><i class='fas fa-list-alt'></i></a>
                                </div>
                            </td>
                          </tr>";
                }
                if (!$any_exam) {
                    echo "<tr><td colspan='4' class='text-center text-muted py-4'>ابھی کوئی امتحان موجود نہیں۔ اوپر فارم سے نیا امتحان شامل کریں۔</td></tr>";
                }
            } catch (Exception $e) {
                error_log('[exams.php] list query error: ' . $e->getMessage());
                echo "<tr><td colspan='4' class='text-center text-danger py-4'>امتحانات لوڈ کرنے میں مسئلہ۔ ایڈمن سے رابطہ کریں۔</td></tr>";
            }
            ?>
        </tbody>
    </table>
</div>
<?php include 'footer.php'; ?>
