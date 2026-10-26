<?php
// سیکیورٹی اور ڈیبگنگ
ini_set('display_errors', 0);
error_reporting(0);

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

if (isset($_GET['lang']) && in_array($_GET['lang'], ['ur', 'en'])) {
    $_SESSION['lang'] = $_GET['lang'];
    setcookie('lang', $_GET['lang'], time() + (86400 * 365), '/');
}
$lang = $_SESSION['lang'] ?? ($_COOKIE['lang'] ?? 'ur');

require_once 'db.php';

// اگر پہلے سے لاگ ان ہے تو ڈیش بورڈ پر بھیج دیں
if (isset($_SESSION['user_id'])) {
    echo "<script>window.location.href='dashboard.php';</script>";
    exit;
}

$error = '';

if (isset($_POST['login'])) {
    $username = trim($_POST['username']);
    $password = trim($_POST['password']);

    try {
        // 1. پہلے ایڈمن ٹیبل میں چیک کریں
        $stmt = $pdo->prepare("SELECT * FROM admins WHERE username = ?");
        $stmt->execute([$username]);
        $admin = $stmt->fetch();

        if ($admin && verify_pass($password, $admin['password'])) {
            $_SESSION['user_id'] = $admin['id'];
            $_SESSION['role'] = !empty($admin['role']) ? $admin['role'] : 'admin';
            $_SESSION['name'] = $admin['name'];
            $_SESSION['permissions'] = json_decode($admin['permissions'] ?? '[]', true) ?: [];
            if (!empty($admin['preferred_language']) && in_array($admin['preferred_language'], ['ur', 'en'], true)) {
                $lang = $admin['preferred_language'];
            }
            $_SESSION['lang'] = $lang;
            setcookie('lang', $lang, time() + (86400 * 365), '/', '', false, false);
            echo "<script>try{localStorage.setItem('madrasa_lang', '$lang');}catch(e){} window.location.href='dashboard.php';</script>";
            exit;
        } 
        
        // 2. اگر ایڈمن نہیں ہے، تو اسٹوڈنٹس/پیرنٹس ٹیبل میں چیک کریں
        $stmt = $pdo->prepare("SELECT * FROM students WHERE admission_number = ? AND is_deleted = 0");
        $stmt->execute([$username]);
        $student = $stmt->fetch();

        if ($student && verify_pass($password, $student['password'] ?? '')) {
            $_SESSION['user_id'] = $student['id'];
            $_SESSION['role'] = 'parent';
            $_SESSION['name'] = $student['name'];
            $_SESSION['adm_no'] = $student['admission_number'];
            $_SESSION['lang'] = $lang;
            setcookie('lang', $lang, time() + (86400 * 365), '/');
            echo "<script>window.location.href='dashboard.php';</script>";
            exit;
        }

        // اگر دونوں میں نہیں ملا
        $error = ($lang === 'ur') ? "غلط یوزر نیم یا پاسورڈ!" : "Invalid username or password!";

    } catch(PDOException $e) {
        $error = ($lang === 'ur') ? "لاگ ان میں دشواری پیش آ رہی ہے۔" : "An error occurred during login.";
    }
}
?>

<!DOCTYPE html>
<html lang="<?php echo $lang; ?>" dir="<?php echo ($lang=='ur') ? 'rtl' : 'ltr'; ?>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo ($lang=='ur') ? 'لاگ ان - ' . e(t('app_name')) : 'Login - ' . e(t('app_name')); ?></title>
    
    <script>
        // Immediate theme load logic to prevent FOUC
        (function() {
            const savedTheme = localStorage.getItem('theme') || 'default';
            if (savedTheme !== 'default') {
                document.documentElement.className = 'theme-' + savedTheme;
            }
        })();
    </script>

    <?php if ($lang === 'ur'): ?>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.rtl.min.css">
    <link href="https://fonts.googleapis.com/css2?family=Noto+Nastaliq+Urdu:wght@400;700&display=swap" rel="stylesheet">
    <?php else: ?>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <?php endif; ?>
    
    <?php include __DIR__ . '/theme_styles.php'; ?>

    <style>
        body {
            font-family: <?php echo ($lang === 'ur') ? "'Noto Nastaliq Urdu', serif" : "'Inter', -apple-system, BlinkMacSystemFont, sans-serif"; ?>;
            background-color: var(--bg) !important;
            color: var(--text-main) !important;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            transition: background-color 0.3s ease, color 0.3s ease;
        }
        .login-box {
            background: var(--card-bg) !important;
            color: var(--text-main) !important;
            padding: 35px;
            border-radius: 15px;
            width: 100%;
            max-width: 420px;
            box-shadow: var(--card-shadow) !important;
            border: 1px solid var(--card-border) !important;
        }
    </style>
