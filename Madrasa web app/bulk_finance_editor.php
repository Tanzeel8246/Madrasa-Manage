<?php
/**
 * Bulk Finance Editor & Speller Tool (بلک فنانس ایڈیٹر و درستگی املا ٹول)
 * 110% Tri-Platform Parity with Multi-Tenant Isolation & Auto Accounting Posting
 */
require_once 'db.php';
require_once 'finance_accounting_bridge.php';

$user_role_lower = strtolower(trim((string)($_SESSION['role'] ?? '')));
$is_admin = in_array($user_role_lower, ['admin', 'superadmin', 'super_admin', 'administrator', 'nazim']);
if (!$is_admin && !has_perm('manage_finance')) {
    die('<div class="alert alert-danger m-4 text-center">رسائی ممنوع ہے: صرف ایڈمنسٹریٹر یا مجاز عملہ ہی بلک ایڈیٹر استعمال کر سکتا ہے۔</div>');
}

$cur_tenant_id = (int)get_current_tenant_id();
$msg = '';
$msg_type = 'success';

// ----------------------------------------------------
// Filter parameters (GET)
// ----------------------------------------------------
$filter_system  = $_GET['system_type'] ?? ($_SESSION['system_type'] ?? 'all');
$filter_type    = $_GET['entry_type'] ?? 'all'; // 'all', 'Income', 'Expense'
$filter_user_id = $_GET['user_id'] ?? 'all';
$filter_head    = trim($_GET['head'] ?? 'all');
$filter_account = $_GET['account_id'] ?? 'all';
$search_term    = trim($_GET['search'] ?? '');
$from_date      = trim($_GET['from_date'] ?? '');
$to_date        = trim($_GET['to_date'] ?? '');
$limit          = min(300, max(10, (int)($_GET['limit'] ?? 100)));

// Fetch Heads for Dropdowns & Auto-complete with 100% resilient fallbacks
$raw_heads = [];
try {
    // 1. Attempt from heads table with tenant_id and is_deleted
    $stH = $pdo->prepare("SELECT id, name, type FROM heads WHERE (is_deleted = 0 OR is_deleted IS NULL) AND (tenant_id = ? OR tenant_id IS NULL OR tenant_id = 0) ORDER BY name ASC");
    $stH->execute([$cur_tenant_id]);
    $raw_heads = $stH->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $e1) {
    try {
        // Fallback without tenant_id parameter
        $stH = $pdo->query("SELECT id, name, type FROM heads WHERE (is_deleted = 0 OR is_deleted IS NULL) ORDER BY name ASC");
        $raw_heads = $stH->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $e2) {
        try {
            $stH = $pdo->query("SELECT id, name, type FROM heads ORDER BY name ASC");
            $raw_heads = $stH->fetchAll(PDO::FETCH_ASSOC);
        } catch (Throwable $e3) {
            try {
                $stH = $pdo->query("SELECT * FROM heads");
                $raw_heads = $stH->fetchAll(PDO::FETCH_ASSOC);
            } catch (Throwable $e4) {
                $raw_heads = [];
            }
        }
    }
}

// 2. Also fetch all existing unique heads from finance transactions
$fin_heads = [];
try {
    $stFin = $pdo->query("SELECT DISTINCT head_name, type FROM finance WHERE head_name IS NOT NULL AND TRIM(head_name) != '' AND (is_deleted = 0 OR is_deleted IS NULL) ORDER BY head_name ASC");
    $fin_heads = $stFin->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $eFin) {
    try {
        $stFin = $pdo->query("SELECT DISTINCT head_name, type FROM finance WHERE head_name IS NOT NULL AND TRIM(head_name) != '' ORDER BY head_name ASC");
        $fin_heads = $stFin->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $eFin2) {
        $fin_heads = [];
    }
}

// 3. Merge & Deduplicate all heads
$all_heads_map = [];

foreach ($raw_heads as $rh) {
    $nm = trim($rh['name'] ?? '');
    if (empty($nm)) continue;
    $tp = (strcasecmp($rh['type'] ?? '', 'Expense') === 0) ? 'Expense' : 'Income';
    $all_heads_map[mb_strtolower($nm)] = [
        'id'   => $rh['id'] ?? null,
        'name' => $nm,
        'type' => $tp
    ];
}

foreach ($fin_heads as $fh) {
    $nm = trim($fh['head_name'] ?? '');
    if (empty($nm)) continue;
    $key = mb_strtolower($nm);
    if (!isset($all_heads_map[$key])) {
        $tp = (strcasecmp($fh['type'] ?? '', 'Income') === 0) ? 'Income' : 'Expense';
        $all_heads_map[$key] = [
            'id'   => null,
            'name' => $nm,
            'type' => $tp
        ];
    }
}

// 4. Guaranteed Institutional Defaults (اگر سسٹم میں کوئی مد نہ بھی ہو تب بھی مکمل لوڈ ہو)
$std_incomes = ['عطیات / چندہ', 'زکوٰۃ', 'صدقات', 'تعاون / امداد', 'فنڈ', 'ماہانہ فیس', 'داخلہ فیس', 'قربانی کھالیں', 'متفرق آمدن'];
$std_expenses = ['بجلی کا بل', 'گیس کا بل', 'پانی کا بل', 'مرمت و دیکھ بھال', 'صفائی و ستھرائی', 'راشن و خوراک', 'تنخواہ عملہ', 'اسٹیشنری و کتب', 'سفر و کرایہ', 'ڈاک و انٹرنیٹ', 'مہمان نوازی', 'متفرق اخراجات'];

foreach ($std_incomes as $si) {
    $key = mb_strtolower($si);
    if (!isset($all_heads_map[$key])) {
        $all_heads_map[$key] = ['id' => null, 'name' => $si, 'type' => 'Income'];
    }
}
foreach ($std_expenses as $se) {
    $key = mb_strtolower($se);
    if (!isset($all_heads_map[$key])) {
        $all_heads_map[$key] = ['id' => null, 'name' => $se, 'type' => 'Expense'];
    }
}

// 5. Build sorted Income and Expense arrays
$income_heads = [];
$expense_heads = [];
$heads_list = [];

foreach ($all_heads_map as $hData) {
    $heads_list[] = $hData;
    if ($hData['type'] === 'Income') {
        $income_heads[] = $hData;
    } else {
        $expense_heads[] = $hData;
    }
}

usort($income_heads, function($a, $b) { return strcmp($a['name'], $b['name']); });
usort($expense_heads, function($a, $b) { return strcmp($a['name'], $b['name']); });

