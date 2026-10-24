<?php
if (session_status() === PHP_SESSION_NONE) { session_start(); }
$_SESSION = [];
if (ini_get("session.use_cookies")) {
    $params = session_get_cookie_params();
    setcookie(session_name(), '', time() - 42000,
        $params["path"], $params["domain"],
        $params["secure"], $params["httponly"]
    );
}
setcookie('remember_token', '', time() - 3600, '/');
setcookie('remember_user', '', time() - 3600, '/');
setcookie('user_token', '', time() - 3600, '/');
session_unset();
session_destroy();

header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Pragma: no-cache");
header("Expires: Sat, 26 Jul 1997 05:00:00 GMT");
header("Location: login.php?logged_out=1");
exit;
