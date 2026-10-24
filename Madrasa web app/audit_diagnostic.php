<?php
/**
 * MC-MMS Audit Diagnostic Tool v2.1.0
 * Purpose: Diagnose S1/S2/S3 root causes on live server
 * ACCESS: Admin only - DELETE AFTER USE
 * Date: 2026-10-23
 */
if (session_status() === PHP_SESSION_NONE) { session_start(); }
require_once 'db.php';

// Security: admin only
if (!isset($_SESSION['user_id']) || strtolower($_SESSION['role'] ?? '') !== 'admin') {
    die('<div style="color:red;font-family:sans-serif;padding:20px;">Access Denied - Admin Only</div>');
}

// Enable error display for diagnostics
ini_set('display_errors', 1);
error_reporting(E_ALL);

echo '<html><head><meta charset="UTF-8"><title>Audit Diagnostic</title>';
echo '<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">';
echo '</head><body class="p-4" dir="rtl">';
echo '<h2 class="text-danger">🔍 آڈٹ ڈایاگنوسٹک رپورٹ — ' . date('Y-m-d H:i:s') . '</h2>';
echo '<hr>';

$cur_tenant_id = (int)get_current_tenant_id();

// ============ S2: Voucher System Check ============
echo '<h4 class="text-primary">S2 — واؤچر ماڈیول چیک</h4>';
try {
    $cols = $pdo->query("SHOW COLUMNS FROM acc_vouchers")->fetchAll(PDO::FETCH_COLUMN);
    echo '<p class="text-success">✅ acc_vouchers جدول موجود — کالمز: ' . implode(', ', $cols) . '</p>';
    
    $missing_cols = [];
    foreach(['is_deleted','created_by','system_type','approved_by','approved_at'] as $c) {
        if(!in_array($c, $cols)) $missing_cols[] = $c;
    }
    if($missing_cols) {
        echo '<p class="text-danger">❌ غائب کالمز: ' . implode(', ', $missing_cols) . '</p>';
        foreach($missing_cols as $mc) {
            try {
                if($mc === 'is_deleted') $pdo->exec("ALTER TABLE acc_vouchers ADD COLUMN is_deleted TINYINT(1) DEFAULT 0");
                elseif($mc === 'created_by') $pdo->exec("ALTER TABLE acc_vouchers ADD COLUMN created_by INT DEFAULT NULL");
                elseif($mc === 'system_type') $pdo->exec("ALTER TABLE acc_vouchers ADD COLUMN system_type VARCHAR(50) DEFAULT 'Madrasa'");
                elseif($mc === 'approved_by') $pdo->exec("ALTER TABLE acc_vouchers ADD COLUMN approved_by INT DEFAULT NULL");
                elseif($mc === 'approved_at') $pdo->exec("ALTER TABLE acc_vouchers ADD COLUMN approved_at DATETIME DEFAULT NULL");
                echo '<p class="text-warning">⚠️ ' . $mc . ' کالم شامل کر دیا گیا</p>';
            } catch(Throwable $e) {
                echo '<p class="text-danger">❌ ' . $mc . ' شامل کرنے میں خرابی: ' . $e->getMessage() . '</p>';
            }
        }
    } else {
        echo '<p class="text-success">✅ تمام ضروری کالمز موجود ہیں</p>';
    }
    
    // Test acc_ledger_entries
    $le_cols = $pdo->query("SHOW COLUMNS FROM acc_ledger_entries")->fetchAll(PDO::FETCH_COLUMN);
    echo '<p class="text-info">ℹ️ acc_ledger_entries کالمز: ' . implode(', ', $le_cols) . '</p>';
    
    // Test voucher count
    $v_count = (int)$pdo->query("SELECT COUNT(*) FROM acc_vouchers WHERE tenant_id = $cur_tenant_id")->fetchColumn();
    echo '<p class="text-success">✅ موجودہ واؤچرز: ' . $v_count . '</p>';
    
    // Test departments table
    try {
        $dept_cols = $pdo->query("SHOW COLUMNS FROM departments")->fetchAll(PDO::FETCH_COLUMN);
        echo '<p class="text-info">ℹ️ departments کالمز: ' . implode(', ', $dept_cols) . '</p>';
        if(!in_array('tenant_id', $dept_cols)) {
            echo '<p class="text-warning">⚠️ departments میں tenant_id نہیں — اضافہ کریں</p>';
            try {
                $pdo->exec("ALTER TABLE departments ADD COLUMN tenant_id INT DEFAULT 1");
                echo '<p class="text-success">✅ tenant_id شامل کر دیا</p>';
            } catch(Throwable $e) { echo '<p class="text-danger">خطا: ' . $e->getMessage() . '</p>'; }
        }
    } catch(Throwable $e) {
        echo '<p class="text-warning">⚠️ departments جدول نہیں ملا — بناتے ہیں</p>';
        try {
            $pdo->exec("CREATE TABLE IF NOT EXISTS departments (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255) NOT NULL, status VARCHAR(50) DEFAULT 'Active', tenant_id INT DEFAULT 1, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)");
            echo '<p class="text-success">✅ departments جدول بنا دیا</p>';
        } catch(Throwable $e2) {
            echo '<p class="text-danger">❌ departments بنانے میں خطا: ' . $e2->getMessage() . '</p>';
        }
    }
    
    // Test acc_audit_log
    try {
        $pdo->exec("CREATE TABLE IF NOT EXISTS acc_audit_log (
            id INT AUTO_INCREMENT PRIMARY KEY,
            tenant_id INT NOT NULL DEFAULT 1,
            voucher_id INT NOT NULL,
            voucher_no VARCHAR(100) DEFAULT NULL,
            action VARCHAR(50) NOT NULL,
            user_id INT DEFAULT NULL,
            user_name VARCHAR(100) DEFAULT NULL,
            details TEXT DEFAULT NULL,
            ip_address VARCHAR(50) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX (voucher_id),
            INDEX (tenant_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        echo '<p class="text-success">✅ acc_audit_log جدول تیار ہے</p>';
    } catch(Throwable $e) {
        echo '<p class="text-danger">❌ acc_audit_log خطا: ' . $e->getMessage() . '</p>';
    }

} catch(Throwable $e) {
    echo '<p class="text-danger">❌ S2 خطا: ' . $e->getMessage() . '</p>';
}

echo '<hr>';

// ============ S3: Simple Finance Check ============
echo '<h4 class="text-primary">S3 — سادہ فائنانس ماڈیول چیک</h4>';
try {
    $fin_cols = $pdo->query("SHOW COLUMNS FROM finance")->fetchAll(PDO::FETCH_COLUMN);
    echo '<p class="text-success">✅ finance جدول موجود — کالمز: ' . implode(', ', $fin_cols) . '</p>';
    
    $fin_needed = ['bill_image','is_deleted','computer_receipt_no','system_type','head_name','spender_name','account_id','payment_method','deleted_at','original_receipt_no'];
    $fin_missing = [];
    foreach($fin_needed as $c) {
        if(!in_array($c, $fin_cols)) $fin_missing[] = $c;
    }
    if($fin_missing) {
        echo '<p class="text-warning">⚠️ غائب کالمز: ' . implode(', ', $fin_missing) . '</p>';
        foreach($fin_missing as $mc) {
            try {
                switch($mc) {
                    case 'bill_image': $pdo->exec("ALTER TABLE finance ADD COLUMN bill_image VARCHAR(255) DEFAULT NULL"); break;
                    case 'is_deleted': $pdo->exec("ALTER TABLE finance ADD COLUMN is_deleted TINYINT DEFAULT 0"); break;
                    case 'computer_receipt_no': $pdo->exec("ALTER TABLE finance ADD COLUMN computer_receipt_no INT DEFAULT NULL"); break;
                    case 'system_type': $pdo->exec("ALTER TABLE finance ADD COLUMN system_type VARCHAR(50) DEFAULT 'Madrasa'"); break;
                    case 'head_name': $pdo->exec("ALTER TABLE finance ADD COLUMN head_name VARCHAR(255) DEFAULT NULL"); break;
                    case 'spender_name': $pdo->exec("ALTER TABLE finance ADD COLUMN spender_name VARCHAR(255) DEFAULT NULL"); break;
                    case 'account_id': $pdo->exec("ALTER TABLE finance ADD COLUMN account_id INT DEFAULT NULL"); break;
                    case 'payment_method': $pdo->exec("ALTER TABLE finance ADD COLUMN payment_method VARCHAR(50) DEFAULT 'Cash'"); break;
                    case 'deleted_at': $pdo->exec("ALTER TABLE finance ADD COLUMN deleted_at DATETIME DEFAULT NULL"); break;
                    case 'original_receipt_no': $pdo->exec("ALTER TABLE finance ADD COLUMN original_receipt_no VARCHAR(100) DEFAULT NULL"); break;
                }
                echo '<p class="text-success">✅ ' . $mc . ' شامل کر دیا</p>';
            } catch(Throwable $e) {
                echo '<p class="text-info">ℹ️ ' . $mc . ': ' . $e->getMessage() . '</p>';
            }
        }
    } else {
        echo '<p class="text-success">✅ تمام finance کالمز موجود ہیں</p>';
    }
    
    // Test heads table
    try {
        $h_cols = $pdo->query("SHOW COLUMNS FROM heads")->fetchAll(PDO::FETCH_COLUMN);
        echo '<p class="text-info">ℹ️ heads کالمز: ' . implode(', ', $h_cols) . '</p>';
        if(!in_array('is_deleted', $h_cols)) {
            $pdo->exec("ALTER TABLE heads ADD COLUMN is_deleted TINYINT DEFAULT 0");
            echo '<p class="text-warning">⚠️ heads.is_deleted شامل کر دیا</p>';
        }
    } catch(Throwable $e) {
        echo '<p class="text-danger">❌ heads جدول: ' . $e->getMessage() . '</p>';
    }
    
    // Test acc_chart_of_accounts
    try {
        $coa_cols = $pdo->query("SHOW COLUMNS FROM acc_chart_of_accounts")->fetchAll(PDO::FETCH_COLUMN);
        echo '<p class="text-info">ℹ️ acc_chart_of_accounts کالمز: ' . implode(', ', $coa_cols) . '</p>';
        foreach(['is_deleted','system_type','is_active'] as $c) {
            if(!in_array($c, $coa_cols)) {
                try {
                    if($c === 'is_deleted') $pdo->exec("ALTER TABLE acc_chart_of_accounts ADD COLUMN is_deleted TINYINT DEFAULT 0");
                    elseif($c === 'system_type') $pdo->exec("ALTER TABLE acc_chart_of_accounts ADD COLUMN system_type VARCHAR(50) DEFAULT 'Madrasa'");
                    elseif($c === 'is_active') $pdo->exec("ALTER TABLE acc_chart_of_accounts ADD COLUMN is_active TINYINT(1) DEFAULT 1");
                    echo '<p class="text-success">✅ acc_chart_of_accounts.' . $c . ' شامل کر دیا</p>';
                } catch(Throwable $e) {}
            }
        }
    } catch(Throwable $e) {
        echo '<p class="text-danger">❌ acc_chart_of_accounts: ' . $e->getMessage() . '</p>';
    }
    
} catch(Throwable $e) {
    echo '<p class="text-danger">❌ S3 خطا: ' . $e->getMessage() . '</p>';
}

echo '<hr>';

// ============ S1: Trial Balance Check ============
echo '<h4 class="text-primary">S1 — ٹرائل بیلنس فرانزک</h4>';
try {
    $tb_query = "
        SELECT a.code, a.name, a.type, 
               COALESCE(SUM(e.debit), 0) as total_debit, 
               COALESCE(SUM(e.credit), 0) as total_credit
        FROM acc_chart_of_accounts a
        LEFT JOIN acc_ledger_entries e ON a.id = e.account_id
        LEFT JOIN acc_vouchers v ON e.voucher_id = v.id 
            AND v.status = 'Approved' 
            AND (v.is_deleted = 0 OR v.is_deleted IS NULL)
        WHERE (a.is_deleted = 0 OR a.is_deleted IS NULL)
        GROUP BY a.id, a.code, a.name, a.type
        HAVING total_debit > 0 OR total_credit > 0
        ORDER BY a.type, a.code
    ";
    $tb_rows = $pdo->query($tb_query)->fetchAll(PDO::FETCH_ASSOC);
    
    $grand_dr = 0; $grand_cr = 0;
    $unusual = [];
    
    echo '<div class="table-responsive"><table class="table table-sm table-bordered">';
    echo '<thead class="table-dark"><tr><th>کوڈ</th><th>نام</th><th>قسم</th><th>ڈیبٹ</th><th>کریڈٹ</th><th>نیٹ بیلنس</th><th>حالت</th></tr></thead><tbody>';
    
    foreach($tb_rows as $r) {
        $dr = (float)$r['total_debit'];
        $cr = (float)$r['total_credit'];
        $net = $dr - $cr;
        $type = $r['type'];
        
        $normal_side = in_array($type, ['Asset','Expense']) ? 'Dr' : 'Cr';
        $actual_side = $net >= 0 ? 'Dr' : 'Cr';
        $is_unusual = ($normal_side !== $actual_side && abs($net) > 0.01);
        
        $grand_dr += $dr;
        $grand_cr += $cr;
        
        $row_class = $is_unusual ? 'table-danger' : '';
        $status = $is_unusual ? '⚠️ غیر معمولی بیلنس' : '✅';
        
        if($is_unusual) {
            $unusual[] = ['code' => $r['code'], 'name' => $r['name'], 'type' => $type, 'net' => $net];
        }
        
        echo "<tr class='$row_class'>
            <td>{$r['code']}</td>
            <td>{$r['name']}</td>
            <td>{$type}</td>
            <td>" . number_format($dr) . "</td>
            <td>" . number_format($cr) . "</td>
            <td>" . number_format(abs($net)) . " ($actual_side)</td>
            <td>$status</td>
        </tr>";
    }
    
    $diff = abs($grand_dr - $grand_cr);
    $is_balanced = $diff < 0.01;
    echo '</tbody><tfoot class="table-dark">';
    echo '<tr><th colspan="3">مجموعہ</th><th>' . number_format($grand_dr) . '</th><th>' . number_format($grand_cr) . '</th>';
    echo '<th colspan="2" class="' . ($is_balanced ? 'text-success' : 'text-danger') . '">';
    echo $is_balanced ? '✅ متوازن' : '❌ فرق: Rs ' . number_format($diff);
    echo '</th></tr></tfoot></table></div>';
    
    if(!empty($unusual)) {
        echo '<h5 class="text-danger mt-3">غیر معمولی بیلنس والے اکاؤنٹس:</h5>';
        foreach($unusual as $u) {
            echo '<div class="alert alert-warning">کوڈ ' . $u['code'] . ': ' . $u['name'] . ' (' . $u['type'] . ') — نیٹ بیلنس: ' . number_format($u['net']) . '</div>';
        }
    }
    
} catch(Throwable $e) {
    echo '<p class="text-danger">❌ TB خطا: ' . $e->getMessage() . '</p>';
}

echo '<hr>';

// ============ S7: Chart of Accounts Type Check ============
echo '<h4 class="text-primary">S7 — چارٹ آف اکاؤنٹس تجزیہ</h4>';
try {
    $coa_issues = $pdo->query("
        SELECT code, name, type 
        FROM acc_chart_of_accounts 
        WHERE (is_deleted = 0 OR is_deleted IS NULL)
        AND (
            (type = 'Expense' AND (name LIKE '%نقد%' OR name LIKE '%Cash%' OR name LIKE '%بینک%' OR name LIKE '%Bank%' OR name LIKE '%قرض%' OR name LIKE '%Loan%'))
            OR type IS NULL OR type = ''
        )
        ORDER BY type, code
    ")->fetchAll(PDO::FETCH_ASSOC);
    
    if(empty($coa_issues)) {
        echo '<p class="text-success">✅ چارٹ میں کوئی واضح درجہ بندی کا مسئلہ نہیں</p>';
    } else {
        echo '<p class="text-danger">❌ غلط درجہ بندی کے اکاؤنٹس:</p>';
        echo '<table class="table table-sm table-bordered"><thead class="table-dark"><tr><th>کوڈ</th><th>نام</th><th>موجودہ قسم</th><th>تجویز شدہ قسم</th></tr></thead><tbody>';
        foreach($coa_issues as $i) {
            $suggested = (!$i['type'] || $i['type'] === '') ? 'خالی — لازمی درست کریں' :
                (str_contains(strtolower($i['name']), 'cash') || str_contains($i['name'], 'نقد') || str_contains(strtolower($i['name']), 'bank') || str_contains($i['name'], 'بینک') ? 'Asset' : 
                (str_contains($i['name'], 'قرض') || str_contains(strtolower($i['name']), 'loan') ? 'Liability' : 'Asset'));
            echo "<tr class='table-warning'><td>{$i['code']}</td><td>{$i['name']}</td><td>{$i['type']}</td><td class='fw-bold text-primary'>$suggested</td></tr>";
        }
        echo '</tbody></table>';
    }
} catch(Throwable $e) {
    echo '<p class="text-danger">❌ S7 خطا: ' . $e->getMessage() . '</p>';
}

echo '<hr>';

// ============ S16: Mode Leak Check ============
echo '<h4 class="text-primary">S16 — موڈ علیحدگی چیک</h4>';
try {
    // Check maktab classes count
    $maktab_count = (int)$pdo->query("SELECT COUNT(*) FROM classes WHERE system_type = 'Masjid' AND (is_deleted = 0 OR is_deleted IS NULL)")->fetchColumn();
    $madrasa_count = (int)$pdo->query("SELECT COUNT(*) FROM classes WHERE (system_type = 'Madrasa' OR system_type IS NULL OR system_type = '') AND (is_deleted = 0 OR is_deleted IS NULL)")->fetchColumn();
    echo "<p>مدرسہ کلاسز: $madrasa_count | مکتب/مسجد کلاسز: $maktab_count</p>";
    
    // Check student count by system type
    $std_madrasa = (int)$pdo->query("SELECT COUNT(*) FROM students WHERE (system_type = 'Madrasa' OR system_type IS NULL OR system_type = '') AND status = 'Active' AND (is_deleted = 0 OR is_deleted IS NULL)")->fetchColumn();
    $std_maktab = (int)$pdo->query("SELECT COUNT(*) FROM students WHERE system_type = 'Masjid' AND status = 'Active' AND (is_deleted = 0 OR is_deleted IS NULL)")->fetchColumn();
    echo "<p>مدرسہ طلبہ: $std_madrasa | مکتب طلبہ: $std_maktab</p>";
    
} catch(Throwable $e) {
    echo '<p class="text-danger">❌ S16 خطا: ' . $e->getMessage() . '</p>';
}

echo '<hr>';

// ============ System Info ============
echo '<h4 class="text-primary">سسٹم معلومات</h4>';
echo '<ul>';
echo '<li>PHP ورژن: ' . phpversion() . '</li>';
echo '<li>MySQL ورژن: ' . $pdo->query("SELECT VERSION()")->fetchColumn() . '</li>';
echo '<li>Tenant ID: ' . $cur_tenant_id . '</li>';
echo '<li>display_errors: ' . ini_get('display_errors') . '</li>';
echo '<li>error_log: ' . (ini_get('error_log') ?: 'ڈیفالٹ') . '</li>';
echo '</ul>';

echo '<div class="alert alert-danger mt-4"><strong>⚠️ سیکیورٹی اطلاع:</strong> یہ فائل استعمال کے بعد فوری حذف کریں!</div>';
echo '</body></html>';
?>