// Fetch Chart of Accounts for Payment Accounts Dropdown
$accounts_list = [];
try {
    $stA = $pdo->prepare("SELECT id, code, name, type, system_type FROM acc_chart_of_accounts WHERE tenant_id = ? AND (is_deleted = 0 OR is_deleted IS NULL) AND (type = 'Asset' OR type = 'Expense') ORDER BY (code = '1001') DESC, code ASC");
    $stA->execute([$cur_tenant_id]);
    $accounts_list = $stA->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $e) {}

// Fetch System Users
$sys_users = [];
try {
    $sys_users = $pdo->query("SELECT id, username, name FROM admins WHERE (tenant_id = $cur_tenant_id OR tenant_id IS NULL OR tenant_id = 0) ORDER BY id ASC")->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $e) {}

// ----------------------------------------------------
// 1. Handle Bulk Grid Save (ایک ہی بٹن سے تمام ترامیم محفوظ کرنا)
// ----------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'bulk_save_entries') {
    $entries_data = $_POST['entries'] ?? [];
    $updated_count = 0;

    if (!empty($entries_data) && is_array($entries_data)) {
        $pdo->beginTransaction();
        try {
            foreach ($entries_data as $id => $row) {
                $id = (int)$id;
                if ($id <= 0) continue;

                $new_date        = trim($row['date'] ?? '');
                $new_type        = trim($row['type'] ?? 'Income');
                $new_amount      = (float)($row['amount'] ?? 0);
                $new_head_name   = trim($row['head_name'] ?? '');
                $new_description = trim($row['description'] ?? '');
                $new_person      = trim($row['person_name'] ?? ''); // donor or spender
                $new_receipt     = trim($row['manual_receipt_no'] ?? '');
                $new_account_id  = !empty($row['account_id']) ? (int)$row['account_id'] : null;

                // Match or resolve head_id
                $matched_head_id = null;
                if (!empty($new_head_name)) {
                    foreach ($heads_list as $h) {
                        if (mb_strtolower(trim($h['name'])) === mb_strtolower($new_head_name) && !empty($h['id'])) {
                            $matched_head_id = (int)$h['id'];
                            break;
                        }
                    }
                    if (!$matched_head_id) {
                        try {
                            $stFind = $pdo->prepare("SELECT id FROM heads WHERE name = ? LIMIT 1");
                            $stFind->execute([$new_head_name]);
                            $foundId = $stFind->fetchColumn();
                            if ($foundId) {
                                $matched_head_id = (int)$foundId;
                            } else {
                                $stInsH = $pdo->prepare("INSERT INTO heads (name, type, is_deleted, tenant_id) VALUES (?, ?, 0, ?)");
                                $stInsH->execute([$new_head_name, $new_type, $cur_tenant_id]);
                                $matched_head_id = (int)$pdo->lastInsertId();
                            }
                        } catch (Throwable $eInsH) {
                            try {
                                $stInsH = $pdo->prepare("INSERT INTO heads (name, type) VALUES (?, ?)");
                                $stInsH->execute([$new_head_name, $new_type]);
                                $matched_head_id = (int)$pdo->lastInsertId();
                            } catch (Throwable $eInsH2) {}
                        }
                    }
                }

                // Payment method resolution
                $payment_method = 'Cash';
                if ($new_account_id) {
                    foreach ($accounts_list as $acc) {
                        if ((int)$acc['id'] === $new_account_id) {
                            $aName = (string)$acc['name'];
                            if (mb_stripos($aName, 'ایڈوانس') !== false || mb_stripos($aName, 'advance') !== false) {
                                $payment_method = 'Advance';
                            } elseif (mb_stripos($aName, 'بینک') !== false || mb_stripos($aName, 'bank') !== false) {
                                $payment_method = 'Bank';
                            }
                            break;
                        }
                    }
                }

                $donor_name   = ($new_type === 'Income') ? $new_person : '';
                $spender_name = ($new_type === 'Expense') ? $new_person : '';

                $stmtUpd = $pdo->prepare("
                    UPDATE finance 
                    SET date = ?, 
                        type = ?, 
                        amount = ?, 
                        head_name = ?, 
                        head_id = ?, 
                        description = ?, 
                        donor_name = ?, 
                        spender_name = ?, 
                        manual_receipt_no = ?, 
                        account_id = ?, 
                        payment_method = ? 
                    WHERE id = ? AND tenant_id = ?
                ");
                $stmtUpd->execute([
                    $new_date,
                    $new_type,
                    $new_amount,
                    $new_head_name,
                    $matched_head_id,
                    $new_description,
                    $donor_name,
                    $spender_name,
                    $new_receipt,
                    $new_account_id,
                    $payment_method,
                    $id,
                    $cur_tenant_id
                ]);

                // Auto post to accounting bridge
                try {
                    finance_accounting_post($pdo, $id);
                } catch (Throwable $eBr) {}

                $updated_count++;
            }
            $pdo->commit();
            $msg = "کامیابی! کل {$updated_count} فنانس انٹریز کی تفصیلات اور املا کامیابی سے محفوظ کر دی گئیں۔";
            $msg_type = 'success';
        } catch (Throwable $e) {
            $pdo->rollBack();
            $msg = "ڈیٹا محفوظ کرنے کے دوران خرابی پیش آگئی: " . htmlspecialchars($e->getMessage());
            $msg_type = 'danger';
        }
    }
}

