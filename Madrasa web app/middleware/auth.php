<?php
/**
 * Authentication, Session & Permissions Middleware
 * 
 * Provides role checking, permission evaluation (including Masjid parity),
 * class-level data isolation, and password hashing/verification.
 */

if (!function_exists('has_permission')) {
    /**
     * Check if the user has a specific permission, dynamically handling Masjid permissions
     */
    function has_permission($role, $user_permissions, $permission, $system_type = null) {
        $role_lower = strtolower((string)$role);
        if (in_array($role_lower, ['admin', 'superadmin', 'super_admin', 'administrator'], true)) return true;
        
        if ($system_type === null && isset($_SESSION['system_type'])) {
            $system_type = $_SESSION['system_type'];
        }
        
        if ($system_type === 'Masjid') {
            if (strpos($permission, 'manage_masjid_') !== 0) {
                if ($permission === 'add_complaint') {
                    $permission = 'manage_masjid_add_complaint';
                } else {
                    $permission = str_replace('manage_', 'manage_masjid_', $permission);
                }
            }
        }
        
        if (is_string($user_permissions)) {
            $user_permissions = json_decode($user_permissions, true) ?: [];
        }

        // Default teacher permissions if user is teacher
        if ($role === 'teacher') {
            $teacherBase = [
                'manage_attendance', 'manage_hifz', 'manage_academics', 'manage_teacher_attendance',
                'manage_masjid_attendance', 'manage_masjid_hifz', 'manage_masjid_academics', 'manage_masjid_teacher_attendance'
            ];
            if (in_array($permission, $teacherBase, true)) return true;
        }

        if ($role_lower === 'nazim') {
            $nazimBase = [
                'manage_attendance', 'manage_teacher_attendance', 'manage_attendance_report',
                'manage_hifz', 'manage_hifz_daily', 'manage_hifz_report',
                'manage_academics', 'manage_academic_dashboard', 'manage_academic_entry', 'manage_academic_view',
                'manage_students', 'manage_teachers', 'manage_classes', 'manage_exams',
                'manage_finance_entry', 'manage_finance_report',
                'manage_requests', 'manage_notices', 'manage_admissions', 'manage_complaints', 'add_complaint',
                // Masjid Parity
                'manage_masjid_attendance', 'manage_masjid_teacher_attendance', 'manage_masjid_attendance_report',
                'manage_masjid_hifz', 'manage_masjid_hifz_daily', 'manage_masjid_hifz_report',
                'manage_masjid_academics', 'manage_masjid_academic_dashboard', 'manage_masjid_academic_entry', 'manage_masjid_academic_view',
                'manage_masjid_students', 'manage_masjid_teachers', 'manage_masjid_classes', 'manage_masjid_exams',
                'manage_masjid_finance_entry', 'manage_masjid_finance_report',
                'manage_masjid_requests', 'manage_masjid_notices', 'manage_masjid_admissions', 'manage_masjid_complaints', 'manage_masjid_add_complaint'
            ];
            if (in_array($permission, $nazimBase, true)) return true;
        }
        
        return in_array($permission, $user_permissions ?? [], true);
    }
}

