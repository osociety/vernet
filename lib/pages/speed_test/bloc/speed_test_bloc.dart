import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/models/ndt7_result.dart';
import 'package:vernet/pages/network_score/bloc/network_score_bloc.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/services/speedtest/ndt7_service.dart';

part 'speed_test_event.dart';
part 'speed_test_state.dart';
part 'speed_test_bloc.freezed.dart';

@singleton
class SpeedTestBloc extends Bloc<SpeedTestEvent, SpeedTestState> {
  SpeedTestBloc({required Ndt7Service ndt7Service})
      : _ndt7Service = ndt7Service,
        super(const SpeedTestState.data()) {
    on<_Init>(_onInit);
    on<_LoadServers>(_onLoadServers);
    on<_StartTest>(_onStartTest);
    on<_ToggleServerInfo>(_onToggleServerInfo);
    on<_Reset>(_onReset);
    on<_LoadResult>(_onLoadResult);
  }

  final Ndt7Service _ndt7Service;

  Future<void> _onInit(_Init event, Emitter<SpeedTestState> emit) async {
    if (event.preloadedServers != null && event.preloadedServers!.isNotEmpty) {
      emit(state.copyWith(
        bestServers: event.preloadedServers,
        isLoading: false,
      ));
    } else {
      await _loadServers(emit);
    }
  }

  Future<void> _onLoadServers(
      _LoadServers event, Emitter<SpeedTestState> emit) async {
    await _loadServers(emit);
  }

  Future<void> _onStartTest(
      _StartTest event, Emitter<SpeedTestState> emit) async {
    if (state.bestServers == null || state.bestServers!.isEmpty) {
      emit(state.copyWith(
        fetchError: 'No test servers available. Please check your connection.',
      ));
      return;
    }

    // Clean up any leftover state from previous test
    _ndt7Service.reset();

    emit(state.copyWith(
      speedTestStarted: true,
      downloadSpeedTestDone: false,
      uploadSpeedTestDone: false,
      showSummary: false,
      downloadSpeeds: [],
      uploadSpeeds: [],
      currentDownloadSpeed: 0,
      currentUploadSpeed: 0,
      latencyMs: null,
      packetLossPercent: null,
      retransmissions: null,
      serverLocation: null,
      fetchError: null,
      isServerInfoExpanded: false,
      isWarmingUp: false,
    ));

    final servers = state.bestServers!;
    Object? lastError;

    for (var i = 0; i < servers.length; i++) {
      final server = servers[i];
      try {
        final result = await _runNdt7Test(server, emit);
        await _saveSpeedSnapshot(emit, result);

        emit(state.copyWith(
          speedTestStarted: false,
          showSummary: true,
          isServerInfoExpanded: true,
        ));
        return;
      } catch (e) {
        lastError = e;
        if (i < servers.length - 1) {
          emit(state.copyWith(
            downloadSpeeds: [],
            uploadSpeeds: [],
            currentDownloadSpeed: 0,
            currentUploadSpeed: 0,
            downloadSpeedTestDone: false,
            uploadSpeedTestDone: false,
          ));
        }
      }
    }

    final errorMessage = _buildUserFriendlyError(lastError);
    emit(state.copyWith(
      fetchError: errorMessage,
      speedTestStarted: false,
      showSummary: false,
    ));
  }

  String _buildUserFriendlyError(Object? error) {
    if (error == null) {
      return 'Speed test failed. Please try again later.';
    }

    final errorStr = error.toString().toLowerCase();

    // Connection/timeout errors suggest high demand or network issues
    if (errorStr.contains('timed out') ||
        errorStr.contains('connection failed') ||
        errorStr.contains('websocket') ||
        errorStr.contains('all servers')) {
      return 'Sorry, it looks like the Internet speed test is experiencing high demand. Please try again later.';
    }

    // Network errors
    if (errorStr.contains('network error') || errorStr.contains('socket')) {
      return 'Network connection failed. Please check your internet connection and try again.';
    }

    // Generic fallback
    return 'Speed test failed. Please try again later.';
  }

  void _onToggleServerInfo(
      _ToggleServerInfo event, Emitter<SpeedTestState> emit) {
    emit(state.copyWith(isServerInfoExpanded: !state.isServerInfoExpanded));
  }

  void _onReset(_Reset event, Emitter<SpeedTestState> emit) {
    emit(const SpeedTestState.data());
  }