// ----------------------------------------------------
// 2. Handle Bulk Duplicate / Clone Entries (ڈپلیکیٹ انٹریز مع جزوی تبدیلیاں)
// ----------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'bulk_duplicate_entries') {
    $selected_ids = $_POST['selected_ids'] ?? [];
    $dup_date_mode = $_POST['dup_date_mode'] ?? 'same'; // 'same', 'custom', 'add_month', 'add_days'
    $dup_custom_date = trim($_POST['dup_custom_date'] ?? '');
    $dup_add_days = (int)($_POST['dup_add_days'] ?? 0);
    $dup_amount_mode = $_POST['dup_amount_mode'] ?? 'same'; // 'same', 'fixed', 'multiply', 'add'
    $dup_custom_amount = (float)($_POST['dup_custom_amount'] ?? 0);
    $dup_head_mode = $_POST['dup_head_mode'] ?? 'same'; // 'same', 'replace'
    $dup_target_head = trim($_POST['dup_target_head'] ?? '');
    $dup_desc_prefix = trim($_POST['dup_desc_prefix'] ?? '');
    $dup_desc_suffix = trim($_POST['dup_desc_suffix'] ?? '');
    $dup_account_mode = $_POST['dup_account_mode'] ?? 'same'; // 'same', 'replace'
    $dup_target_account = !empty($_POST['dup_target_account']) ? (int)$_POST['dup_target_account'] : null;

    if (!empty($selected_ids) && is_array($selected_ids)) {
        $pdo->beginTransaction();
        try {
            $created_count = 0;
            $total_created_amount = 0.0;

            // Resolve target head id if replace mode
            $target_head_id = null;
            if ($dup_head_mode === 'replace' && !empty($dup_target_head)) {
                foreach ($heads_list as $h) {
                    if (mb_strtolower(trim($h['name'])) === mb_strtolower($dup_target_head)) {
                        $target_head_id = (int)$h['id'];
                        break;
                    }
                }
            }

            foreach ($selected_ids as $sid) {
                $sid = (int)$sid;
                if ($sid <= 0) continue;

                $stOrig = $pdo->prepare("SELECT * FROM finance WHERE id = ? AND tenant_id = ?");
                $stOrig->execute([$sid, $cur_tenant_id]);
                $orig = $stOrig->fetch(PDO::FETCH_ASSOC);
                if (!$orig) continue;

                // 1. Calculate Date
                $new_date = $orig['date'];
                if ($dup_date_mode === 'custom' && !empty($dup_custom_date)) {
                    $new_date = $dup_custom_date;
                } elseif ($dup_date_mode === 'add_month') {
                    $new_date = date('Y-m-d', strtotime('+1 month', strtotime($orig['date'])));
                } elseif ($dup_date_mode === 'add_days' && $dup_add_days != 0) {
                    $new_date = date('Y-m-d', strtotime("{$dup_add_days} days", strtotime($orig['date'])));
                }

                // 2. Calculate Amount
                $orig_amt = (float)$orig['amount'];
                $new_amt = $orig_amt;
                if ($dup_amount_mode === 'fixed' && $dup_custom_amount > 0) {
                    $new_amt = $dup_custom_amount;
                } elseif ($dup_amount_mode === 'add') {
                    $new_amt = max(0, $orig_amt + $dup_custom_amount);
                } elseif ($dup_amount_mode === 'multiply' && $dup_custom_amount > 0) {
                    $new_amt = $orig_amt * $dup_custom_amount;
                }

                // 3. Calculate Head
                $new_head_name = $orig['head_name'];
                $new_head_id = $orig['head_id'];
                if ($dup_head_mode === 'replace' && !empty($dup_target_head)) {
                    $new_head_name = $dup_target_head;
                    $new_head_id = $target_head_id;
                }

                // 4. Calculate Description
                $new_desc = $orig['description'];
                if (!empty($dup_desc_prefix)) {
                    $new_desc = $dup_desc_prefix . ' ' . $new_desc;
                }
                if (!empty($dup_desc_suffix)) {
                    $new_desc = $new_desc . ' ' . $dup_desc_suffix;
                }

                // 5. Calculate Account & Payment Method
                $new_acc_id = $orig['account_id'];
                $new_pay_method = $orig['payment_method'] ?? 'Cash';
                if ($dup_account_mode === 'replace') {
                    $new_acc_id = $dup_target_account;
                    if ($new_acc_id) {
                        foreach ($accounts_list as $acc) {
                            if ((int)$acc['id'] === $new_acc_id) {
                                $aName = (string)$acc['name'];
                                if (mb_stripos($aName, 'ایڈوانس') !== false || mb_stripos($aName, 'advance') !== false) {
                                    $new_pay_method = 'Advance';
                                } elseif (mb_stripos($aName, 'بینک') !== false || mb_stripos($aName, 'bank') !== false) {
                                    $new_pay_method = 'Bank';
                                } else {
                                    $new_pay_method = 'Cash';
                                }
                                break;
                            }
                        }
                    }
                }

                // 6. Computer Receipt No if Income
                $comp_receipt_no = null;
                $new_type = $orig['type'];
                if ($new_type === 'Income') {
                    try {
                        if (function_exists('next_user_receipt_no')) {
                            $comp_receipt_no = next_user_receipt_no($pdo, (int)$orig['user_id'], $orig['system_type'] ?? 'Madrasa', $cur_tenant_id);
                        }
                    } catch (Throwable $e) {}
                }

                $stIns = $pdo->prepare("
                    INSERT INTO finance (
                        user_id, user_name, type, head_id, head_name, amount, date, 
                        donor_name, donor_address, spender_name, manual_receipt_no, computer_receipt_no, 
                        description, is_deleted, system_type, account_id, payment_method, tenant_id
                    ) VALUES (
                        ?, ?, ?, ?, ?, ?, ?, 
                        ?, ?, ?, ?, ?, 
                        ?, 0, ?, ?, ?, ?
                    )
                ");
                $stIns->execute([
                    $orig['user_id'],
                    $orig['user_name'],
                    $new_type,
                    $new_head_id,
                    $new_head_name,
                    $new_amt,
                    $new_date,
                    $orig['donor_name'],
                    $orig['donor_address'],
                    $orig['spender_name'],
                    $orig['manual_receipt_no'], // manual receipt copied or blank
                    $comp_receipt_no,
                    $new_desc,
                    $orig['system_type'] ?? 'Madrasa',
                    $new_acc_id,
                    $new_pay_method,
                    $cur_tenant_id
                ]);

                $new_id = (int)$pdo->lastInsertId();
                if ($new_id > 0) {
                    try {
                        finance_accounting_post($pdo, $new_id);
                    } catch (Throwable $eB) {}
                    $created_count++;
                    $total_created_amount += $new_amt;
                }
            }

            $pdo->commit();
            $msg = "زبردست! کل {$created_count} انٹریز کامیابی سے ڈپلیکیٹ (نئی شامل) کر دی گئیں (کل رقم: Rs. " . number_format($total_created_amount) . ")۔";
            $msg_type = 'success';
        } catch (Throwable $e) {
            $pdo->rollBack();
            $msg = "ڈپلیکیٹ انٹریز بنانے میں خرابی: " . htmlspecialchars($e->getMessage());
            $msg_type = 'danger';
        }
    } else {
        $msg = "براہ کرم ڈپلیکیٹ کرنے کے لیے فہرست میں سے کم از کم ایک انٹری منتخب کریں۔";
        $msg_type = 'warning';
    }
}

// ----------------------------------------------------
// 2. Build Query & Fetch Finance Records
// ----------------------------------------------------
$where = ["f.tenant_id = :tid", "(f.is_deleted = 0 OR f.is_deleted IS NULL)"];
$params = [':tid' => $cur_tenant_id];