if (!function_exists('get_allowed_classes')) {
    function get_allowed_classes($pdo, $orderBy = 'id ASC', $apiRole = null, $apiUserId = null, $apiSystemType = null) {
        $rawRole = $apiRole !== null ? $apiRole : ($_SESSION['role'] ?? '');
        $role = strtolower(trim((string)$rawRole));
        $userId = $apiUserId !== null ? (int)$apiUserId : (int)($_SESSION['user_id'] ?? 0);

        // Resolve system_type: prefer explicit param, then GET, then session, then DB lookup
        $sys = $apiSystemType ?? $_GET['system_type'] ?? $_SESSION['system_type'] ?? null;
        if (!$sys && $userId) {
            try {
                $sysStmt = $pdo->prepare("SELECT system_type FROM admins WHERE id = ? LIMIT 1");
                $sysStmt->execute([$userId]);
                $sysRow = $sysStmt->fetch(PDO::FETCH_ASSOC);
                $sys = $sysRow['system_type'] ?? 'Madrasa';
            } catch (Exception $e) { $sys = 'Madrasa'; }
        }
        if (!$sys) $sys = 'Madrasa';
        
        $sys_cond = ($sys === 'Masjid') ? "system_type = 'Masjid'" : "(system_type = 'Madrasa' OR system_type IS NULL OR system_type = '')";
        $tenantId = function_exists('get_current_tenant_id') ? (int)get_current_tenant_id() : 1;
        $tenant_cond = "tenant_id = $tenantId";

        try {
            // Admin has full access to all classes for current system_type
            if (in_array($role, ['admin', 'superadmin', 'super_admin', 'administrator'], true)) {
                try {
                    $res = $pdo->query("SELECT * FROM classes WHERE $sys_cond AND $tenant_cond AND (is_deleted = 0 OR is_deleted IS NULL) ORDER BY $orderBy")->fetchAll(PDO::FETCH_ASSOC);
                } catch (Exception $e) {
                    $res = $pdo->query("SELECT * FROM classes WHERE $sys_cond AND $tenant_cond ORDER BY $orderBy")->fetchAll(PDO::FETCH_ASSOC);
                }
                return $res ?: [];
            }

            // Teachers: resolve classes from classes table (teacher_id, main_teacher_ids) and teachers.assigned_classes
            if ($role === 'teacher' && $userId) {
                $teacherClasses = [];
                // 1. Check classes where teacher_id matches
                try {
                    $tStmt = $pdo->prepare("SELECT * FROM classes WHERE teacher_id = ? AND $sys_cond AND $tenant_cond AND (is_deleted = 0 OR is_deleted IS NULL) ORDER BY $orderBy");
                    $tStmt->execute([$userId]);
                    $teacherClasses = $tStmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
                } catch (Exception $e) {}

                // 2. Check classes where main_teacher_ids contains $userId
                try {
                    $mStmt = $pdo->prepare("SELECT * FROM classes WHERE (main_teacher_ids LIKE ? OR main_teacher_ids LIKE ?) AND $sys_cond AND $tenant_cond AND (is_deleted = 0 OR is_deleted IS NULL) ORDER BY $orderBy");
                    $mStmt->execute(['%' . $userId . '%', '%"' . $userId . '"%']);
                    $mClasses = $mStmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
                    foreach ($mClasses as $mc) {
                        if (!in_array($mc['id'], array_column($teacherClasses, 'id'))) {
                            $teacherClasses[] = $mc;
                        }
                    }
                } catch (Exception $e) {}

                // 3. Check teachers table assigned_classes column
                try {
                    $tRowStmt = $pdo->prepare("SELECT assigned_classes FROM teachers WHERE id = ? AND $tenant_cond LIMIT 1");
                    $tRowStmt->execute([$userId]);
                    $tRow = $tRowStmt->fetch(PDO::FETCH_ASSOC);
                    if (!empty($tRow['assigned_classes'])) {
                        $rawAssigned = trim((string)$tRow['assigned_classes']);
                        $classNamesOrIds = array_filter(array_map('trim', explode(',', $rawAssigned)));
                        if (!empty($classNamesOrIds)) {
                            $quoted = implode(',', array_map(function($val) use ($pdo) { return $pdo->quote($val); }, $classNamesOrIds));
                            $extraStmt = $pdo->query("SELECT * FROM classes WHERE (name IN ($quoted) OR id IN ($quoted)) AND $sys_cond AND $tenant_cond AND (is_deleted = 0 OR is_deleted IS NULL) ORDER BY $orderBy");
                            if ($extraStmt) {
                                foreach ($extraStmt->fetchAll(PDO::FETCH_ASSOC) as $ec) {
                                    if (!in_array($ec['id'], array_column($teacherClasses, 'id'))) {
                                        $teacherClasses[] = $ec;
                                    }
                                }
                            }
                        }
                    }
                } catch (Exception $e) {}

                if (!empty($teacherClasses)) {
                    return $teacherClasses;
                }
            }

            // Non-admin (nazim, staff) restricted strictly by allowed_classes
            if ($userId) {
                $stmt = $pdo->prepare("SELECT allowed_classes, permissions FROM admins WHERE id = ?");
                $stmt->execute([$userId]);
                $admin_row = $stmt->fetch(PDO::FETCH_ASSOC);
                
                if ($admin_row && array_key_exists('allowed_classes', $admin_row) && $admin_row['allowed_classes'] !== null) {
                    $decoded = json_decode((string)$admin_row['allowed_classes'], true);
                    if (is_array($decoded)) {
                        $allowed_ids = array_values(array_filter(array_map('intval', $decoded)));
                        if (empty($allowed_ids)) {
                            // If user is nazim, empty allowed_classes means no specific restriction (all classes allowed)
                            if ($role === 'nazim') {
                                try {
                                    $res = $pdo->query("SELECT * FROM classes WHERE $sys_cond AND $tenant_cond AND (is_deleted = 0 OR is_deleted IS NULL) ORDER BY $orderBy")->fetchAll(PDO::FETCH_ASSOC);
                                } catch (Exception $e) {
                                    $res = $pdo->query("SELECT * FROM classes WHERE $sys_cond AND $tenant_cond ORDER BY $orderBy")->fetchAll(PDO::FETCH_ASSOC);
                                }
                                return $res ?: [];
                            }
                            // Explicitly assigned empty allowed_classes -> access to zero classes
                            return [];
                        }
                        $placeholders = implode(',', array_fill(0, count($allowed_ids), '?'));
                        try {
                            $stmt = $pdo->prepare("SELECT * FROM classes WHERE id IN ($placeholders) AND $sys_cond AND $tenant_cond AND (is_deleted = 0 OR is_deleted IS NULL) ORDER BY $orderBy");
                            $stmt->execute($allowed_ids);
                            $res = $stmt->fetchAll(PDO::FETCH_ASSOC);
                        } catch (Exception $e) {
                            $stmt = $pdo->prepare("SELECT * FROM classes WHERE id IN ($placeholders) AND $sys_cond AND $tenant_cond ORDER BY $orderBy");
                            $stmt->execute($allowed_ids);
                            $res = $stmt->fetchAll(PDO::FETCH_ASSOC);
                        }
                        return $res ?: [];
                    }
                }
            }

            // If allowed_classes was unconfigured (NULL) in legacy record and user is nazim
            if ($role === 'nazim') {
                try {
                    $res = $pdo->query("SELECT * FROM classes WHERE $sys_cond AND $tenant_cond AND (is_deleted = 0 OR is_deleted IS NULL) ORDER BY $orderBy")->fetchAll(PDO::FETCH_ASSOC);
                } catch (Exception $e) {
                    $res = $pdo->query("SELECT * FROM classes WHERE $sys_cond AND $tenant_cond ORDER BY $orderBy")->fetchAll(PDO::FETCH_ASSOC);
                }
                return $res ?: [];
            }

            return [];
        } catch (Exception $e) {
            return [];
        }
    }
}