</head>
<body>
    <div class="login-box text-center">
        <!-- Language Switcher Pill -->
        <div class="d-flex justify-content-end mb-2">
            <div class="btn-group btn-group-sm rounded-pill border p-1 bg-light">
                <a href="login.php?lang=ur" onclick="setLoginLanguage('ur');" class="btn btn-sm rounded-pill px-2 py-0 <?php echo ($lang==='ur') ? 'btn-success text-white fw-bold' : 'text-dark'; ?>" style="font-size: 11px;">اردو</a>
                <a href="login.php?lang=en" onclick="setLoginLanguage('en');" class="btn btn-sm rounded-pill px-2 py-0 <?php echo ($lang==='en') ? 'btn-success text-white fw-bold' : 'text-dark'; ?>" style="font-size: 11px;">English</a>
            </div>
        </div>
        <script>
        function setLoginLanguage(l) {
            try { localStorage.setItem('madrasa_lang', l); } catch(e){}
            document.cookie = "lang=" + l + "; path=/; max-age=31536000; SameSite=Lax";
        }
        (function() {
            var stored = localStorage.getItem('madrasa_lang');
            var cur = '<?php echo $lang; ?>';
            if (stored && (stored === 'ur' || stored === 'en') && stored !== cur && !window.location.search.includes('lang=')) {
                document.cookie = "lang=" + stored + "; path=/; max-age=31536000; SameSite=Lax";
                var sep = window.location.search ? '&' : '?';
                window.location.href = window.location.pathname + window.location.search + sep + 'lang=' + stored;
            }
        })();
        </script>

        <img src="logo.png" alt="Logo" style="width: 80px; height: 80px; border-radius: 50%; border: 2px solid var(--primary); margin-bottom: 15px; background: white; object-fit: contain;">
        <h3 class="mb-2 text-success fw-bold"><?php echo e(t('app_name')); ?></h3>
        <p class="text-muted small mb-4"><?php echo ($lang=='ur') ? 'جامع نظامِ انتظام و تعلیم (Management ERP)' : 'Madrasa & Masjid Management ERP'; ?></p>
        
        <?php if($error): ?>
            <div class="alert alert-danger p-2 small"><?php echo $error; ?></div>
        <?php endif; ?>
        
        <form method="POST">
            <div class="mb-3 text-start">
                <label class="form-label text-success fw-bold"><?php echo ($lang=='ur') ? 'یوزر نیم / داخلہ نمبر' : 'Username / Admission No'; ?></label>
                <input type="text" name="username" class="form-control" required placeholder="<?php echo ($lang=='ur') ? 'یوزر نیم لکھیں...' : 'Enter Username...'; ?>">
            </div>
            <div class="mb-4 text-start">
                <label class="form-label text-success fw-bold"><?php echo ($lang=='ur') ? 'پاسورڈ' : 'Password'; ?></label>
                <input type="password" name="password" class="form-control" required placeholder="<?php echo ($lang=='ur') ? 'پاسورڈ لکھیں...' : 'Enter Password...'; ?>">
            </div>
            <button type="submit" name="login" class="btn btn-success w-100 py-2 fw-bold shadow-sm"><?php echo ($lang=='ur') ? 'لاگ ان کریں' : 'Sign In'; ?></button>
        </form>
        
        <div class="mt-4 pt-2 border-top">
            <a href="forgot_password.php" class="text-danger text-decoration-none small d-block mb-2"><?php echo ($lang=='ur') ? 'پاسورڈ بھول گئے؟ (Forgot Password)' : 'Forgot Password?'; ?></a>
            <a href="index.php" class="small text-muted text-decoration-none"><?php echo ($lang=='ur') ? '← ہوم پیج پر واپس جائیں' : '← Back to Home'; ?></a>
        </div>
    </div>
</body>
</html>