if ($filter_system !== 'all') {
    $where[] = "f.system_type = :sys";
    $params[':sys'] = $filter_system;
}

if ($filter_type !== 'all') {
    $where[] = "f.type = :type";
    $params[':type'] = $filter_type;
}

if ($filter_user_id !== 'all') {
    $where[] = "f.user_id = :uid";
    $params[':uid'] = (int)$filter_user_id;
}

if ($filter_head !== 'all' && !empty($filter_head)) {
    $where[] = "(f.head_name = :hname OR h.name = :hname)";
    $params[':hname'] = $filter_head;
}

if ($filter_account !== 'all' && !empty($filter_account)) {
    $where[] = "f.account_id = :acc_id";
    $params[':acc_id'] = (int)$filter_account;
}

if (!empty($from_date)) {
    $where[] = "f.date >= :from_date";
    $params[':from_date'] = $from_date;
}

if (!empty($to_date)) {
    $where[] = "f.date <= :to_date";
    $params[':to_date'] = $to_date;
}

if (!empty($search_term)) {
    $where[] = "(f.description LIKE :s OR f.donor_name LIKE :s OR f.spender_name LIKE :s OR f.head_name LIKE :s OR f.manual_receipt_no LIKE :s OR CAST(f.id AS CHAR) = :sExact)";
    $params[':s'] = "%{$search_term}%";
    $params[':sExact'] = $search_term;
}

