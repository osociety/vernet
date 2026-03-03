import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/pages/ping_page/bloc/ping_bloc.dart';

void main() {
  group('PingBloc', () {
    test('initial state is PingState.initial', () {
      final bloc = PingBloc();

      expect(bloc.state, const PingState.initial());
    });

    test('handles StartPing and StopPing events without crashing', () async {
      final bloc = PingBloc();

      bloc.add(const PingEvent.startPing());
      bloc.add(const PingEvent.stopPing());

      // Close should complete without throwing.
      await bloc.close();
    });
  });
}

