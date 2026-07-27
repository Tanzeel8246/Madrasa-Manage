<?php
require_once 'db.php';
// Auth checks are handled in header.php

$selected_class = $_GET['class'] ?? '';
$start_date = $_GET['start_date'] ?? date('Y-m-d');
$end_date = $_GET['end_date'] ?? date('Y-m-d');
$filter_date = $_GET['filter_date'] ?? ''; // If empty, means weekly period
$lesson_type = $_GET['lesson_type'] ?? ''; // sabaq, sabqi, manzil
$miss_count = $_GET['miss_count'] ?? ''; // 0, 1, 2, 3, 'more', or 'any'

if (empty($selected_class) || empty($lesson_type) || $miss_count === '') {
    echo "Invalid parameters.";
    exit;
}

include 'header.php';

// Utility functions
function translateDateUrduFull($dateStr) {
    if(!$dateStr) return '-';
    $timestamp = strtotime($dateStr);
    $months = ['Jan'=>'جنوری', 'Feb'=>'فروری', 'Mar'=>'مارچ', 'Apr'=>'اپریل', 'May'=>'مئی', 'Jun'=>'جون', 'Jul'=>'جولائی', 'Aug'=>'اگست', 'Sep'=>'ستمبر', 'Oct'=>'اکتوبر', 'Nov'=>'نومبر', 'Dec'=>'دسمبر'];
    $days = ['Mon'=>'پیر', 'Tue'=>'منگل', 'Wed'=>'بدھ', 'Thu'=>'جمعرات', 'Fri'=>'جمعہ', 'Sat'=>'ہفتہ', 'Sun'=>'اتوار'];
    return date('d', $timestamp) . ' ' . ($months[date('M', $timestamp)] ?? '') . ' ' . date('Y', $timestamp) . ' (' . ($days[date('D', $timestamp)] ?? '') . ')';
}
function cleanUrduStr($str) {
    if(!$str) return '-';
    $str = str_replace(['(3/4)','(1/2)','(1/4)','(1)','((', '))', 'پارہ '], ['', '', '', '', '(', ')', ''], $str);
    return trim($str);
}
function translateStatusClean($status) {
    $map = ['Excellent'=>'ممتاز', 'Good'=>'بہتر', 'Average'=>'معمولی', 'Weak'=>'کمزور'];
    $color = ['Excellent'=>'success', 'Good'=>'primary', 'Average'=>'warning', 'Weak'=>'danger'];
    $urdu = $map[$status] ?? $status;
    $c = $color[$status] ?? 'secondary';
    return "<span class='text-$c fw-bold'>$urdu</span>";
}
function translateQtyClean($str) {
    if(!$str) return '-';
    $map = ['Lines'=>'لائنیں', 'Pages'=>'صفحات', 'Ruku'=>'رکوع', 'Rubah'=>'پاؤ', 'Nisf'=>'نصف', 'Suls'=>'ثُلث', 'Full Para'=>'مکمل پارہ'];
    foreach($map as $e => $u) { $str = str_replace($e, $u, $str); }
    return trim($str);
}

// Fetch all students of this class
$sql_students = "SELECT id, name, father_name, roll_number, admission_number FROM students WHERE class = ? AND (is_deleted = 0 OR is_deleted IS NULL) AND status = 'Active'";
$stmt = $pdo->prepare($sql_students);
$stmt->execute([$selected_class]);
$all_students = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Fetch Hifz records
$sql = "SELECT d.* FROM daily_hifz d JOIN students s ON d.student_id = s.id 
        WHERE d.date BETWEEN ? AND ? AND (s.is_deleted = 0 OR s.is_deleted IS NULL) AND s.class = ?";
$stmt = $pdo->prepare($sql);
$stmt->execute([$start_date, $end_date, $selected_class]);
$hifz_records = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Fetch Complaints
$c_sql = "SELECT student_id, date, complaint as description FROM complaints WHERE date BETWEEN ? AND ?";
$stmt = $pdo->prepare($c_sql);
$stmt->execute([$start_date, $end_date]);
$complaints_data = $stmt->fetchAll(PDO::FETCH_ASSOC);
$complaints_map = [];
foreach($complaints_data as $cd) {
    $complaints_map[$cd['student_id'] . '_' . $cd['date']][] = $cd['description'];
}

// Calculate missed frequencies
$freq_sabaq = [];
$freq_sabqi = [];
$freq_manzil = [];
$student_records = []; // student_id => [date => rec]

foreach ($hifz_records as $rec) {
    $sid = $rec['student_id'];
    $student_records[$sid][$rec['date']] = $rec;
    
    // Check misses
    $miss_sabaq = empty(trim($rec['sabaq_parah'])) || $rec['sabaq_status'] == 'ناغہ' || $rec['sabaq_status'] == 'Absent' || empty(trim($rec['sabaq_status']));
    $miss_sabqi = empty(trim($rec['sabqi_parah'])) || $rec['sabqi_status'] == 'ناغہ' || $rec['sabqi_status'] == 'Absent' || empty(trim($rec['sabqi_status']));
    $miss_manzil = empty(trim($rec['manzil_parah'])) || $rec['manzil_status'] == 'ناغہ' || $rec['manzil_status'] == 'Absent' || empty(trim($rec['manzil_status']));
    
    if($miss_sabaq) $freq_sabaq[$sid] = ($freq_sabaq[$sid] ?? 0) + 1;
    if($miss_sabqi) $freq_sabqi[$sid] = ($freq_sabqi[$sid] ?? 0) + 1;
    if($miss_manzil) $freq_manzil[$sid] = ($freq_manzil[$sid] ?? 0) + 1;
}