$where_sql = implode(' AND ', $where);
$records_stmt = $pdo->prepare("
    SELECT f.*, h.name as linked_head_name, a.name as account_name, a.code as account_code
    FROM finance f
    LEFT JOIN heads h ON f.head_id = h.id
    LEFT JOIN acc_chart_of_accounts a ON f.account_id = a.id
    WHERE {$where_sql}
    ORDER BY f.date DESC, f.id DESC
    LIMIT {$limit}
");
$records_stmt->execute($params);
$records = $records_stmt->fetchAll(PDO::FETCH_ASSOC);

include 'header.php';
?>

<div class="container-fluid py-4" dir="rtl">
    <!-- Header -->
    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
        <div>
            <h3 class="fw-bold text-dark m-0 d-flex align-items-center gap-2">
                <i class="fas fa-edit text-success"></i>
                بلک فنانس ایڈیٹر و درستگی املا ٹول
            </h3>
            <small class="text-muted">ایک ساتھ متعدد انٹریز کے ہجے، مد، تفصیل اور رقم ایڈٹ کریں اور ایک ہی بٹن سے محفوظ کریں۔</small>
        </div>
        <div class="d-flex gap-2">
            <a href="simple_finance.php" class="btn btn-outline-secondary fw-bold">
                <i class="fas fa-arrow-right me-1"></i> فنانس پر واپس جائیں
            </a>
            <button type="submit" form="bulkEditorForm" class="btn btn-success fw-bold px-4 shadow-sm">
                <i class="fas fa-save me-1"></i> تمام ترامیم محفوظ کریں (Save All)
            </button>
        </div>
    </div>

    <?php if (!empty($msg)): ?>
        <div class="alert alert-<?php echo $msg_type; ?> alert-dismissible fade show shadow-sm fw-bold" role="alert">
            <i class="fas <?php echo $msg_type === 'success' ? 'fa-check-circle' : 'fa-exclamation-circle'; ?> me-2"></i>
            <?php echo $msg; ?>
            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
        </div>
    <?php endif; ?>

    <!-- Filter Card -->
    <div class="card border-0 shadow-sm mb-4" style="border-radius: 12px; background: #ffffff;">
        <div class="card-body p-3">
            <form method="GET" class="row g-2 align-items-end">
                <div class="col-md-2 col-sm-6">
                    <label class="form-label small fw-bold text-muted mb-1">سسٹم کی قسم</label>
                    <select name="system_type" class="form-select form-select-sm">
                        <option value="all" <?php echo $filter_system === 'all' ? 'selected' : ''; ?>>تمام (مدرسہ و مسجد)</option>
                        <option value="Madrasa" <?php echo $filter_system === 'Madrasa' ? 'selected' : ''; ?>>مدرسہ (Madrasa)</option>
                        <option value="Masjid" <?php echo $filter_system === 'Masjid' ? 'selected' : ''; ?>>مسجد (Masjid)</option>
                    </select>
                </div>
                <div class="col-md-2 col-sm-6">
                    <label class="form-label small fw-bold text-muted mb-1">نوعیت (آمدن/خرچ)</label>
                    <select name="entry_type" class="form-select form-select-sm">
                        <option value="all" <?php echo $filter_type === 'all' ? 'selected' : ''; ?>>تمام انٹریز</option>
                        <option value="Income" <?php echo $filter_type === 'Income' ? 'selected' : ''; ?>>آمدن (Income)</option>
                        <option value="Expense" <?php echo $filter_type === 'Expense' ? 'selected' : ''; ?>>خرچ (Expense)</option>
                    </select>
                </div>
                <div class="col-md-2 col-sm-6">
                    <label class="form-label small fw-bold text-muted mb-1">تاریخ سے</label>
                    <input type="date" name="from_date" class="form-control form-control-sm" value="<?php echo htmlspecialchars($from_date); ?>">
                </div>
                <div class="col-md-2 col-sm-6">
                    <label class="form-label small fw-bold text-muted mb-1">تاریخ تک</label>
                    <input type="date" name="to_date" class="form-control form-control-sm" value="<?php echo htmlspecialchars($to_date); ?>">
                </div>
                <div class="col-md-3 col-sm-8">
                    <label class="form-label small fw-bold text-muted mb-1">تلاش (لفظ یا تفصیل)</label>
                    <input type="text" name="search" class="form-control form-control-sm" placeholder="مثلاً: راشن، مرمت، نام، رسید نمبر..." value="<?php echo htmlspecialchars($search_term); ?>">
                </div>
                <div class="col-md-1 col-sm-4 d-grid">
                    <button type="submit" class="btn btn-primary btn-sm fw-bold">
                        <i class="fas fa-filter me-1"></i> فلٹر
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- Quick Find & Replace Toolbar -->
    <div class="card border-0 shadow-sm mb-4" style="border-radius: 12px; background: #fdfbf7; border-right: 4px solid #198754 !important;">
        <div class="card-body p-3">
            <div class="row g-2 align-items-center">
                <div class="col-md-3 col-sm-12">
                    <div class="fw-bold text-success d-flex align-items-center gap-1">
                        <i class="fas fa-search me-1"></i>
                        <span>تلاش اور خودکار تبدیلی (Find & Replace):</span>
                    </div>
                    <small class="text-muted" style="font-size: 0.75rem;">صفحے پر موجود تمام انٹریز میں ایک ہی بار غلط لفظ کو درست کریں۔</small>
                </div>
                <div class="col-md-3 col-sm-6">
                    <input type="text" id="find_text" class="form-control form-control-sm" placeholder="غلط لفظ (مثلاً: بجلی بل)">
                </div>
                <div class="col-md-3 col-sm-6">
                    <input type="text" id="replace_text" class="form-control form-control-sm" placeholder="صحیح متبادل لفظ (مثلاً: بجلی کا بل)">
                </div>
                <div class="col-md-3 col-sm-12 d-flex gap-2">
                    <button type="button" class="btn btn-outline-success btn-sm fw-bold w-100" onclick="applyFindAndReplace('description')">
                        <i class="fas fa-sync-alt me-1"></i> تفصیل میں بدلیں
                    </button>
                    <button type="button" class="btn btn-outline-primary btn-sm fw-bold w-100" onclick="applyFindAndReplace('all')">
                        <i class="fas fa-check-double me-1"></i> ہر جگہ بدلیں
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- Data Form Grid -->
    <div class="card border-0 shadow-sm" style="border-radius: 14px; overflow: hidden;">
        <div class="card-header bg-white py-3 d-flex justify-content-between align-items-center flex-wrap gap-2">
            <div class="fw-bold text-dark d-flex align-items-center gap-2">
                <i class="fas fa-table text-primary"></i>
                <span>فنانس انٹریز گرڈ (نتائج: <span class="badge bg-success"><?php echo count($records); ?></span>)</span>
                <span class="badge bg-primary text-white" id="selectedCountBadge" style="display:none;">0 منتخب</span>
            </div>
            <div class="d-flex align-items-center flex-wrap gap-2">
                <!-- Bulk Head Assignment Toolbar for Selected Rows -->
                <div class="d-flex align-items-center bg-light p-1 px-2 border rounded shadow-sm gap-2">
                    <i class="fas fa-tags text-primary"></i>
                    <label class="small fw-bold text-dark m-0 d-none d-md-inline">منتخب کی مد:</label>
                    <select id="bulkTargetHeadSelect" class="form-select form-select-sm" style="min-width: 170px; max-width: 220px;">
                        <option value="">-- مد منتخب کریں --</option>
                        <?php if (!empty($income_heads)): ?>
                            <optgroup label="آمدن کی مدات">
                                <?php foreach ($income_heads as $h): ?>
                                    <option value="<?php echo htmlspecialchars($h['name']); ?>"><?php echo htmlspecialchars($h['name']); ?></option>
                                <?php endforeach; ?>
                            </optgroup>
                        <?php endif; ?>
                        <?php if (!empty($expense_heads)): ?>
                            <optgroup label="خرچ کی مدات">
                                <?php foreach ($expense_heads as $h): ?>
                                    <option value="<?php echo htmlspecialchars($h['name']); ?>"><?php echo htmlspecialchars($h['name']); ?></option>
                                <?php endforeach; ?>
                            </optgroup>
                        <?php endif; ?>
                    </select>
                    <button type="button" class="btn btn-primary btn-sm fw-bold text-nowrap" onclick="applyBulkHeadToSelected()">
                        <i class="fas fa-check me-1"></i> لاگو کریں
                    </button>
                </div>

                <button type="button" class="btn btn-warning btn-sm fw-bold px-3 shadow-sm text-dark" onclick="openDuplicateModal()">
                    <i class="fas fa-clone me-1 text-dark"></i> منتخب انٹریز ڈپلیکیٹ کریں (Clone Selected)
                </button>
                <button type="submit" form="bulkEditorForm" class="btn btn-success btn-sm fw-bold px-3 shadow-sm">
                    <i class="fas fa-save me-1"></i> تمام ترامیم محفوظ کریں (Save All)
                </button>
            </div>
        </div>
        <div class="card-body p-0">
            <form method="POST" id="bulkEditorForm">
                <input type="hidden" name="action" value="bulk_save_entries">
                
                <div class="table-responsive" style="max-height: 700px; overflow-y: auto;">
                    <table class="table table-hover table-bordered table-sm align-middle m-0" style="font-size: 0.88rem;">
                        <thead class="table-light sticky-top shadow-sm text-center" style="z-index: 10;">
                            <tr>
                                <th style="width: 40px;">
                                    <input type="checkbox" id="selectAllCheckbox" class="form-check-input" onchange="toggleSelectAll(this)" title="سب منتخب کریں">
                                </th>
                                <th style="width: 50px;">ID</th>
                                <th style="width: 125px;">تاریخ</th>
                                <th style="width: 95px;">نوعیت</th>
                                <th style="width: 110px;">رقم (Rs)</th>
                                <th style="width: 190px;">مد (Head)</th>
                                <th>تفصیل (Description)</th>
                                <th style="width: 160px;">دینے / لینے والا</th>
                                <th style="width: 160px;">ادائیگی کھاتہ (Account)</th>
                                <th style="width: 90px;">رسید نمبر</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($records)): ?>
                                <tr>
                                    <td colspan="10" class="text-center py-5 text-muted">
                                        <i class="fas fa-folder-open fa-3x mb-3 text-secondary opacity-50"></i>
                                        <p class="m-0 fw-bold">کوئی فنانس انٹری موصول نہیں ہوئی۔ اوپر دیے گئے فلٹرز تبدیل کر کے تلاش کریں۔</p>
                                    </td>
                                </tr>
                            <?php else: ?>
                                <?php foreach ($records as $r): 
                                    $eid = (int)$r['id'];
                                    $is_inc = ($r['type'] === 'Income');
                                    $p_name = $is_inc ? ($r['donor_name'] ?? '') : ($r['spender_name'] ?? '');
                                    $effective_head = !empty($r['head_name']) ? $r['head_name'] : ($r['linked_head_name'] ?? '');
                                ?>
                                <tr id="row_<?php echo $eid; ?>">
                                    <td class="text-center bg-light">
                                        <input type="checkbox" class="form-check-input row-select-cb" value="<?php echo $eid; ?>" onchange="updateSelectedCount()">
                                    </td>
                                    <td class="text-center fw-bold text-muted small bg-light">
                                        #<?php echo $eid; ?>
                                    </td>
                                    <td>
                                        <input type="date" name="entries[<?php echo $eid; ?>][date]" class="form-control form-control-sm text-center" value="<?php echo htmlspecialchars($r['date']); ?>" required>
                                    </td>
                                    <td>
                                        <select name="entries[<?php echo $eid; ?>][type]" class="form-select form-select-sm fw-bold <?php echo $is_inc ? 'text-success' : 'text-danger'; ?>" onchange="this.className = 'form-select form-select-sm fw-bold ' + (this.value==='Income'?'text-success':'text-danger')">
                                            <option value="Income" <?php echo $is_inc ? 'selected' : ''; ?>>آمدن</option>
                                            <option value="Expense" <?php echo !$is_inc ? 'selected' : ''; ?>>خرچ</option>
                                        </select>
                                    </td>
                                    <td>
                                        <input type="number" step="any" name="entries[<?php echo $eid; ?>][amount]" class="form-control form-control-sm text-end fw-bold" value="<?php echo (float)$r['amount']; ?>" required>
                                    </td>
                                    <td>
                                        <select name="entries[<?php echo $eid; ?>][head_name]" class="form-select form-select-sm editable-head" onchange="this.style.backgroundColor='#d1e7dd'; this.style.fontWeight='bold';">
                                            <option value="">-- مد منتخب کریں --</option>
                                            <?php 
                                            $head_matched = false;
                                            if (!empty($income_heads)): ?>
                                                <optgroup label="آمدن کی مدات">
                                                    <?php foreach ($income_heads as $h): 
                                                        $isSelected = (mb_strtolower(trim($h['name'])) === mb_strtolower(trim($effective_head)));
                                                        if ($isSelected) $head_matched = true;
                                                    ?>
                                                        <option value="<?php echo htmlspecialchars($h['name']); ?>" <?php echo $isSelected ? 'selected' : ''; ?>>
                                                            <?php echo htmlspecialchars($h['name']); ?>
                                                        </option>
                                                    <?php endforeach; ?>
                                                </optgroup>
                                            <?php endif; ?>
                                            <?php if (!empty($expense_heads)): ?>
                                                <optgroup label="خرچ کی مدات">
                                                    <?php foreach ($expense_heads as $h): 
                                                        $isSelected = (mb_strtolower(trim($h['name'])) === mb_strtolower(trim($effective_head)));
                                                        if ($isSelected) $head_matched = true;
                                                    ?>
                                                        <option value="<?php echo htmlspecialchars($h['name']); ?>" <?php echo $isSelected ? 'selected' : ''; ?>>
                                                            <?php echo htmlspecialchars($h['name']); ?>
                                                        </option>
                                                    <?php endforeach; ?>
                                                </optgroup>
                                            <?php endif; ?>
                                            <?php if (!empty($effective_head) && !$head_matched): ?>
                                                <option value="<?php echo htmlspecialchars($effective_head); ?>" selected>
                                                    <?php echo htmlspecialchars($effective_head); ?> (حالیہ)
                                                </option>
                                            <?php endif; ?>
                                        </select>
                                    </td>
                                    <td>
                                        <input type="text" name="entries[<?php echo $eid; ?>][description]" class="form-control form-control-sm editable-desc" value="<?php echo htmlspecialchars($r['description']); ?>" placeholder="تفصیل...">
                                    </td>
                                    <td>
                                        <input type="text" name="entries[<?php echo $eid; ?>][person_name]" class="form-control form-control-sm editable-person" value="<?php echo htmlspecialchars($p_name); ?>" placeholder="<?php echo $is_inc ? 'عطیہ دہندہ' : 'خرچ کنندہ'; ?>">
                                    </td>
                                    <td>
                                        <select name="entries[<?php echo $eid; ?>][account_id]" class="form-select form-select-sm">
                                            <option value="">-- غیر متعین --</option>
                                            <?php foreach ($accounts_list as $acc): ?>
                                                <option value="<?php echo $acc['id']; ?>" <?php echo ((int)$r['account_id'] === (int)$acc['id']) ? 'selected' : ''; ?>>
                                                    <?php echo htmlspecialchars($acc['name'] . ' (' . $acc['code'] . ')'); ?>
                                                </option>
                                            <?php endforeach; ?>
                                        </select>
                                    </td>
                                    <td>
                                        <input type="text" name="entries[<?php echo $eid; ?>][manual_receipt_no]" class="form-control form-control-sm text-center" value="<?php echo htmlspecialchars($r['manual_receipt_no'] ?? ''); ?>" placeholder="رسید">
                                    </td>
                                </tr>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>

                <!-- Footer Save Action -->
                <?php if (!empty($records)): ?>
                <div class="card-footer bg-light py-3 d-flex justify-content-between align-items-center flex-wrap gap-2">
                    <span class="text-muted small">
                        کل <?php echo count($records); ?> انٹریز اس گرڈ میں موجود ہیں۔ آپ جتنی چاہیں انٹریز کو منتخب کر کے ڈپلیکیٹ کر سکتے ہیں یا ترامیم محفوظ کر سکتے ہیں۔
                    </span>
                    <div class="d-flex gap-2">
                        <button type="button" class="btn btn-warning fw-bold px-3 shadow-sm text-dark" onclick="openDuplicateModal()">
                            <i class="fas fa-clone me-1 text-dark"></i> منتخب انٹریز ڈپلیکیٹ کریں
                        </button>
                        <button type="submit" class="btn btn-success fw-bold px-4 shadow-sm">
                            <i class="fas fa-save me-1"></i> تمام ترامیم محفوظ کریں (Save All)
                        </button>
                    </div>
                </div>
                <?php endif; ?>
            </form>
        </div>
    </div>
