/// Response model for health sync operations
class HealthSyncResponse {
  final bool ok;
  final bool fromOtherApps;
  final String? message;
  final DateTime? timestamp;

  HealthSyncResponse({
    required this.ok,
    this.fromOtherApps = false,
    this.message,
    this.timestamp,
  });

  factory HealthSyncResponse.success({
    bool fromOtherApps = false,
    String? message,
  }) {
    return HealthSyncResponse(
      ok: true,
      fromOtherApps: fromOtherApps,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  factory HealthSyncResponse.failure({
    String? message,
  }) {
    return HealthSyncResponse(
      ok: false,
      message: message,
      timestamp: DateTime.now(),
    );
  }
}
