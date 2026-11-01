import 'dart:async';
import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:speed_test_dart/classes/server.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/repository/network_score_repository.dart';

part 'speed_test_event.dart';
part 'speed_test_state.dart';
part 'speed_test_bloc.freezed.dart';

@singleton
class SpeedTestBloc extends Bloc<SpeedTestEvent, SpeedTestState> {
  SpeedTestBloc() : super(const SpeedTestState.data()) {
    on<_Init>(_onInit);
    on<_LoadIspInfo>(_onLoadIspInfo);
    on<_LoadServers>(_onLoadServers);
    on<_StartTest>(_onStartTest);
    on<_UpdateDownloadSpeed>(_onUpdateDownloadSpeed);
    on<_UpdateUploadSpeed>(_onUpdateUploadSpeed);
    on<_SetDownloadSpeeds>(_onSetDownloadSpeeds);
    on<_SetUploadSpeeds>(_onSetUploadSpeeds);
    on<_CompleteDownload>(_onCompleteDownload);
    on<_CompleteUpload>(_onCompleteUpload);
    on<_ToggleServerInfo>(_onToggleServerInfo);
    on<_Reset>(_onReset);
  }

  final SpeedTestDart _tester = SpeedTestDart();
  final Random _rng = Random();
  static const int _numberOfTests = 4;
  Timer? _progressTimer;

  Future<void> _onInit(_Init event, Emitter<SpeedTestState> emit) async {
    await _loadIspInfo(emit);
    if (event.preloadedServers != null && event.preloadedServers!.isNotEmpty) {
      emit(state.copyWith(
        bestServers: event.preloadedServers,
        isLoading: false,
      ));
    } else {
      await _loadServers(emit);
    }
  }

  Future<void> _onLoadIspInfo(_LoadIspInfo event, Emitter<SpeedTestState> emit) async {
    await _loadIspInfo(emit);
  }

  Future<void> _onLoadServers(_LoadServers event, Emitter<SpeedTestState> emit) async {
    await _loadServers(emit);
  }

  Future<void> _onStartTest(_StartTest event, Emitter<SpeedTestState> emit) async {
    if (state.bestServers == null || state.bestServers!.isEmpty) return;

    final servers = state.bestServers!;

    emit(state.copyWith(
      speedTestStarted: true,
      downloadSpeedTestDone: false,
      uploadSpeedTestDone: false,
      downloadSpeeds: [],
      uploadSpeeds: [],
      currentDownloadSpeed: 0,
      currentUploadSpeed: 0,
    ));

    try {
      await _testDownloadSpeed(emit, servers);
      await _testUploadSpeed(emit, servers);
      await _saveSpeedSnapshot(emit);
    } catch (e) {
      _progressTimer?.cancel();
      emit(state.copyWith(fetchError: 'Speed test failed: $e'));
    } finally {
      emit(state.copyWith(
        speedTestStarted: false,
        isServerInfoExpanded: true,
      ));
    }
  }

  void _onUpdateDownloadSpeed(_UpdateDownloadSpeed event, Emitter<SpeedTestState> emit) {
    final speeds = List<double>.from(state.downloadSpeeds)..add(event.speed);
    emit(state.copyWith(
      currentDownloadSpeed: event.speed,
      downloadSpeeds: speeds,
    ));
  }

  void _onUpdateUploadSpeed(_UpdateUploadSpeed event, Emitter<SpeedTestState> emit) {
    final speeds = List<double>.from(state.uploadSpeeds)..add(event.speed);
    emit(state.copyWith(
      currentUploadSpeed: event.speed,
      uploadSpeeds: speeds,
    ));
  }

  void _onSetDownloadSpeeds(_SetDownloadSpeeds event, Emitter<SpeedTestState> emit) {
    emit(state.copyWith(downloadSpeeds: event.speeds));
  }

  void _onSetUploadSpeeds(_SetUploadSpeeds event, Emitter<SpeedTestState> emit) {
    emit(state.copyWith(uploadSpeeds: event.speeds));
  }

  void _onCompleteDownload(_CompleteDownload event, Emitter<SpeedTestState> emit) {
    emit(state.copyWith(downloadSpeedTestDone: true));
  }

  void _onCompleteUpload(_CompleteUpload event, Emitter<SpeedTestState> emit) {
    emit(state.copyWith(uploadSpeedTestDone: true));
  }

  void _onToggleServerInfo(_ToggleServerInfo event, Emitter<SpeedTestState> emit) {
    emit(state.copyWith(isServerInfoExpanded: !state.isServerInfoExpanded));
  }

  void _onReset(_Reset event, Emitter<SpeedTestState> emit) {
    _progressTimer?.cancel();
    emit(const SpeedTestState.data());
  }