// Ensure students with no records get their misses counted
$report_dates = [];
for ($c = strtotime($end_date); $c >= strtotime($start_date); $c -= 86400) {
    $report_dates[] = date('Y-m-d', $c);
}

foreach($all_students as $s) {
    $sid = $s['id'];
    foreach($report_dates as $d) {
        if(!isset($student_records[$sid][$d])) {
            $freq_sabaq[$sid] = ($freq_sabaq[$sid] ?? 0) + 1;
            $freq_sabqi[$sid] = ($freq_sabqi[$sid] ?? 0) + 1;
            $freq_manzil[$sid] = ($freq_manzil[$sid] ?? 0) + 1;
        }
    }
}

// Filter students
$filtered_student_ids = [];
foreach($all_students as $s) {
    $sid = $s['id'];
    
    if (!empty($filter_date)) {
        // Daily Summary Filter
        $rec = $student_records[$sid][$filter_date] ?? null;
        if ($rec) {
            $miss = false;
            if ($lesson_type == 'sabaq') $miss = empty(trim($rec['sabaq_parah'])) || $rec['sabaq_status'] == 'ناغہ' || $rec['sabaq_status'] == 'Absent' || empty(trim($rec['sabaq_status']));
            if ($lesson_type == 'sabqi') $miss = empty(trim($rec['sabqi_parah'])) || $rec['sabqi_status'] == 'ناغہ' || $rec['sabqi_status'] == 'Absent' || empty(trim($rec['sabqi_status']));
            if ($lesson_type == 'manzil') $miss = empty(trim($rec['manzil_parah'])) || $rec['manzil_status'] == 'ناغہ' || $rec['manzil_status'] == 'Absent' || empty(trim($rec['manzil_status']));
        } else {
            $miss = true;
        }
        
        if ($miss_count == '0' && !$miss) {
            $filtered_student_ids[] = $sid;
        } elseif ($miss_count == 'any' && $miss) {
            $filtered_student_ids[] = $sid;
        }
    } else {
        // Weekly Summary Filter
        $freq = 0;
        if ($lesson_type == 'sabaq') $freq = $freq_sabaq[$sid] ?? 0;
        if ($lesson_type == 'sabqi') $freq = $freq_sabqi[$sid] ?? 0;
        if ($lesson_type == 'manzil') $freq = $freq_manzil[$sid] ?? 0;
        
        if ($miss_count == 'more' && $freq > 3) $filtered_student_ids[] = $sid;
        elseif ($miss_count !== 'more' && $freq == (int)$miss_count) $filtered_student_ids[] = $sid;
    }
}

$title_label = "";
$type_label = ($lesson_type == 'sabaq') ? "سبق" : (($lesson_type == 'sabqi') ? "سبقی" : "منزل");
if (!empty($filter_date)) {
    $status_label = ($miss_count == '0') ? "سنانے والے طلبہ" : "کا ناغہ کرنے والے طلبہ";
    $title_label = "بتاریخ " . translateDateUrduFull($filter_date) . " " . $type_label . " " . $status_label;
} else {
    if ($miss_count == '0') $mc_lbl = "بِلا ناغہ (0 ناغے)";
    elseif ($miss_count == 'more') $mc_lbl = "3 سے زیادہ ناغے";
    else $mc_lbl = $miss_count . " ناغے";
    $title_label = "کل دورانیہ میں " . $type_label . " کے " . $mc_lbl . " والے طلبہ";
}
?>

<style>
    .table th, .table td { white-space: nowrap; }
    @media print {
        @page { size: A4 landscape; margin: 5mm; }
        body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
        .d-print-none { display: none !important; }
        .table-responsive { overflow: visible !important; }
        .table { width: 100% !important; table-layout: fixed !important; }
        .table th, .table td { white-space: normal !important; font-size: 10px !important; padding: 2px !important; }
    }
</style>

<div class="d-print-none card p-3 mb-4 bg-light shadow-sm text-end" dir="rtl">
    <a href="hifz_report.php?class=<?= urlencode($selected_class) ?>&from=<?= $start_date ?>&to=<?= $end_date ?>" class="btn btn-outline-secondary btn-sm fw-bold float-start mt-2"><i class="fas fa-arrow-right me-2"></i> واپس</a>
    <div class="text-end">
        <button type="button" onclick="window.print()" class="btn btn-dark fw-bold"><?php echo t('btn_print'); ?></button>
    </div>
</div>

