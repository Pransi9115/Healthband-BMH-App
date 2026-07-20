<?php
// ─────────────────────────────────────────────────────────
//  BMH — BATTERY ALERT FAN-OUT
//  Deploy at: https://your.server/notify_battery.php
//  The app posts here when the patient's battery drops below 20%
//  (and for "Send test alert"). This script alerts each contact.
//
//  Payload (JSON):
//  {
//    "type": "battery_low" | "battery_test",
//    "patient_name": "M. Patel",
//    "level": 18,
//    "charging": false,
//    "threshold": 20,
//    "timestamp": "2026-07-20T14:32:00",
//    "contacts": [ { "name": "...", "relation": "...",
//                    "phone": "+91...", "email": "..." }, ... ]  // max 5
//  }
//
//  Out of the box: email via PHP mail() + a delivery log file.
//  SMS/WhatsApp: fill in sendSms() with your provider (Twilio,
//  MSG91, Gupshup, etc.) — the hook is already called per contact.
// ─────────────────────────────────────────────────────────

header('Content-Type: application/json');

// Optional shared-secret check — set the same value in the app if
// you want to lock this endpoint down (recommended for production).
$API_SECRET = '';   // e.g. 'change-me'; empty = check disabled
if ($API_SECRET !== '' &&
    ($_SERVER['HTTP_X_BMH_SECRET'] ?? '') !== $API_SECRET) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'error' => 'unauthorized']);
    exit;
}

$raw  = file_get_contents('php://input');
$data = json_decode($raw, true);

if (!is_array($data) || empty($data['contacts'])) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'bad payload']);
    exit;
}

$type     = $data['type'] ?? 'battery_low';
$patient  = substr(trim($data['patient_name'] ?? 'A BMH patient'), 0, 80);
$level    = (int)($data['level'] ?? 0);
$charging = !empty($data['charging']);
$when     = $data['timestamp'] ?? date('c');
$contacts = array_slice($data['contacts'], 0, 5);   // hard cap: 5

// ── Throttle: max one real alert per patient per hour ─────
// (test alerts are never throttled). Uses a small state file;
// swap for a DB table when you wire this into the platform.
$stateDir = __DIR__ . '/battery_state';
if (!is_dir($stateDir)) { mkdir($stateDir, 0770, true); }
$stateKey = $stateDir . '/' . md5($patient) . '.last';

if ($type === 'battery_low') {
    $last = @file_get_contents($stateKey);
    if ($last !== false && (time() - (int)$last) < 3600) {
        echo json_encode(['ok' => true, 'throttled' => true]);
        exit;
    }
    file_put_contents($stateKey, (string)time());
}

// ── Compose the message ───────────────────────────────────
$isTest  = ($type === 'battery_test');
$subject = $isTest
    ? "BioHealthcare test alert — {$patient}"
    : "BioHealthcare: {$patient}'s phone battery is low ({$level}%)";
$bodyFor = function ($contactName) use ($patient, $level, $when, $isTest) {
    $lead = $isTest
        ? "This is a TEST alert from BioHealthcare — no action needed.\n\n"
        : '';
    return $lead .
        "Hello {$contactName},\n\n" .
        "{$patient}'s phone battery has dropped to {$level}% and it is " .
        "not charging. If it switches off, health monitoring and calls " .
        "to them will stop working.\n\n" .
        "Please check on them or remind them to charge their phone.\n\n" .
        "Time: {$when}\n" .
        "— BioHealthcare";
};

// ── SMS hook: plug in your provider here ──────────────────
function sendSms(string $phone, string $message): bool {
    // Example (Twilio): POST to their API with your SID/token.
    // Example (MSG91 / Gupshup): their send-SMS endpoint.
    // Return true on provider success. Until wired, report false
    // so delivery honestly shows email-only.
    return false;
}

// ── Fan out ───────────────────────────────────────────────
$results = [];
foreach ($contacts as $c) {
    $name  = substr(trim($c['name'] ?? ''), 0, 80);
    $phone = preg_replace('/[^0-9+]/', '', $c['phone'] ?? '');
    $email = filter_var(trim($c['email'] ?? ''), FILTER_VALIDATE_EMAIL);

    $sentEmail = false;
    if ($email) {
        $sentEmail = @mail(
            $email,
            $subject,
            $bodyFor($name ?: 'there'),
            "From: alerts@biohealthcare.example\r\n" .
            "Content-Type: text/plain; charset=UTF-8"
        );
    }

    $sentSms = $phone !== '' ? sendSms($phone, $bodyFor($name)) : false;

    $results[] = [
        'name'  => $name,
        'email' => $sentEmail ? 'sent' : ($email ? 'failed' : 'none'),
        'sms'   => $sentSms   ? 'sent' : ($phone ? 'not_configured' : 'none'),
    ];
}

// ── Delivery log (append-only, one JSON line per alert) ───
@file_put_contents(
    $stateDir . '/delivery.log',
    json_encode([
        'at' => date('c'), 'type' => $type, 'patient' => $patient,
        'level' => $level, 'charging' => $charging, 'results' => $results,
    ]) . "\n",
    FILE_APPEND | LOCK_EX
);

echo json_encode(['ok' => true, 'delivered' => $results]);
