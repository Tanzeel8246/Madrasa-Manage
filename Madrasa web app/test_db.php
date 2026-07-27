<?php
require 'db.php';
$stmt = $pdo->query("SELECT sabaq_parah, sabqi_parah, manzil_parah FROM daily_hifz WHERE sabaq_parah LIKE '%:%' OR sabqi_parah LIKE '%:%' OR manzil_parah LIKE '%:%' LIMIT 5");
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
