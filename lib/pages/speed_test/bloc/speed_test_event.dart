part of 'speed_test_bloc.dart';

@freezed
class SpeedTestEvent with _$SpeedTestEvent {
  const factory SpeedTestEvent.init({List<Ndt7Server>? preloadedServers}) = _Init;
  const factory SpeedTestEvent.loadServers() = _LoadServers;
  const factory SpeedTestEvent.startTest() = _StartTest;
  const factory SpeedTestEvent.updateDownloadSpeed(double speed) = _UpdateDownloadSpeed;
  const factory SpeedTestEvent.updateUploadSpeed(double speed) = _UpdateUploadSpeed;
  const factory SpeedTestEvent.setDownloadSpeeds(List<double> speeds) = _SetDownloadSpeeds;
  const factory SpeedTestEvent.setUploadSpeeds(List<double> speeds) = _SetUploadSpeeds;
  const factory SpeedTestEvent.completeDownload() = _CompleteDownload;
  const factory SpeedTestEvent.completeUpload() = _CompleteUpload;
  const factory SpeedTestEvent.toggleServerInfo() = _ToggleServerInfo;
  const factory SpeedTestEvent.reset() = _Reset;
}