</div>

<!-- Modal: جزوی تبدیلیوں کے ساتھ ڈپلیکیٹ انٹریز وزرڈ -->
<div class="modal fade" id="duplicateModal" tabindex="-1" aria-labelledby="duplicateModalLabel" aria-hidden="true" dir="rtl">
    <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content border-0 shadow">
            <div class="modal-header bg-warning-subtle text-dark border-bottom border-warning">
                <h5 class="modal-title fw-bold" id="duplicateModalLabel">
                    <i class="fas fa-clone text-warning me-2"></i>
                    منتخب انٹریز کی جزوی تبدیلیوں کے ساتھ نقل (Duplicate Wizard)
                </h5>
                <button type="button" class="btn-close ms-0 me-auto" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <form method="POST" id="duplicateForm">
                <input type="hidden" name="action" value="bulk_duplicate_entries">
                <div id="hiddenSelectedIdsContainer"></div>

                <div class="modal-body p-4 bg-light">
                    <div class="alert alert-info py-2 small mb-3">
                        <i class="fas fa-info-circle me-1"></i>
                        آپ <strong id="modalSelectedCount">0</strong> منتخب انٹریز کی نئی نقل (Clones) تیار کر رہے ہیں۔ ذیل میں جو تبدیلیاں لاگو کرنا چاہتے ہیں ان کا انتخاب کریں۔ جو چیز تبدیل نہیں کرنی اسے "اصل کے مطابق رکھیں" پر رہنے دیں۔
                    </div>

                    <div class="row g-3">
                        <!-- 1. تاریخ میں جزوی تبدیلی -->
                        <div class="col-md-6">
                            <div class="card p-3 h-100 border-0 shadow-sm bg-white">
                                <label class="form-label fw-bold text-primary mb-2">
                                    <i class="fas fa-calendar-alt me-1"></i> 1. نئی تاریخ کا تعین
                                </label>
                                <select name="dup_date_mode" id="dup_date_mode" class="form-select form-select-sm mb-2" onchange="toggleDateInputs(this.value)">
                                    <option value="same">اصل تاریخ برقرار رکھیں (Same Date)</option>
                                    <option value="custom">مخصوص نئی تاریخ سیٹ کریں (Specific Date)</option>
                                    <option value="add_month">اگلے مہینے میں منتقل کریں (+1 Month)</option>
                                    <option value="add_days">دنوں کا اضافہ / کمی (+ / - Days)</option>
                                </select>
                                <div id="dupCustomDateWrap" style="display:none;" class="mb-2">
                                    <input type="date" name="dup_custom_date" class="form-control form-control-sm" value="<?php echo date('Y-m-d'); ?>">
                                </div>
                                <div id="dupAddDaysWrap" style="display:none;" class="mb-2">
                                    <input type="number" name="dup_add_days" class="form-control form-control-sm" placeholder="دنوں کی تعداد (مثلاً 7 یا -3)" value="0">
                                </div>
                            </div>
                        </div>

                        <!-- 2. رقم (Amount) میں جزوی تبدیلی -->
                        <div class="col-md-6">
                            <div class="card p-3 h-100 border-0 shadow-sm bg-white">
                                <label class="form-label fw-bold text-success mb-2">
                                    <i class="fas fa-coins me-1"></i> 2. رقم میں تبدیلی (Amount Adjustment)
                                </label>
                                <select name="dup_amount_mode" id="dup_amount_mode" class="form-select form-select-sm mb-2" onchange="toggleAmountInputs(this.value)">
                                    <option value="same">اصل رقم برقرار رکھیں (Same Amount)</option>
                                    <option value="fixed">نئی فکسڈ رقم مقرر کریں (Fixed Amount)</option>
                                    <option value="add">رقم میں اضافہ / کمی (+ / - Amount)</option>
                                    <option value="multiply">تناسب سے ضرب دیں (Multiply Ratio)</option>
                                </select>
                                <div id="dupAmountValWrap" style="display:none;" class="mb-2">
                                    <input type="number" step="any" name="dup_custom_amount" id="dup_custom_amount" class="form-control form-control-sm" placeholder="رقم یا فیکٹر درج کریں" value="0">
                                </div>
                            </div>
                        </div>

                        <!-- 3. مد (Head) میں جزوی تبدیلی -->
                        <div class="col-md-6">
                            <div class="card p-3 h-100 border-0 shadow-sm bg-white">
                                <label class="form-label fw-bold text-warning-emphasis mb-2">
                                    <i class="fas fa-tags me-1"></i> 3. مد (Head) کی تبدیلی
                                </label>
                                <select name="dup_head_mode" id="dup_head_mode" class="form-select form-select-sm mb-2" onchange="toggleHeadInputs(this.value)">
                                    <option value="same">اصل مد برقرار رکھیں (Same Head)</option>
                                    <option value="replace">نئی مد میں منتقل کریں (Replace Head)</option>
                                </select>
                                <div id="dupTargetHeadWrap" style="display:none;" class="mb-2">
                                    <select name="dup_target_head" class="form-select form-select-sm">
                                        <option value="">-- نئی مد منتخب کریں --</option>
                                        <?php if (!empty($income_heads)): ?>
                                            <optgroup label="آمدن کی مدات">
                                                <?php foreach ($income_heads as $h): ?>
                                                    <option value="<?php echo htmlspecialchars($h['name']); ?>"><?php echo htmlspecialchars($h['name']); ?></option>
                                                <?php endforeach; ?>
                                            </optgroup>
                                        <?php endif; ?>
                                        <?php if (!empty($expense_heads)): ?>
                                            <optgroup label="خرچ کی مدات">
                                                <?php foreach ($expense_heads as $h): ?>
                                                    <option value="<?php echo htmlspecialchars($h['name']); ?>"><?php echo htmlspecialchars($h['name']); ?></option>
                                                <?php endforeach; ?>
                                            </optgroup>
                                        <?php endif; ?>
                                    </select>
                                </div>
                            </div>
                        </div>

                        <!-- 4. کھاتہ (Account) میں تبدیلی -->
                        <div class="col-md-6">
                            <div class="card p-3 h-100 border-0 shadow-sm bg-white">
                                <label class="form-label fw-bold text-info mb-2">
                                    <i class="fas fa-wallet me-1"></i> 4. ادائیگی کھاتہ (Account)
                                </label>
                                <select name="dup_account_mode" id="dup_account_mode" class="form-select form-select-sm mb-2" onchange="toggleAccountInputs(this.value)">
                                    <option value="same">اصل کھاتہ برقرار رکھیں (Same Account)</option>
                                    <option value="replace">نیا کھاتہ منتخب کریں (Replace Account)</option>
                                </select>
                                <div id="dupTargetAccountWrap" style="display:none;" class="mb-2">
                                    <select name="dup_target_account" class="form-select form-select-sm">
                                        <option value="">-- منتخب کریں --</option>
                                        <?php foreach ($accounts_list as $acc): ?>
                                            <option value="<?php echo $acc['id']; ?>">
                                                <?php echo htmlspecialchars($acc['name'] . ' (' . $acc['code'] . ')'); ?>
                                            </option>
                                        <?php endforeach; ?>
                                    </select>
                                </div>
                            </div>
                        </div>

                        <!-- 5. تفصیل (Description) میں اضافی سابقہ / لاحقہ -->
                        <div class="col-12">
                            <div class="card p-3 border-0 shadow-sm bg-white">
                                <label class="form-label fw-bold text-secondary mb-2">
                                    <i class="fas fa-pen-fancy me-1"></i> 5. تفصیل میں اضافی نوٹ (Description Note)
                                </label>
                                <div class="row g-2">
                                    <div class="col-md-6">
                                        <input type="text" name="dup_desc_prefix" class="form-control form-control-sm" placeholder="شروع میں جوڑیں (Prefix) مثلاً: [نقل] یا [قسط]">
                                    </div>
                                    <div class="col-md-6">
                                        <input type="text" name="dup_desc_suffix" class="form-control form-control-sm" placeholder="آخر میں جوڑیں (Suffix) مثلاً: - ماہ اکتوبر 2026">
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="modal-footer bg-white py-2">
                    <button type="button" class="btn btn-secondary btn-sm fw-bold px-3" data-bs-dismiss="modal">منسوخ</button>
                    <button type="submit" class="btn btn-warning btn-sm fw-bold px-4 text-dark shadow-sm">
                        <i class="fas fa-check-circle me-1"></i> ہاں، ابھی ڈپلیکیٹ انٹریز بنائیں
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Datalist for heads auto-complete -->
<datalist id="headsDataList">
    <?php foreach ($heads_list as $h): ?>
        <option value="<?php echo htmlspecialchars($h['name']); ?>">
    <?php endforeach; ?>