<div class="bg-white p-3 text-end" dir="rtl">
    <div class="border-bottom border-2 border-dark mb-4 pb-2">
        <h3 class="m-0 fw-bold text-primary"><?= $title_label ?> (<?= count($filtered_student_ids) ?> طلبہ)</h3>
        <p class="mb-0 mt-1 fw-bold text-muted">کلاس: <?= htmlspecialchars($selected_class) ?></p>
    </div>

    <div class="table-responsive" style="width: 100%; overflow-x: auto;">
        <table class="table table-bordered border-dark text-center table-sm align-middle" style="font-size: 13px; min-width: 1200px;">
            <thead class="table-light">
                <tr>
                    <th rowspan="2" style="width: 3%;">#</th>
                    <th rowspan="2" style="width: 5%;">رول نمبر</th>
                    <th rowspan="2" style="width: 12%;"><?php echo t('student'); ?></th>
                    <th rowspan="2" style="width: 8%;">تاریخ</th>
                    <th colspan="3" class="bg-success text-white">سبق</th>
                    <th colspan="4" class="bg-primary text-white">سبقی</th>
                    <th colspan="4" class="bg-warning text-dark">منزل</th>
                    <th rowspan="2" style="width: 12%;" class="bg-danger text-white">شکایات</th>
                </tr>
                <tr>
                    <th style="width: 4%;">پارہ</th><th style="width: 4%;">لائنیں</th><th style="width: 5%;">کیفیت</th>
                    <th style="width: 7%;">تفصیل</th><th style="width: 5%;">مقدار</th><th style="width: 5%;">کیفیت</th><th style="width: 8%;">سننے والا</th>
                    <th style="width: 14%;">تفصیل</th><th style="width: 5%;">مقدار</th><th style="width: 5%;">کیفیت</th><th style="width: 8%;">سننے والا</th>
                </tr>
            </thead>
            <tbody>
                <?php
                if (count($filtered_student_ids) == 0) {
                    echo "<tr><td colspan='15' class='text-danger fw-bold p-3'>کوئی طالب علم نہیں ملا۔</td></tr>";
                } else {
                    $sr_no = 1;
                    foreach ($all_students as $student) {
                        if (!in_array($student['id'], $filtered_student_ids)) continue;
                        
                        $dates_to_show = empty($filter_date) ? $report_dates : [$filter_date];
                        $sid = $student['id'];
                        
                        foreach($dates_to_show as $d) {
                            $rec = $student_records[$sid][$d] ?? null;
                            $formatted_date = date('d-M-y', strtotime($d));
                            
                            if ($rec) {
                                $sabaq_parah = cleanUrduStr($rec['sabaq_parah'] ?? '');
                                $sabaq_lines = htmlspecialchars($rec['sabaq_lines'] ?? '');
                                $sabaq_status = translateStatusClean($rec['sabaq_status'] ?? '');
                                
                                $sabqi_parah = cleanUrduStr($rec['sabqi_parah'] ?? '');
                                $sabqi_amount = translateQtyClean($rec['sabqi_amount'] ?? '');
                                $sabqi_status = translateStatusClean($rec['sabqi_status'] ?? '');
                                $sabqi_listener = htmlspecialchars($rec['sabqi_listener'] ?? '');
                                
                                $manzil_parah = cleanUrduStr($rec['manzil_parah'] ?? '');
                                $manzil_amount = htmlspecialchars($rec['manzil_amount'] ?? '');
                                $manzil_status = translateStatusClean($rec['manzil_status'] ?? '');
                                $manzil_listener = htmlspecialchars($rec['manzil_listener'] ?? '');
                            } else {
                                $sabaq_parah = '-'; $sabaq_lines = '-'; $sabaq_status = '-';
                                $sabqi_parah = '-'; $sabqi_amount = '-'; $sabqi_status = '-'; $sabqi_listener = '-';
                                $manzil_parah = '-'; $manzil_amount = '-'; $manzil_status = '-'; $manzil_listener = '-';
                            }
                            
                            $comp_key = $sid . '_' . $d;
                            $complaints_html = isset($complaints_map[$comp_key]) ? implode('<br><hr class="my-1 border-danger">', $complaints_map[$comp_key]) : '-';
                            
                            echo "<tr>
                                <td>$sr_no</td>
                                <td>{$student['roll_number']}</td>
                                <td class='fw-bold'>{$student['name']}</td>
                                <td class='text-muted' style='font-size:11px;' dir='ltr'>{$formatted_date}</td>
                                <td>{$sabaq_parah}</td><td>{$sabaq_lines}</td><td>{$sabaq_status}</td>
                                <td style='font-size:11px;'>{$sabqi_parah}</td><td>{$sabqi_amount}</td><td>{$sabqi_status}</td><td class='small text-muted'>{$sabqi_listener}</td>
                                <td class='text-start ps-1' style='font-size:11px;'>{$manzil_parah}</td><td>{$manzil_amount}</td><td>{$manzil_status}</td><td class='small text-muted'>{$manzil_listener}</td>
                                <td class='small text-start text-danger' style='font-size:11px;'>{$complaints_html}</td>
                            </tr>";
                        }
                        $sr_no++;
                    }
                }
                ?>
            </tbody>
        </table>
    </div>
</div>

<?php include 'footer.php'; ?>
