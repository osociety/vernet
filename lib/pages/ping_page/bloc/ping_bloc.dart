import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ping_event.dart';
part 'ping_state.dart';
part 'ping_bloc.freezed.dart';

class PingBloc extends Bloc<PingEvent, PingState> {
  PingBloc() : super(const PingState.initial()) {
    on<StartPing>(_startPing);
    on<StopPing>(_stopPing);
  }

  void _startPing(StartPing event, Emitter<PingState> emit) {}

  void _stopPing(StopPing event, Emitter<PingState> emit) {}
}