  void _onLoadResult(_LoadResult event, Emitter<SpeedTestState> emit) {
    final result = event.result;
    emit(state.copyWith(
      isLoading: false,
      speedTestStarted: false,
      downloadSpeedTestDone: true,
      uploadSpeedTestDone: true,
      showSummary: true,
      currentDownloadSpeed: result.downloadMbps,
      currentUploadSpeed: result.uploadMbps,
      latencyMs: result.latencyMs,
      retransmissions: result.retransmissions,
      retransmissionPercentage: result.retransmissionPercentage,
      serverLocation: result.server.site,
      isServerInfoExpanded: true,
    ));
  }

  Future<void> _loadServers(Emitter<SpeedTestState> emit) async {
    try {
      final servers = await _ndt7Service.discoverServers();
      emit(state.copyWith(
        bestServers: servers,
        isLoading: false,
      ));
    } on Ndt7Exception catch (e) {
      emit(state.copyWith(
        fetchError: 'Could not find test servers: ${e.message}',
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        fetchError: 'Could not find test servers. Check your connection.',
        isLoading: false,
      ));
    }
  }

  Future<Ndt7TestResult> _runNdt7Test(
    Ndt7Server server,
    Emitter<SpeedTestState> emit,
  ) async {
    emit(state.copyWith(
      currentDownloadSpeed: 0,
      downloadSpeeds: [0],
    ));

    final downloadResult = await _ndt7Service.runDownloadTest(
      server,
      onProgress: (progress) {
        final speeds = List<double>.from(state.downloadSpeeds)
          ..add(progress.speed);
        emit(state.copyWith(
          currentDownloadSpeed: progress.speed,
          downloadSpeeds: speeds,
        ));
      },
    );

    emit(state.copyWith(
      currentDownloadSpeed: downloadResult.throughputMbps ?? 0,
      downloadSpeedTestDone: true,
    ));

    emit(state.copyWith(
      currentUploadSpeed: 0,
      uploadSpeeds: [0],
    ));

    final uploadResult = await _ndt7Service.runUploadTest(
      server,
      onProgress: (progress) {
        final speeds = List<double>.from(state.uploadSpeeds)
          ..add(progress.speed);
        emit(state.copyWith(
          currentUploadSpeed: progress.speed,
          uploadSpeeds: speeds,
          isWarmingUp: progress.isWarmingUp,
        ));
      },
    );

    final latencyMs = downloadResult.minRTT ?? uploadResult.minRTT;
    final retransmissions =
        downloadResult.retransmissions ?? uploadResult.retransmissions;
    final retransmissionPercentage = downloadResult.retransmissionPercentage ??
        uploadResult.retransmissionPercentage;

    emit(state.copyWith(
      currentUploadSpeed: uploadResult.throughputMbps ?? 0,
      uploadSpeedTestDone: true,
      isWarmingUp: false,
      latencyMs: latencyMs,
      packetLossPercent: null,
      retransmissions: retransmissions,
      retransmissionPercentage: retransmissionPercentage,
      serverLocation: server.location != null
          ? '${server.location!.city ?? ''}, ${server.location!.country ?? ''}'
          : server.site,
    ));

    return Ndt7TestResult(
      downloadMbps: downloadResult.throughputMbps ?? 0,
      uploadMbps: uploadResult.throughputMbps ?? 0,
      latencyMs: latencyMs ?? 0,
      server: server,
      minRTT: latencyMs,
      retransmissions: retransmissions,
      retransmissionPercentage: retransmissionPercentage,
      timestamp: DateTime.now(),
    );
  }

  Future<void> _saveSpeedSnapshot(
    Emitter<SpeedTestState> emit,
    Ndt7TestResult result,
  ) async {
    final server = state.bestServers?.firstWhere(
      (s) => s.machine == result.server.machine,
      orElse: () => result.server,
    );

    await getIt<NetworkScoreRepository>().saveSpeedSnapshot(SpeedSnapshot(
      downloadMbps: result.downloadMbps,
      uploadMbps: result.uploadMbps,
      latencyMs: result.latencyMs,
      retransmissions: result.retransmissions,
      serverLocation: result.server.location?.city,
      testProvider: 'mlab',
      timestamp: DateTime.now(),
      ttlSeconds: server?.ttl,
      fetchedAt: DateTime.now(),
    ));

    getIt<NetworkScoreBloc>().add(const NetworkScoreEvent.refresh());
  }
}
