import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:speed_test_dart/classes/classes.dart';
import 'package:speed_test_dart/speed_test_dart.dart';

part 'isp_page_event.dart';
part 'isp_page_state.dart';
part 'isp_page_bloc.freezed.dart';

@injectable
class IspPageBloc extends Bloc<IspPageEvent, IspPageState> {
  IspPageBloc() : super(const _Initial()) {
    on<_Started>(_started);
    on<_Completed>(_completed);
    on<_Failed>(_failed);
  }

  final tester = SpeedTestDart();

  Future<void> _started(_Started event, Emitter<IspPageState> emit) async {
    emit(const _LoadInProgress());
    try {
      final result =
          await event.tester.getBestServers(servers: event.settings.servers);
      result.sort((a, b) => a.latency.compareTo(b.latency));
      add(const IspPageEvent.completed());
      emit(IspPageState.loadSuccess(result));
    } catch (e) {
      add(const IspPageEvent.failed());
      emit(const IspPageState.loadFailure());
    }
  }

  Future<void> _completed(_Completed event, Emitter<IspPageState> emit) async {}

  Future<void> _failed(_Failed event, Emitter<IspPageState> emit) async {}
}