if (!function_exists('get_user_allowed_class_names')) {
    function get_user_allowed_class_names($pdo, $apiRole = null, $apiUserId = null, $apiSystemType = null) {
        $classes = get_allowed_classes($pdo, 'name ASC', $apiRole, $apiUserId, $apiSystemType);
        return array_values(array_filter(array_unique(array_column($classes, 'name'))));
    }
}

if (!function_exists('get_student_class_privacy_sql')) {
    function get_student_class_privacy_sql($pdo, $classColumn = 'class', $apiRole = null, $apiUserId = null, $apiSystemType = null) {
        $rawRole = $apiRole !== null ? $apiRole : ($_SESSION['role'] ?? '');
        $role = strtolower(trim((string)$rawRole));
        if (in_array($role, ['admin', 'superadmin', 'administrator'], true)) {
            return "1=1";
        }
        $names = get_user_allowed_class_names($pdo, $apiRole, $apiUserId, $apiSystemType);
        if (empty($names)) {
            return "1=0";
        }
        $quoted = array_map(function($n) use ($pdo) { return $pdo->quote($n); }, $names);
        $inList = implode(',', $quoted);
        return "TRIM($classColumn) IN ($inList)";
    }
}

if (!function_exists('app_has_perm')) {
    function app_has_perm($perm) {
        if (!isset($_SESSION['role'])) return false;
        $perms = $_SESSION['permissions'] ?? [];
        return has_permission($_SESSION['role'], $perms, $perm);
    }
}

/**
 * Password Hashing Helpers
 */
if (!function_exists('hash_pass')) {
    function hash_pass($password) {
        return password_hash($password, PASSWORD_BCRYPT);
    }
}

if (!function_exists('verify_pass')) {
    function verify_pass($password, $hash) {
        if (empty($hash)) return false;
        $hash = trim($hash);
        if ($password === $hash) return true;
        if (password_verify($password, $hash)) return true;
        if (md5($password) === strtolower($hash) || md5($password) === $hash) return true;
        if (sha1($password) === strtolower($hash) || sha1($password) === $hash) return true;
        return false;
    }
}