</datalist>

<script>
// Checkbox Management
function toggleSelectAll(masterCb) {
    const cbs = document.querySelectorAll('.row-select-cb');
    cbs.forEach(cb => cb.checked = masterCb.checked);
    updateSelectedCount();
}

function updateSelectedCount() {
    const selected = document.querySelectorAll('.row-select-cb:checked');
    const badge = document.getElementById('selectedCountBadge');
    if (badge) {
        if (selected.length > 0) {
            badge.style.display = 'inline-block';
            badge.textContent = selected.length + ' منتخب';
        } else {
            badge.style.display = 'none';
        }
    }
}

function openDuplicateModal() {
    const selected = document.querySelectorAll('.row-select-cb:checked');
    if (selected.length === 0) {
        alert('براہ کرم ڈپلیکیٹ کرنے کے لیے گرڈ میں سے کم از کم ایک انٹری کے چیک باکس کو منتخب کریں۔');
        return;
    }

    const container = document.getElementById('hiddenSelectedIdsContainer');
    container.innerHTML = '';
    selected.forEach(cb => {
        const inp = document.createElement('input');
        inp.type = 'hidden';
        inp.name = 'selected_ids[]';
        inp.value = cb.value;
        container.appendChild(inp);
    });

    document.getElementById('modalSelectedCount').textContent = selected.length;

    const modal = new bootstrap.Modal(document.getElementById('duplicateModal'));
    modal.show();
}

