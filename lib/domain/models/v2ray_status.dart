class V2RayStatus {
  final String duration;
  final int uploadSpeed;
  final int downloadSpeed;
  final String state;
  final int? delay;

  V2RayStatus({
    required this.duration,
    required this.uploadSpeed,
    required this.downloadSpeed,
    required this.state,
    this.delay,
  });

  factory V2RayStatus.disconnected() {
    return V2RayStatus(
      duration: '00:00:00',
      uploadSpeed: 0,
      downloadSpeed: 0,
      state: 'DISCONNECTED',
      delay: null,
    );
  }

  static V2RayStatus fromMap(Map<String, dynamic> map) {
    return V2RayStatus(
      duration: map['duration'] ?? '00:00:00',
      uploadSpeed: map['uploadSpeed'] ?? 0,
      downloadSpeed: map['downloadSpeed'] ?? 0,
      state: map['state'] ?? 'DISCONNECTED',
      delay: map['delay'],
    );
  }
}