  Future<void> _loadIspInfo(Emitter<SpeedTestState> emit) async {
    final ispInfo = await NetworkScoreRepository().loadIspInfo();
    emit(state.copyWith(ispInfo: ispInfo));
  }

  Future<void> _loadServers(Emitter<SpeedTestState> emit) async {
    try {
      final settings = await _tester.getSettings(headers: {"User-Agent": "Mozilla/4.0"});
      final result = await _tester.getBestServers(servers: settings.servers);
      result.sort((a, b) => a.latency.compareTo(b.latency));
      emit(state.copyWith(
        bestServers: result,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        fetchError: 'Could not find test servers. Check your connection.',
        isLoading: false,
      ));
    }
  }

  void _startFakeProgress({
    required bool isDownload,
    required double variation,
    required double minSpeed,
  }) {
    _progressTimer?.cancel();
    double currentSpeed = 0;
    _progressTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (Timer t) {
        currentSpeed = currentSpeed + (_rng.nextDouble() * variation - (variation / 2 - 2));
        if (currentSpeed < minSpeed) currentSpeed = minSpeed;
        if (currentSpeed > 100) currentSpeed = 100;
        if (isDownload) {
          add(SpeedTestEvent.updateDownloadSpeed(currentSpeed));
        } else {
          add(SpeedTestEvent.updateUploadSpeed(currentSpeed));
        }
      },
    );
  }

  Future<void> _testDownloadSpeed(
    Emitter<SpeedTestState> emit,
    List<Server> servers,
  ) async {
    emit(state.copyWith(
      currentDownloadSpeed: 0,
      downloadSpeeds: [0],
    ));

    _startFakeProgress(isDownload: true, variation: 10, minSpeed: 0);

    final speeds = <double>[];
    for (int i = 0; i < _numberOfTests; i++) {
      try {
        final speed = await _tester
            .testDownloadSpeed(servers: servers)
            .timeout(const Duration(seconds: 30));
        speeds.add(speed);
        // Show average of completed tests so far
        final avg = speeds.reduce((a, b) => a + b) / speeds.length;
        emit(state.copyWith(currentDownloadSpeed: avg));
      } on TimeoutException {
        _progressTimer?.cancel();
        _progressTimer = null;
        emit(state.copyWith(
          fetchError: 'Download test timed out. Check your connection.',
          downloadSpeedTestDone: true,
        ));
        return;
      }
    }

    _progressTimer?.cancel();
    _progressTimer = null;
    // Emit final average
    final finalAvg = speeds.reduce((a, b) => a + b) / speeds.length;
    emit(state.copyWith(
      currentDownloadSpeed: finalAvg,
      downloadSpeedTestDone: true,
    ));
  }

  Future<void> _testUploadSpeed(
    Emitter<SpeedTestState> emit,
    List<Server> servers,
  ) async {
    emit(state.copyWith(
      currentUploadSpeed: 0,
      uploadSpeeds: [0],
      downloadSpeeds: [],
    ));

    _startFakeProgress(isDownload: false, variation: 8, minSpeed: 0);

    final speeds = <double>[];
    for (int i = 0; i < _numberOfTests; i++) {
      try {
        final speed = await _tester
            .testUploadSpeed(servers: servers)
            .timeout(const Duration(seconds: 30));
        speeds.add(speed);
        // Show average of completed tests so far
        final avg = speeds.reduce((a, b) => a + b) / speeds.length;
        emit(state.copyWith(currentUploadSpeed: avg));
      } on TimeoutException {
        _progressTimer?.cancel();
        _progressTimer = null;
        emit(state.copyWith(
          fetchError: 'Upload test timed out. Check your connection.',
          uploadSpeedTestDone: true,
        ));
        return;
      }
    }

    _progressTimer?.cancel();
    _progressTimer = null;
    // Emit final average
    final finalAvg = speeds.reduce((a, b) => a + b) / speeds.length;
    emit(state.copyWith(
      currentUploadSpeed: finalAvg,
      uploadSpeedTestDone: true,
    ));
  }

  Future<void> _saveSpeedSnapshot(Emitter<SpeedTestState> emit) async {
    if (state.bestServers == null || state.bestServers!.isEmpty) return;

    final ispInfo = await NetworkScoreRepository().loadIspInfo();
    await NetworkScoreRepository().saveSpeedSnapshot(SpeedSnapshot(
      downloadMbps: state.currentDownloadSpeed,
      uploadMbps: state.currentUploadSpeed,
      latencyMs: state.bestServers!.first.latency.toDouble(),
      ispRating: ispInfo?.ispRating,
      ispAvgDownloadMbps: ispInfo?.avgDownloadMbps,
      ispAvgUploadMbps: ispInfo?.avgUploadMbps,
      ispName: ispInfo?.ispName,
    ));

    getIt<NetworkScoreBloc>().add(const NetworkScoreEvent.refresh());
  }
}
