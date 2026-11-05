part of 'speed_test_bloc.dart';

@freezed
sealed class SpeedTestState with _$SpeedTestState {
  const factory SpeedTestState.data({
    @Default(true) bool isLoading,
    @Default(false) bool speedTestStarted,
    @Default(false) bool downloadSpeedTestDone,
    @Default(false) bool uploadSpeedTestDone,
    @Default(false) bool showSummary,
    @Default(false) bool isServerInfoExpanded,
    @Default(0.0) double currentDownloadSpeed,
    @Default(0.0) double currentUploadSpeed,
    @Default(<double>[]) List<double> downloadSpeeds,
    @Default(<double>[]) List<double> uploadSpeeds,
    List<Ndt7Server>? bestServers,
    String? fetchError,
    double? latencyMs,
    double? packetLossPercent,
    int? retransmissions,
    double? retransmissionPercentage,
    String? serverLocation,
  }) = _SpeedTestStateData;
}
