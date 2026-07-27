$content = Get-Content "Madrasa web app/hifz_report.php" -Raw

$index1 = $content.IndexOf("`$all_hifz_students = [];") + 25
$top = $content.Substring(0, $index1) + "`r`n}`r`n`r`n"

$middle = @"
// Helpers
function getGradePoints(`$grade, `$max) {
    if (!`$grade) return 0;
    `$g = trim(`$grade);
    if (in_array(`$g, ['Excellent', 'ممتاز', 'بہترین', 'اعلیٰ'])) return `$max;
    if (in_array(`$g, ['Good', 'بہتر', 'اچھا'])) return `$max * 0.8;
    if (in_array(`$g, ['Average', 'معمولی', 'مناسب'])) return `$max * 0.6;
    if (in_array(`$g, ['Weak', 'کمزور', 'توجہ طلب'])) return `$max * 0.4;
    return 0;
}

function translateDateUrduFull(`$dateStr) {
    if(!`$dateStr) return '-';
    `$timestamp = strtotime(`$dateStr);
    `$months = ['Jan'=>'جنوری', 'Feb'=>'فروری', 'Mar'=>'مارچ', 'Apr'=>'اپریل', 'May'=>'مئی', 'Jun'=>'جون', 'Jul'=>'جولائی', 'Aug'=>'اگست', 'Sep'=>'تمبر', 'Oct'=>'اکتوبر', 'Nov'=>'نومبر', 'Dec'=>'دسمبر'];
    `$days = ['Mon'=>'پیر', 'Tue'=>'منگل', 'Wed'=>'بدھ', 'Thu'=>'جمعرات', 'Fri'=>'جمعہ', 'Sat'=>'ہفتہ', 'Sun'=>'اتوار'];
    return date('d', `$timestamp) . '-' . (`$months[date('M', `$timestamp)] ?? '') . ' (' . (`$days[date('D', `$timestamp)] ?? '') . ')';
}

function translateStatusClean(`$status) {
    `$map = ['Excellent'=>'ممتاز', 'Good'=>'بہتر', 'Average'=>'معمولی', 'Weak'=>'کمزور', 'بہترین'=>'بہترین', 'بہتر'=>'بہتر', 'کمزور'=>'کمزور'];
    `$color = ['Excellent'=>'success', 'Good'=>'primary', 'Average'=>'warning', 'Weak'=>'danger', 'بہترین'=>'success', 'بہتر'=>'primary', 'کمزور'=>'danger'];
    `$urdu = `$map[`$status] ?? `$status;
    `$c = `$color[`$status] ?? 'secondary';
    return "<span class='text-`$c fw-bold'>`$urdu</span>";
}

