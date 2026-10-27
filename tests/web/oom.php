<?php
register_shutdown_function(function () { error_log("SHUTDOWN RAN"); });
ini_set("memory_limit", "16M");
$x = str_repeat("x", 32 * 1024 * 1024);