function toggleDateInputs(mode) {
    document.getElementById('dupCustomDateWrap').style.display = (mode === 'custom') ? 'block' : 'none';
    document.getElementById('dupAddDaysWrap').style.display = (mode === 'add_days') ? 'block' : 'none';
}

function toggleAmountInputs(mode) {
    const wrap = document.getElementById('dupAmountValWrap');
    wrap.style.display = (mode === 'same') ? 'none' : 'block';
}

function toggleHeadInputs(mode) {
    document.getElementById('dupTargetHeadWrap').style.display = (mode === 'replace') ? 'block' : 'none';
}

function toggleAccountInputs(mode) {
    document.getElementById('dupTargetAccountWrap').style.display = (mode === 'replace') ? 'block' : 'none';
}

// Bulk Apply Head to all Selected Rows
function applyBulkHeadToSelected() {
    const headSelect = document.getElementById('bulkTargetHeadSelect');
    const targetHead = headSelect ? headSelect.value.trim() : '';

    if (!targetHead) {
        alert('براہ کرم منتخب انٹریز پر لاگو کرنے کے لیے ڈراپ ڈاؤن سے کوئی مد منتخب کریں۔');
        return;
    }

    const selectedCbs = document.querySelectorAll('.row-select-cb:checked');
    if (selectedCbs.length === 0) {
        alert('براہ کرم گرڈ سے کم از کم ایک انٹری کا چیک باکس منتخب کریں جن پر یہ مد لاگو کرنی ہے۔');
        return;
    }

    let modifiedCount = 0;
    selectedCbs.forEach(function(cb) {
        const row = document.getElementById('row_' + cb.value);
        if (row) {
            const selectElem = row.querySelector('.editable-head');
            if (selectElem) {
                // Ensure targetHead exists as an option in row's select
                let exists = false;
                for (let i = 0; i < selectElem.options.length; i++) {
                    if (selectElem.options[i].value === targetHead) {
                        exists = true;
                        break;
                    }
                }
                if (!exists) {
                    const newOpt = new Option(targetHead, targetHead, true, true);
                    selectElem.add(newOpt);
                }
                selectElem.value = targetHead;
                selectElem.style.backgroundColor = '#d1e7dd';
                selectElem.style.borderColor = '#198754';
                selectElem.style.fontWeight = 'bold';
                modifiedCount++;
            }
        }
    });

    if (modifiedCount > 0) {
        alert('کامیابی! کل ' + modifiedCount + ' منتخب انٹریز کی مد تبدیل کر کے "' + targetHead + '" پر سیٹ کر دی گئی۔\nاب تبدیلیوں کو حتمی محفوظ کرنے کے لیے اوپر "تمام ترامیم محفوظ کریں (Save All)" کا بٹن دبائیں۔');
    }
}

// Find and Replace Logic in DOM
function applyFindAndReplace(targetField) {
    const findVal = document.getElementById('find_text').value.trim();
    const replaceVal = document.getElementById('replace_text').value;

    if (!findVal) {
        alert('براہ کرم تلاش کرنے کے لیے لفظ درج کریں۔');
        return;
    }

    let modifiedCount = 0;

    let selector = '';
    if (targetField === 'description') {
        selector = '.editable-desc';
    } else {
        selector = '.editable-desc, .editable-person';
    }

    const inputs = document.querySelectorAll(selector);
    inputs.forEach(function(input) {
        const originalText = input.value;
        if (originalText && originalText.includes(findVal)) {
            const updatedText = originalText.split(findVal).join(replaceVal);
            input.value = updatedText;
            input.style.backgroundColor = '#d1e7dd';
            modifiedCount++;
        }
    });

    if (modifiedCount > 0) {
        alert('کامیابی! کل ' + modifiedCount + ' فیلڈز میں لفظ تبدیل کر دیا گیا۔ اب "تمام ترامیم محفوظ کریں" کا بٹن دبائیں۔');
    } else {
        alert('کوئی مماثل لفظ نہیں ملا۔');
    }
}
</script>

<?php include 'footer.php'; ?>
