<?php
/**
 * Multi-Tenant SaaS Middleware & Core Helpers
 * 
 * Provides tenant resolution, context resolution, SaaS settings,
 * module permissions catalog, and subscription checks.
 */

if (!function_exists('get_current_tenant_id')) {
    function get_current_tenant_id($explicit = null) {
        if ($explicit !== null && is_numeric($explicit) && (int)$explicit > 0) {
            return (int)$explicit;
        }
        // 1. Web session
        if (isset($_SESSION['tenant_id']) && (int)$_SESSION['tenant_id'] > 0) {
            return (int)$_SESSION['tenant_id'];
        }
        // 2. HTTP headers (API)
        $headers = function_exists('getallheaders') ? (getallheaders() ?: []) : [];
        $norm = array_change_key_case($headers, CASE_LOWER);
        if (!empty($norm['x-tenant-id']) && is_numeric($norm['x-tenant-id'])) {
            return (int)$norm['x-tenant-id'];
        }
        if (!empty($_SERVER['HTTP_X_TENANT_ID']) && is_numeric($_SERVER['HTTP_X_TENANT_ID'])) {
            return (int)$_SERVER['HTTP_X_TENANT_ID'];
        }
        // 3. Request param
        if (!empty($_REQUEST['tenant_id']) && is_numeric($_REQUEST['tenant_id'])) {
            return (int)$_REQUEST['tenant_id'];
        }
        // 4. Default fallback for backwards compatibility
        return 1;
    }
}

if (!function_exists('get_current_tenant_code')) {
    function get_current_tenant_code() {
        if (!empty($_SESSION['tenant_code'])) {
            return strtoupper(trim((string)$_SESSION['tenant_code']));
        }
        $headers = function_exists('getallheaders') ? (getallheaders() ?: []) : [];
        $norm = array_change_key_case($headers, CASE_LOWER);
        if (!empty($norm['x-tenant-code'])) {
            return strtoupper(trim((string)$norm['x-tenant-code']));
        }
        if (!empty($_SERVER['HTTP_X_TENANT_CODE'])) {
            return strtoupper(trim((string)$_SERVER['HTTP_X_TENANT_CODE']));
        }
        if (!empty($_REQUEST['tenant_code'])) {
            return strtoupper(trim((string)$_REQUEST['tenant_code']));
        }
        return 'MAIN01';
    }
}

