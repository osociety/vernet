enum NetworkConnectionState {
  connected,
  disconnected,
  checking,
}

enum NetworkConnectionType {
  deviceToRouter,
  routerToInternet,
}

class NetworkConnectionStatus {
  const NetworkConnectionStatus({
    required this.type,
    required this.state,
    required this.title,
    required this.summary,
    required this.description,
    this.troubleshootingSteps = const [],
    this.details = const {},
    this.latency,
    this.targetHost,
    this.interfaceType,
  });

  final NetworkConnectionType type;
  final NetworkConnectionState state;
  final String title;
  final String summary;
  final String description;
  final List<String> troubleshootingSteps;
  final Map<String, String> details;
  final Duration? latency;
  final String? targetHost;
  final String? interfaceType;

  bool get isConnected => state == NetworkConnectionState.connected;
  bool get isDisconnected => state == NetworkConnectionState.disconnected;
  bool get isChecking => state == NetworkConnectionState.checking;

  String get label => switch (state) {
        NetworkConnectionState.connected => 'Connected',
        NetworkConnectionState.disconnected => 'Disconnected',
        NetworkConnectionState.checking => 'Checking…',
      };
}
