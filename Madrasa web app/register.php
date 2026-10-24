<?php
/**
 * ════════════════════════════════════════════════════════════════════
 *  نیا ادارہ رجسٹریشن — 14 روزہ مفت آزمائش (Self-Service Onboarding)
 *  Madrasa & Masjid SaaS Tenant Registration
 * ════════════════════════════════════════════════════════════════════
 */

ini_set('display_errors', 0);
error_reporting(0);

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

require_once __DIR__ . '/db.php';

$error = '';
$success = '';

$allowRegistration = (int)get_saas_setting($pdo, 'allow_public_registration', 1);

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['register'])) {
    if (!$allowRegistration) {
        $error = "معذرت! نئے اداروں کی آن لائن رجسٹریشن فی الوقت بند ہے۔ براہِ کرم ایڈمن سے رابطہ کریں۔";
    } else {
        $instituteName = trim($_POST['institute_name'] ?? '');
        $instituteCode = strtoupper(trim($_POST['institute_code'] ?? ''));
        $systemType = in_array($_POST['system_type'] ?? '', ['Madrasa', 'Masjid']) ? $_POST['system_type'] : 'Madrasa';
        $adminName = trim($_POST['admin_name'] ?? '');
        $username = trim($_POST['username'] ?? '');
        $password = trim($_POST['password'] ?? '');
        $phone = trim($_POST['phone'] ?? '');
        $city = trim($_POST['city'] ?? '');
        $address = trim($_POST['address'] ?? '');

        // Validation
        if (empty($instituteName) || empty($instituteCode) || empty($adminName) || empty($username) || empty($password)) {
            $error = "براہ کرم تمام لازمی فیلڈز پر کریں۔";
        } elseif (!preg_match('/^[A-Z0-9_-]{3,20}$/', $instituteCode)) {
            $error = "ادارہ کوڈ میں صرف انگریزی حروف، اعداد اور منفی (-) علامت ہو سکتی ہے (3 تا 20 حروف)۔ مثال: ASHRAF01";
        } elseif (strlen($password) < 6) {
            $error = "پاسورڈ کم از کم 6 حروف کا ہونا چاہیے۔";
        } else {
            try {
                // Check if tenant code already exists
                $checkStmt = $pdo->prepare("SELECT id FROM tenants WHERE UPPER(code) = ? LIMIT 1");
                $checkStmt->execute([$instituteCode]);
            if ($checkStmt->fetch()) {
                $error = "ادارہ کوڈ '{$instituteCode}' پہلے سے کسی دوسرے ادارے کے زیرِ استعمال ہے۔ براہ کرم کوئی اور کوڈ چنیں۔";
            } else {
                // Check if admin username exists in general
                $pdo->beginTransaction();

                // 1. Create Tenant with 14-day trial
                $trialEnds = date('Y-m-d', strtotime('+14 days'));
                $slug = strtolower(preg_replace('/[^a-zA-Z0-9]+/', '-', $instituteCode));
                $defaultModulesJson = json_encode(function_exists('get_default_module_keys') ? get_default_module_keys() : []);
                try {
                    $tenantStmt = $pdo->prepare("INSERT INTO tenants 
                        (code, name, slug, phone, address, city, status, trial_ends_at, max_students, max_teachers, max_admins, allowed_modules) 
                        VALUES (?, ?, ?, ?, ?, ?, 'trial', ?, 50, 10, 3, ?)");
                    $tenantStmt->execute([$instituteCode, $instituteName, $slug, $phone, $address, $city, $trialEnds, $defaultModulesJson]);
                } catch (Throwable $eIns) {
                    $pdo->exec("ALTER TABLE `tenants` ADD COLUMN `allowed_modules` TEXT DEFAULT NULL");
                    $tenantStmt = $pdo->prepare("INSERT INTO tenants 
                        (code, name, slug, phone, address, city, status, trial_ends_at, max_students, max_teachers, max_admins, allowed_modules) 
                        VALUES (?, ?, ?, ?, ?, ?, 'trial', ?, 50, 10, 3, ?)");
                    $tenantStmt->execute([$instituteCode, $instituteName, $slug, $phone, $address, $city, $trialEnds, $defaultModulesJson]);
                }
                $tenantId = (int)$pdo->lastInsertId();

                // 2. Assign Free Trial Subscription
                $trialPlanId = $pdo->query("SELECT id FROM subscription_plans WHERE is_free_trial = 1 LIMIT 1")->fetchColumn();
                if (!$trialPlanId) {
                    $trialPlanId = $pdo->query("SELECT id FROM subscription_plans ORDER BY id ASC LIMIT 1")->fetchColumn() ?: 1;
                }
                $subStmt = $pdo->prepare("INSERT INTO subscriptions 
                    (tenant_id, plan_id, billing_cycle, starts_at, ends_at, status, payment_method) 
                    VALUES (?, ?, 'monthly', CURDATE(), ?, 'trial', 'free_trial')");
                $subStmt->execute([$tenantId, $trialPlanId, $trialEnds]);

                // 3. Create Admin for this Tenant
                $hashedPass = password_hash($password, PASSWORD_DEFAULT);
                $allPerms = json_encode([
                    'manage_students','manage_teachers','manage_attendance','manage_hifz',
                    'manage_academics','manage_finance','manage_requests','manage_notices',
                    'manage_exams','manage_classes','manage_erp','manage_teacher_attendance',
                    'manage_loans','manage_stipends'
                ]);
                $adminStmt = $pdo->prepare("INSERT INTO admins 
                    (tenant_id, name, username, password, role, permissions, system_type) 
                    VALUES (?, ?, ?, ?, 'admin', ?, ?)");
                $adminStmt->execute([$tenantId, $adminName, $username, $hashedPass, $allPerms, $systemType]);
                $adminId = (int)$pdo->lastInsertId();

                // 4. Create default settings row for this tenant
                $setStmt = $pdo->prepare("INSERT INTO settings 
                    (tenant_id, madrasa_name, phone, address, current_hijri_year, week_start_day) 
                    VALUES (?, ?, ?, ?, '1447', 6)");
                $setStmt->execute([$tenantId, $instituteName, $phone, $address]);

                // 5. Create default basic accounting heads for this tenant
                $heads = [
                    ['ماہانہ فیس', 'آمدن'],
                    ['عطیات و صدقات', 'آمدن'],
                    ['زکوۃ', 'آمدن'],
                    ['اساتذہ مشاہرہ', 'اخراجات'],
                    ['بجلی و گیس بل', 'اخراجات'],
                    ['مرمت و دیکھ بھال', 'اخراجات']
                ];
                $headStmt = $pdo->prepare("INSERT INTO heads (tenant_id, name, type) VALUES (?, ?, ?)");
                foreach ($heads as $h) {
                    $headStmt->execute([$tenantId, $h[0], $h[1]]);
                }

                $pdo->commit();

                // Auto login new admin
                $_SESSION['user_id'] = $adminId;
                $_SESSION['role'] = 'admin';
                $_SESSION['name'] = $adminName;
                $_SESSION['username'] = $username;
                $_SESSION['permissions'] = json_decode($allPerms, true);
                $_SESSION['system_type'] = $systemType;
                $_SESSION['tenant_id'] = $tenantId;
                $_SESSION['tenant_code'] = $instituteCode;
                $_SESSION['tenant_name'] = $instituteName;

                setcookie('last_tenant_code', $instituteCode, time() + (86400 * 30), '/');

                echo "<script>alert('مبارک ہو! آپ کا ادارہ کامیابی سے رجسٹر ہو گیا ہے اور 14 دن کا مفت ٹرائل فعال کر دیا گیا ہے۔'); window.location.href='dashboard.php';</script>";
                exit;
            }
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            $error = "رجسٹریشن میں خرابی: " . $e->getMessage();
        }
    }
    }
}
?>
<!DOCTYPE html>
<html lang="ur" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>نیا ادارہ رجسٹریشن — کلاؤڈ ساس پلیٹ فارم</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.rtl.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link href="https://fonts.googleapis.com/css2?family=Noto+Nastaliq+Urdu:wght@400;700&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Noto Nastaliq Urdu', Tahoma, Arial, sans-serif;
            background: linear-gradient(135deg, #064e3b 0%, #0f172a 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            color: #1e293b;
        }
        .register-card {
            background: #ffffff;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.3);
            max-width: 650px;
            width: 100%;
            padding: 35px;
        }
        .form-label { font-weight: 600; font-size: 0.9rem; color: #064e3b; }
        .input-group-text { background: #f0fdf4; border-color: #86efac; }
        .btn-register {
            background: #059669;
            color: #fff;
            padding: 12px;
            border-radius: 12px;
            font-weight: bold;
            font-size: 1.1rem;
            border: none;
            transition: all 0.2s;
        }
        .btn-register:hover { background: #047857; }
    </style>
</head>
<body>

<div class="register-card">
    <div class="text-center mb-4">
        <img src="logo.png" alt="Logo" style="width: 70px; height: 70px; object-fit: contain; margin-bottom: 10px;">
        <h3 class="fw-bold text-success mb-1">نیا ادارہ آن لائن رجسٹریشن</h3>
        <p class="text-muted small mb-0">14 روزہ مفت ٹرائل حاصل کریں — فوری طور پر مدرسہ یا مسجد مینجمنٹ شروع کریں</p>
    </div>

    <?php if (!empty($error)): ?>
        <div class="alert alert-danger p-2 small mb-3"><?php echo htmlspecialchars($error); ?></div>
    <?php endif; ?>

    <?php if (!$allowRegistration): ?>
        <div class="text-center py-4 bg-light rounded-4 border p-4">
            <div class="mb-3 text-warning">
                <i class="fas fa-lock fa-3x"></i>
            </div>
            <h5 class="fw-bold text-dark">آن لائن رجسٹریشن فی الوقت بند ہے</h5>
            <p class="text-muted small mt-2">
                معذرت! نظام میں نئے اداروں کی خودکار رجسٹریشن عارضی طور پر بند کر دی گئی ہے۔<br>
                اگر آپ اپنے مدرسہ یا مسجد کے لیے سبسکرپشن چاہتے ہیں تو براہِ کرم ہمارے ایڈمن سے رابطہ فرمائیں۔
            </p>
            <div class="mt-3">
                <a href="login.php" class="btn btn-success rounded-pill px-4">← لاگ ان اسکرین پر جائیں</a>
            </div>
        </div>
    <?php else: ?>

    <form method="POST">
        <div class="row g-3">
            <div class="col-12 col-md-8">
                <label class="form-label">ادارے کا پورا نام (مدرسہ / جامعہ / مسجد) <span class="text-danger">*</span></label>
                <input type="text" name="institute_name" class="form-control" required placeholder="مثال: جامعہ دارالعلوم فاروقیہ" value="<?php echo htmlspecialchars($_POST['institute_name'] ?? ''); ?>">
            </div>

            <div class="col-12 col-md-4">
                <label class="form-label">مطلوبہ ادارہ کوڈ <span class="text-danger">*</span></label>
                <input type="text" name="institute_code" class="form-control text-uppercase fw-bold" required placeholder="FAROOQ01" value="<?php echo htmlspecialchars($_POST['institute_code'] ?? ''); ?>">
                <small class="text-muted" style="font-size: 0.7rem;">صرف انگریزی حروف/اعداد</small>
            </div>

            <div class="col-12 col-md-6">
                <label class="form-label">بنیادی نظام منتخب کریں <span class="text-danger">*</span></label>
                <select name="system_type" class="form-select" required>
                    <option value="Madrasa">مدرسہ (تعلیمی و اقامتی نظام)</option>
                    <option value="Masjid">مسجد و مکتب (نماز و مکتب نظام)</option>
                </select>
            </div>

            <div class="col-12 col-md-6">
                <label class="form-label">شہر <span class="text-muted small">(اختیاری)</span></label>
                <input type="text" name="city" class="form-control" placeholder="لاہور / کراچی / اسلام آباد" value="<?php echo htmlspecialchars($_POST['city'] ?? ''); ?>">
            </div>

            <div class="col-12 col-md-6">
                <label class="form-label">مہتمم / ناظم کا نام <span class="text-danger">*</span></label>
                <input type="text" name="admin_name" class="form-control" required placeholder="مولانا محمد احمد" value="<?php echo htmlspecialchars($_POST['admin_name'] ?? ''); ?>">
            </div>

            <div class="col-12 col-md-6">
                <label class="form-label">رابطہ نمبر / فون <span class="text-danger">*</span></label>
                <input type="text" name="phone" class="form-control" required placeholder="03001234567" value="<?php echo htmlspecialchars($_POST['phone'] ?? ''); ?>">
            </div>

            <div class="col-12">
                <label class="form-label">پتہ <span class="text-muted small">(اختیاری)</span></label>
                <input type="text" name="address" class="form-control" placeholder="مکمل پتہ درج کریں..." value="<?php echo htmlspecialchars($_POST['address'] ?? ''); ?>">
            </div>

            <div class="col-12 pt-2 border-top">
                <h6 class="fw-bold text-success mb-2"><i class="fas fa-lock me-1"></i> ایڈمن لاگ ان معلومات</h6>
            </div>

            <div class="col-12 col-md-6">
                <label class="form-label">ایڈمن یوزر نیم <span class="text-danger">*</span></label>
                <input type="text" name="username" class="form-control" required placeholder="admin" value="<?php echo htmlspecialchars($_POST['username'] ?? ''); ?>">
            </div>

            <div class="col-12 col-md-6">
                <label class="form-label">پاسورڈ (کم از کم 6 حروف) <span class="text-danger">*</span></label>
                <div class="input-group">
                    <input type="password" name="password" id="reg_pass" class="form-control" required placeholder="••••••••">
                    <button class="btn btn-outline-secondary" type="button" onclick="toggleRegPass()">
                        <i class="fas fa-eye" id="reg_eye_icon"></i>
                    </button>
                </div>
            </div>
        </div>

        <div class="alert alert-success bg-opacity-25 border-success small mt-3 mb-3 p-2">
            <i class="fas fa-check-circle me-1 text-success"></i> <strong>14 دن مفت ٹرائل:</strong> کوئی کریڈٹ کارڈ درکار نہیں ہے۔ تمام فیچرز، موبائل ایپ سپورٹ اور کلاؤڈ بیک اپ فوری فعال ہوگا۔
        </div>

        <button type="submit" name="register" value="1" class="btn btn-register w-100 py-2">
            🚀 ادارہ رجسٹر کریں اور فوری شروع کریں
        </button>
    </form>
    <?php endif; ?>

    <div class="text-center mt-3 pt-2 border-top">
        <span class="small text-muted">پہلے سے رجسٹرڈ ہیں؟</span>
        <a href="login.php" class="small fw-bold text-success text-decoration-none ms-1">یہاں لاگ ان کریں</a>
    </div>
</div>

<script>
function toggleRegPass() {
    var p = document.getElementById('reg_pass');
    var icon = document.getElementById('reg_eye_icon');
    if (p.type === 'password') {
        p.type = 'text';
        icon.classList.remove('fa-eye');
        icon.classList.add('fa-eye-slash');
    } else {
        p.type = 'password';
        icon.classList.remove('fa-eye-slash');
        icon.classList.add('fa-eye');
    }
}
</script>
</body>
</html>