function translateQtyClean(`$qty) {
    `$map = ['Quarter'=> 'پاؤ', 'Half'=> 'آدھا', 'Three Quarter'=> 'تین پاؤ', 'Full'=> 'مکمل', '1.5 Parah'=> 'ڈیڑھ', '2 Parah'=> 'دو', '2.5 Parah'=> 'ڈھائی', '3 Parah'=> 'تین'];
    return `$map[`$qty] ?? `$qty;
}

function shortName(`$name) {
    return (strlen(`$name) > 15) ? mb_substr(`$name, 0, 15).'..' : `$name;
}

function cleanUrduStr(`$str) {
    if(empty(`$str)) return '-';
    `$str = str_replace(['(3/4)', '(1/2)', '(1/4)', '(1)', '((', '))', 'پارہ '], ['', '', '', '', '(', ')', ''], `$str);
    `$str = preg_replace('/\(?\b(\d{1,2}:\d{2}(?:\s*[aApP][mM])?)\b\)?/i', '<div class="small text-muted" style="font-size: 0.75rem;">`$1</div>', `$str);
    return trim(`$str);
}
?>

<style>
    @media print {
        @page { size: A4 landscape; margin: 10mm; }
        body { -webkit-print-color-adjust: exact; print-color-adjust: exact; font-size: 11pt !important; }
        .table th, .table td { white-space: nowrap; font-size: 11pt !important; padding: 2px !important; }
        .card { border: none !important; box-shadow: none !important; margin: 0 !important; padding: 0 !important; }
        #printableArea { width: 100% !important; }
    }
    .table th, .table td { white-space: nowrap; }
    .bg-light-purple { background-color: #f3e5f5; }
    .gauge-container { position: relative; width: 80px; height: 80px; margin: 0 auto; }
    .gauge-svg { transform: rotate(-90deg); width: 100%; height: 100%; }
    .gauge-bg { fill: none; stroke: #eee; stroke-width: 8; }
    .gauge-fill { fill: none; stroke: var(--primary); stroke-width: 8; stroke-linecap: round; }
    .gauge-text { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); font-weight: bold; font-size: 14px; }
</style>

<div class="d-print-none card p-3 mb-4 bg-light shadow-sm text-end" dir="rtl">
    <a href="academic_view_dashboard.php" class="btn btn-outline-secondary btn-sm fw-bold float-start mt-2"><i class="fas fa-arrow-right me-2"></i> واپس ڈیش بورڈ</a>
    <form method="GET" class="row g-2 align-items-end">
        <input type="hidden" name="class" value="<?php echo htmlspecialchars(`$selected_class); ?>">
        <div class="col-md-3"><label class="fw-bold">تاریخ سے:</label><input type="date" name="from" class="form-control" value="<?php echo `$start_date; ?>"></div>
        <div class="col-md-3"><label class="fw-bold">تاریخ تک:</label><input type="date" name="to" class="form-control" value="<?php echo `$end_date; ?>"></div>
        <div class="col-md-2">
            <button type="submit" class="btn btn-success w-100 fw-bold mb-1">تلاش کریں</button>
            <button type="button" onclick="window.print()" class="btn btn-dark w-100 fw-bold"><?php echo t('btn_print'); ?></button>
        </div>
    </form>
</div>

<div id="printableArea" class="bg-white p-3 text-end" dir="rtl">
    <div class="d-flex justify-content-between align-items-center border-bottom border-2 border-dark mb-4 pb-2">
        <div><h2 class="m-0 fw-bold text-success"><i class="fas fa-quran me-2"></i> حفظ رپورٹس - <?= htmlspecialchars(`$selected_class) ?></h2></div>
        <div class="text-start"><p class="mb-0 fw-bold">دورانیہ: <span dir="ltr"><?php echo date('d M', strtotime(`$start_date)); ?> - <?php echo date('d M', strtotime(`$end_date)); ?></span></p></div>
    </div>

    <div class="table-responsive">
        <table class="table table-bordered border-dark text-center table-sm align-middle" style="font-size: 13px;">
            <thead class="table-light">
                <tr>
                    <th rowspan="2" style="width: 3%;">#</th>
                    <th rowspan="2" style="width: 5%;">رول نمبر</th>
                    <th rowspan="2" style="width: 12%;"><?php echo t('student'); ?></th>
                    <th colspan="3" class="bg-success text-white"><?php echo t('sabaq'); ?> (Sabaq)</th>
                    <th colspan="4" class="bg-primary text-white"><?php echo t('sabaq'); ?>ی (Sabqi)</th>
                    <th colspan="4" class="bg-warning text-dark"><?php echo t('manzil'); ?> (Manzil)</th>
                    <th rowspan="2" style="width: 12%;" class="bg-danger text-white">شکایات / کیفیت</th>
                </tr>
                <tr>
                    <th style="width: 4%;">پارہ</th><th style="width: 4%;">لائنیں</th><th style="width: 5%;">کیفیت</th>
                    <th style="width: 7%;">تفصیل</th><th style="width: 5%;">مقدار</th><th style="width: 5%;">کیفیت</th><th style="width: 8%;">سننے والا</th>
                    <th style="width: 14%;">تفصیل</th><th style="width: 5%;">مقدار</th><th style="width: 5%;">کیفیت</th><th style="width: 8%;">سننے والا</th>
                </tr>
            </thead>
            <tbody>
                <?php
                // Fetch Hifz records
                `$sql = "SELECT d.* FROM daily_hifz d 
                        JOIN students s ON d.student_id = s.id 
                        WHERE d.date BETWEEN ? AND ? AND (s.is_deleted = 0 OR s.is_deleted IS NULL) AND s.class = ?";
                try {
                    `$stmt = `$pdo->prepare(`$sql);
                    `$stmt->execute([`$start_date, `$end_date, `$selected_class]);
                    `$hifz_records = `$stmt->fetchAll(PDO::FETCH_ASSOC);
                } catch (PDOException `$e) {
"@

$index2 = $content.IndexOf("echo `"<tr><td colspan='15'>DB Error: `" . `$e->getMessage() . `"</td></tr>`";")
$bottom = $content.Substring($index2)

$newContent = $top + $middle + "`r`n                    " + $bottom

Set-Content "Madrasa web app/hifz_report.php" -Value $newContent -Encoding UTF8