if (!function_exists('resolve_tenant_by_code')) {
    function resolve_tenant_by_code($pdo, $code) {
        $c = strtoupper(trim((string)$code));
        if (empty($c)) $c = 'MAIN01';
        try {
            $stmt = $pdo->prepare("SELECT * FROM tenants WHERE UPPER(code) = ? OR UPPER(slug) = ? LIMIT 1");
            $stmt->execute([$c, $c]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($row) return $row;

            // Fallback for default tenant / single-madrasa mode
            if ($c === 'MAIN01' || $c === 'DEFAULT') {
                try {
                    $row1 = $pdo->query("SELECT * FROM tenants WHERE id = 1 LIMIT 1")->fetch(PDO::FETCH_ASSOC);
                    if ($row1) return $row1;

                    $first = $pdo->query("SELECT * FROM tenants ORDER BY id ASC LIMIT 1")->fetch(PDO::FETCH_ASSOC);
                    if ($first) return $first;
                } catch (Throwable $te1) {}

                // Auto-create/seed default tenant row if table exists or can be created
                try {
                    $pdo->exec("
                        CREATE TABLE IF NOT EXISTS `tenants` (
                            `id` INT AUTO_INCREMENT PRIMARY KEY,
                            `code` VARCHAR(50) UNIQUE NOT NULL,
                            `name` VARCHAR(255) NOT NULL,
                            `slug` VARCHAR(100) UNIQUE NOT NULL,
                            `system_type` VARCHAR(50) DEFAULT 'Madrasa',
                            `status` VARCHAR(30) NOT NULL DEFAULT 'active',
                            `allowed_modules` TEXT DEFAULT NULL,
                            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                    ");
                    $pdo->exec("
                        INSERT IGNORE INTO `tenants` (`id`, `code`, `name`, `slug`, `system_type`, `status`)
                        VALUES (1, 'MAIN01', 'مدرسہ اشرف المدارس', 'main01', 'Madrasa', 'active')
                    ");
                    $seeded = $pdo->query("SELECT * FROM tenants WHERE id = 1 LIMIT 1")->fetch(PDO::FETCH_ASSOC);
                    if ($seeded) return $seeded;
                } catch (Throwable $te2) {}

                // Virtual fallback if database user lacks DDL privileges
                return [
                    'id' => 1,
                    'code' => 'MAIN01',
                    'name' => 'مدرسہ اشرف المدارس',
                    'slug' => 'main01',
                    'system_type' => 'Madrasa',
                    'status' => 'active'
                ];
            }
            return null;
        } catch (Throwable $e) {
            if ($c === 'MAIN01' || $c === 'DEFAULT' || empty($code)) {
                return [
                    'id' => 1,
                    'code' => 'MAIN01',
                    'name' => 'مدرسہ اشرف المدارس',
                    'slug' => 'main01',
                    'system_type' => 'Madrasa',
                    'status' => 'active'
                ];
            }
            return null;
        }
    }
}

if (!function_exists('get_tenant_id')) {
    function get_tenant_id() {
        return (int)get_current_tenant_id();
    }
}

if (!function_exists('tenant_sql')) {
    function tenant_sql($alias = '') {
        $tid = (int)get_current_tenant_id();
        return $alias ? " {$alias}.tenant_id = {$tid} " : " tenant_id = {$tid} ";
    }
}

if (!function_exists('get_tenant_settings')) {
    function get_tenant_settings(PDO $pdo, $tenant_id = null) {
        if ($tenant_id === null || (int)$tenant_id <= 0) {
            $tenant_id = (int)get_current_tenant_id();
        }
        $tenant_id = (int)$tenant_id;
        try {
            $stmt = $pdo->prepare("SELECT * FROM settings WHERE tenant_id = ? ORDER BY id ASC LIMIT 1");
            $stmt->execute([$tenant_id]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($row) return $row;

            // If not found by tenant_id, auto-provision for this tenant
            $tName = '';
            try {
                $tStmt = $pdo->prepare("SELECT name FROM tenants WHERE id = ? LIMIT 1");
                $tStmt->execute([$tenant_id]);
                $tName = (string)$tStmt->fetchColumn();
            } catch (Throwable $te) {}

            if ($tName === '') {
                // Fallback to id=1 if this is tenant 1
                if ($tenant_id === 1) {
                    $row1 = $pdo->query("SELECT * FROM settings WHERE id = 1 LIMIT 1")->fetch(PDO::FETCH_ASSOC);
                    if ($row1) {
                        try { $pdo->prepare("UPDATE settings SET tenant_id = 1 WHERE id = 1")->execute(); } catch (Throwable $ue) {}
                        return $row1;
                    }
                }
                $tName = 'جامعہ دارالعلوم';
            }

            // Insert new settings row for this tenant
            $ins = $pdo->prepare("INSERT INTO settings (tenant_id, madrasa_name, current_hijri_year, week_start_day) VALUES (?, ?, '1447', 6)");
            $ins->execute([$tenant_id, $tName]);
            $newId = $pdo->lastInsertId();

            $stmt2 = $pdo->prepare("SELECT * FROM settings WHERE id = ? LIMIT 1");
            $stmt2->execute([$newId]);
            $newRow = $stmt2->fetch(PDO::FETCH_ASSOC);
            if ($newRow) return $newRow;
        } catch (Throwable $e) {}

        // Ultimate fallback
        try {
            $fallback = $pdo->query("SELECT * FROM settings LIMIT 1")->fetch(PDO::FETCH_ASSOC);
            if ($fallback) return $fallback;
        } catch (Throwable $e) {}

        return [
            'tenant_id' => $tenant_id,
            'madrasa_name' => 'جامعہ دارالعلوم',
            'phone' => '',
            'address' => '',
            'tagline' => 'العلم نور - تعلیم و تربیت کا گہوارہ',
            'current_hijri_year' => '1447',
            'week_start_day' => 6,
            'logo_path' => 'logo.png',
            'receipt_bg' => 'uploads/receipt_bg.webp',
            'masjid_receipt_bg' => 'uploads/MAMFSS.webp',
            'id_card_bg' => null,
            'sanad_bg' => null,
            'signature_stamp_path' => null,
            'masjid_name' => 'مسجد اشرف المدارس',
            'masjid_logo_path' => null
        ];
    }
}

if (!function_exists('get_saas_setting')) {
    function get_saas_setting($pdo, $key, $default = null) {
        try {
            $stmt = $pdo->prepare("SELECT setting_value FROM saas_settings WHERE setting_key = ? LIMIT 1");
            $stmt->execute([$key]);
            $val = $stmt->fetchColumn();
            return ($val !== false && $val !== null) ? $val : $default;
        } catch (Throwable $e) {
            return $default;
        }
    }
}

if (!function_exists('set_saas_setting')) {
    function set_saas_setting($pdo, $key, $value) {
        try {
            $stmt = $pdo->prepare("INSERT INTO saas_settings (setting_key, setting_value, updated_at) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_at = NOW()");
            return $stmt->execute([$key, (string)$value]);
        } catch (Throwable $e) {
            return false;
        }
    }
}

if (!function_exists('get_all_system_modules')) {
    function get_all_system_modules() {
        return [
            'core_academics' => [
                'title' => 'بنیادی تعلیمی ونگ (Core Academics)',
                'modules' => [
                    'classes' => ['name' => 'کلاسز کا انتظام', 'desc' => 'کلاسز، سیکشنز اور درجات کا انتظام'],
                    'students' => ['name' => 'طلباء مینجمنٹ', 'desc' => 'طلباء کا ریکارڈ، داخلہ، کوائف و سابقہ طلباء (Alumni)'],
                    'teachers' => ['name' => 'اساتذہ و عملہ', 'desc' => 'اساتذہ کا ریکارڈ، کوائف و پروفائلز'],
                    'attendance' => ['name' => 'حاضری رجسٹر و رپورٹس', 'desc' => 'طلبہ و اساتذہ کی روزانہ حاضری، رخصت اور QR حاضری'],
                    'hifz' => ['name' => 'حفظ و ناظرہ و تعلیمی رپورٹس', 'desc' => 'روزانہ سبق، سبقی، منزل اور درسی تعلیمی کارکردگی'],
                    'exams' => ['name' => 'امتحانات و رزلٹ کارڈز', 'desc' => 'امتحانات کا انعقاد، نتائج کا اندراج اور اسناد'],
                    'admissions' => ['name' => 'آن لائن داخلہ پائپ لائن', 'desc' => 'داخلہ فارم، ٹیسٹ اور داخلہ درخواستیں'],
                    'notices' => ['name' => 'نوٹس بورڈ و اعلانات', 'desc' => 'ادارہ جاتی پیغامات، اعلانات اور نوٹیفیکیشنز'],
                    'requests' => ['name' => 'درخواستیں و شکایات', 'desc' => 'والدین و اساتذہ کی شکایات و اصلاحی نوٹسز']
                ]
            ],
            'finance_accounts' => [
                'title' => 'مالیات و اکاؤنٹس (Finance & ERP)',
                'modules' => [
                    'simple_finance' => ['name' => 'سادہ فنانس (آمدن و خرچ)', 'desc' => 'روزمرہ کیش انکم و ایکسپنس، کیش ان ہینڈ اور عطیات'],
                    'assets_donations' => ['name' => 'اثاثہ جات و اشیاء عطیات', 'desc' => 'ادارہ کے فکسڈ اثاثے اور اشیاء کے عطیات'],
                    'payroll' => ['name' => 'مشاہرہ و وظائف عملہ', 'desc' => 'ماہانہ تنخواہوں/وظائف کا حساب کتاب اور ادائیگیاں'],
                    'loans' => ['name' => 'ایڈوانس و قرض مینیجمنٹ', 'desc' => 'عملہ کے قرضے، کٹوتی اور وصولیاں'],
                    'erp_accounts' => ['name' => 'مکمل ڈبل انٹری ERP اکاؤنٹس', 'desc' => 'چارٹ آف اکاؤنٹس، واؤچرز، لیجر، ٹرائل بیلنس، انکم اسٹیٹمنٹ، بیلنس شیٹ اور فیس انوائسز']
                ]
            ],
            'operations_campus' => [
                'title' => 'جدید آپریشنز و کیمپس (Phase 3 & 4)',
                'modules' => [
                    'library' => ['name' => 'لائبریری مینجمنٹ', 'desc' => 'کتب کی کیٹلاگ، اجراء و واپسی'],
                    'inventory' => ['name' => 'سکول شاپ و انونٹری', 'desc' => 'کتب، کاپیاں و اشیاء کی فروخت و اسٹاک'],
                    'hostel' => ['name' => 'ہاسٹل و رہائش مینیجمنٹ', 'desc' => 'کمرے، بیڈز اور رہائشی طلبہ کا انتظام'],
                    'recruitment' => ['name' => 'بھرتی و تقرری (HR)', 'desc' => 'ملازمت کے اشتہارات، امیدوار اور انٹرویوز'],
                    'cms' => ['name' => 'ویب سائٹ و پبلک CMS', 'desc' => 'ادارے کی ویب سائٹ، گیلری اور پبلک پورٹل مواد']
                ]
            ],
            'masjid_wing' => [
                'title' => 'مسجد و مکتب ونگ (Masjid & Maktab)',
                'modules' => [
                    'masjid_wing' => ['name' => 'مسجد و مکتب مکمل نظام', 'desc' => 'مسجد کا الگ موڈ، مکتب قرآنی کلاسز، مسجد فنانس اور اعتکاف']
                ]
            ]
        ];
    }
}

if (!function_exists('get_default_module_keys')) {
    function get_default_module_keys() {
        return [
            'classes', 'students', 'teachers', 'attendance', 'hifz',
            'exams', 'admissions', 'notices', 'requests', 'simple_finance',
            'assets_donations', 'payroll', 'loans', 'erp_accounts',
            'library', 'inventory', 'hostel', 'recruitment', 'cms', 'masjid_wing'
        ];
    }
}

if (!function_exists('get_tenant_allowed_modules')) {
    function get_tenant_allowed_modules($pdo, $tenantId = null) {
        $tid = ($tenantId !== null) ? (int)$tenantId : (int)get_current_tenant_id();
        static $memCache = [];
        if (isset($memCache[$tid])) {
            return $memCache[$tid];
        }

        try {
            $stmt = $pdo->prepare("SELECT allowed_modules FROM tenants WHERE id = ? LIMIT 1");
            $stmt->execute([$tid]);
            $raw = $stmt->fetchColumn();
            if ($raw !== false && $raw !== null && trim((string)$raw) !== '') {
                $decoded = json_decode($raw, true);
                if (is_array($decoded)) {
                    $memCache[$tid] = $decoded;
                    return $decoded;
                }
            }
        } catch (Throwable $e) {
            try {
                $colChk = $pdo->query("SHOW COLUMNS FROM `tenants` LIKE 'allowed_modules'")->fetch();
                if (!$colChk) {
                    $pdo->exec("ALTER TABLE `tenants` ADD COLUMN `allowed_modules` TEXT DEFAULT NULL");
                }
            } catch (Throwable $eCol) {}
        }

        $defaults = get_default_module_keys();
        $memCache[$tid] = $defaults;
        return $defaults;
    }
}

if (!function_exists('is_module_allowed_for_tenant')) {
    function is_module_allowed_for_tenant($pdo, $moduleKey, $tenantId = null) {
        if (!empty($_SESSION['is_super_admin']) || !empty($_SESSION['impersonated_by_super_admin'])) {
            return true;
        }
        $allowed = get_tenant_allowed_modules($pdo, $tenantId);
        return in_array($moduleKey, $allowed, true);
    }
}

if (!function_exists('ensure_tenant_isolation_schema')) {
    function ensure_tenant_isolation_schema($pdo, $force = false) {
        static $executed = false;
        if ($executed && !$force) return;
        $executed = true;

        $cacheFlag = __DIR__ . '/../.tenant_schema_v2_done';
        if (!$force && file_exists($cacheFlag)) return;

        try {
            // 1. SaaS settings table
            $pdo->exec("
                CREATE TABLE IF NOT EXISTS `saas_settings` (
                    `setting_key` VARCHAR(50) PRIMARY KEY,
                    `setting_value` TEXT,
                    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ");
            $chk = $pdo->query("SELECT COUNT(*) FROM saas_settings WHERE setting_key = 'allow_public_registration'")->fetchColumn();
            if ($chk == 0) {
                $pdo->exec("INSERT INTO saas_settings (setting_key, setting_value) VALUES ('allow_public_registration', '1')");
            }

            // 1b. Ensure tenants table exists with default MAIN01
            try {
                $pdo->exec("
                    CREATE TABLE IF NOT EXISTS `tenants` (
                        `id` INT AUTO_INCREMENT PRIMARY KEY,
                        `code` VARCHAR(50) UNIQUE NOT NULL,
                        `name` VARCHAR(255) NOT NULL,
                        `slug` VARCHAR(100) UNIQUE NOT NULL,
                        `system_type` VARCHAR(50) DEFAULT 'Madrasa',
                        `status` VARCHAR(30) NOT NULL DEFAULT 'active',
                        `allowed_modules` TEXT DEFAULT NULL,
                        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                ");
                $hasMain = (int)$pdo->query("SELECT COUNT(*) FROM `tenants` WHERE `code` = 'MAIN01' OR `id` = 1")->fetchColumn();
                if ($hasMain === 0) {
                    $pdo->exec("
                        INSERT INTO `tenants` (`id`, `code`, `name`, `slug`, `system_type`, `status`)
                        VALUES (1, 'MAIN01', 'مدرسہ اشرف المدارس', 'main01', 'Madrasa', 'active')
                    ");
                }
            } catch (Throwable $eTen) {}

            // 2. Fix status truncation for tenants & subscriptions (VARCHAR instead of restrictive ENUM)
            try { $pdo->exec("ALTER TABLE `tenants` MODIFY COLUMN `status` VARCHAR(30) NOT NULL DEFAULT 'trial'"); } catch (Throwable $e) {}
            try { $pdo->exec("ALTER TABLE `subscriptions` MODIFY COLUMN `status` VARCHAR(30) NOT NULL DEFAULT 'trial'"); } catch (Throwable $e) {}
            try {
                $tCols = $pdo->query("SHOW COLUMNS FROM `tenants`")->fetchAll(PDO::FETCH_COLUMN);
                if (!in_array('allowed_modules', $tCols)) {
                    $pdo->exec("ALTER TABLE `tenants` ADD COLUMN `allowed_modules` TEXT DEFAULT NULL");
                }
            } catch (Throwable $e) {}

            // 3. Ensure tenant_id exists and backfill 1 on legacy rows across all tables
            $tables = [
                'admins', 'students', 'teachers', 'classes', 'class_periods', 'attendance', 'period_attendance',
                'attendance_teachers', 'teacher_period_attendance', 'teacher_leaves', 'daily_hifz', 'daily_nazira',
                'qaida_records', 'academic_reports', 'exams', 'exam_results',
                'parent_complaints', 'complaints', 'fee_submissions', 'admission_applications', 'admission_inquiries',
                'notices', 'activity_logs', 'leave_applications', 'heads', 'finance',
                'staff_loans', 'loan_transactions', 'staff_salaries', 'staff_stipends', 'assets',
                'in_kind_donations', 'inventory_items', 'inventory_sales', 'hostel_rooms',
                'hostel_allocations', 'lib_books', 'lib_issues', 'web_pages', 'announcements',
                'job_postings', 'job_applicants', 'settings', 'smart_notification_reads',
                'acc_chart_of_accounts', 'acc_vouchers', 'acc_ledger_entries', 'acc_invoices',
                'acc_payroll', 'acc_departments', 'maktab_classes', 'maktab_teachers'
            ];

            foreach ($tables as $t) {
                try {
                    $cols = $pdo->query("SHOW COLUMNS FROM `$t`")->fetchAll(PDO::FETCH_COLUMN);
                    if (!in_array('tenant_id', $cols)) {
                        $pdo->exec("ALTER TABLE `$t` ADD COLUMN `tenant_id` INT NOT NULL DEFAULT 1");
                    }
                    $pdo->exec("UPDATE `$t` SET `tenant_id` = 1 WHERE `tenant_id` IS NULL OR `tenant_id` = 0");
                } catch (Throwable $eT) {}
            }

            // 4. Ensure specific vital columns exist across core tables
            $essential_cols = [
                'students' => [
                    'system_type' => "VARCHAR(50) DEFAULT 'Madrasa'",
                    'is_deleted' => "TINYINT DEFAULT 0",
                    'residence_status' => "VARCHAR(50) DEFAULT ''",
                    'quran_edition' => "VARCHAR(50) DEFAULT '16 سطری'"
                ],
                'finance' => [
                    'system_type' => "VARCHAR(50) DEFAULT 'Madrasa'",
                    'is_deleted' => "TINYINT DEFAULT 0",
                    'head_name' => "VARCHAR(255) DEFAULT NULL",
                    'account_id' => "INT DEFAULT NULL",
                    'payment_method' => "VARCHAR(50) DEFAULT 'Cash'"
                ],
                'heads' => [
                    'is_deleted' => "TINYINT DEFAULT 0"
                ],
                'admission_applications' => [
                    'serial_no' => "INT DEFAULT NULL"
                ],
                'acc_chart_of_accounts' => [
                    'system_type' => "VARCHAR(50) DEFAULT 'Madrasa'",
                    'is_deleted' => "TINYINT DEFAULT 0",
                    'is_active' => "TINYINT(1) DEFAULT 1"
                ],
                'acc_vouchers' => [
                    'system_type' => "VARCHAR(50) DEFAULT 'Madrasa'",
                    'is_deleted' => "TINYINT(1) DEFAULT 0",
                    'created_by' => "INT DEFAULT NULL"
                ]
            ];

            foreach ($essential_cols as $tbl => $colsMap) {
                try {
                    $existingCols = $pdo->query("SHOW COLUMNS FROM `$tbl`")->fetchAll(PDO::FETCH_COLUMN);
                    foreach ($colsMap as $cName => $cDef) {
                        if (!in_array($cName, $existingCols)) {
                            try { $pdo->exec("ALTER TABLE `$tbl` ADD COLUMN `$cName` $cDef"); } catch (Throwable $e) {}
                        }
                    }
                } catch (Throwable $e) {}
            }

            // 5. Self-healing restore: Restore advance expenses for users who spend from Advance accounts
            $restoreFlag = __DIR__ . '/../.restore_user_advance_expenses_v6_done';
            if (!file_exists($restoreFlag)) {
                try {
                    $advAcctRows = $pdo->query("SELECT id, name FROM acc_chart_of_accounts WHERE type = 'Asset' AND (name LIKE 'ایڈوانس%' OR name LIKE 'Advance%') AND (is_deleted = 0 OR is_deleted IS NULL)")->fetchAll(PDO::FETCH_ASSOC);
                    $admRows = $pdo->query("SELECT id, username, name, role FROM admins")->fetchAll(PDO::FETCH_ASSOC);

                    foreach ($advAcctRows as $aa) {
                        $aid = (int)$aa['id'];
                        $clean_label = trim(preg_replace('/^(ایڈوانس|advance)\s*[-:]?\s*/iu', '', $aa['name']));
                        if (empty($clean_label)) continue;

                        $matchedUser = null;
                        foreach ($admRows as $u) {
                            $un = !empty($u['username']) ? $u['username'] : '';
                            $nm = !empty($u['name']) ? $u['name'] : '';
                            if (mb_strtolower(trim($un)) === mb_strtolower($clean_label) ||
                                mb_strtolower(trim($nm)) === mb_strtolower($clean_label) ||
                                (!empty($un) && mb_stripos($aa['name'], $un) !== false) ||
                                (!empty($nm) && mb_stripos($aa['name'], $nm) !== false) ||
                                (!empty($nm) && mb_stripos($clean_label, $nm) !== false) ||
                                (!empty($un) && mb_stripos($clean_label, $un) !== false)) {
                                $matchedUser = $u;
                                break;
                            }
                        }

                        // Auto-overwrite removed to preserve user/account segregation integrity
                    }
                    @touch($restoreFlag);
                } catch (Throwable $eR) {}
            }

            @touch($cacheFlag);
        } catch (Throwable $e) {}
    }
}

// Lightweight tenant safety check (only runs heavy migration if explicitly requested via ?migrate_tenant_schema=1)

if (!function_exists('check_tenant_subscription')) {
    function check_tenant_subscription($pdo, $tenantId) {
        // اگر سنگل مدرسہ یا ڈیفالٹ ٹیننٹ (id <= 1) ہو تو ہمیشہ ایکٹو رکھیں
        if ((int)$tenantId <= 1) {
            return ['ok' => true, 'tenant' => ['id' => 1, 'code' => 'MAIN01', 'name' => 'مدرسہ اشرف المدارس', 'status' => 'active']];
        }
        try {
            $stmt = $pdo->prepare("SELECT t.*, s.status as sub_status, s.ends_at, s.plan_id 
                                   FROM tenants t 
                                   LEFT JOIN subscriptions s ON t.id = s.tenant_id AND s.status IN ('active', 'trial')
                                   WHERE t.id = ? 
                                   ORDER BY s.id DESC LIMIT 1");
            $stmt->execute([(int)$tenantId]);
            $t = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$t) return ['ok' => true, 'tenant' => null];

            if ($t['status'] === 'suspended') {
                return ['ok' => false, 'message' => 'آپ کے ادارے کا اکاؤنٹ معطل (Suspended) کر دیا گیا ہے۔ انتظامیہ سے رابطہ کریں۔'];
            }
            if ($t['status'] === 'cancelled') {
                return ['ok' => false, 'message' => 'ادارے کی رکنیت منسوخ ہو چکی ہے۔'];
            }

            // چیک میعاد
            if (!empty($t['ends_at'])) {
                if (strtotime($t['ends_at']) < strtotime(date('Y-m-d'))) {
                    return ['ok' => false, 'message' => 'آپ کے ادارے کی سبسکرپشن کی میعاد ختم ہو چکی ہے، براہ کرم تجدید کروائیں۔'];
                }
            } elseif ($t['status'] === 'trial' && !empty($t['trial_ends_at'])) {
                if (strtotime($t['trial_ends_at']) < strtotime(date('Y-m-d'))) {
                    return ['ok' => false, 'message' => 'آپ کا 14 روزہ مفت ٹرائل ختم ہو چکا ہے۔ جاری رکھنے کے لیے پلان منتخب کریں۔'];
                }
            }

            return ['ok' => true, 'tenant' => $t];
        } catch (Throwable $e) {
            return ['ok' => true, 'tenant' => null];
        }
    }
}
