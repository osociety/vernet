import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vernet/providers/dark_theme_provider.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';

void main() {
  testWidgets('AdaptiveListTile renders ListTile on non-iOS platforms',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: AdaptiveListTile(
              title: Text('Hello'),
              subtitle: Text('Subtitle'),
              leading: Icon(Icons.add),
              trailing: Icon(Icons.chevron_right),
              platform: 'android',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Subtitle'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('AdaptiveListTile renders CupertinoListTile on iOS',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: AdaptiveListTile(
              title: Text('Hello'),
              subtitle: Text('Subtitle'),
              leading: Icon(Icons.add),
              trailing: Icon(Icons.chevron_right),
              platform: 'ios',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(CupertinoListTile), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Subtitle'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('AdaptiveListTile onTap and onLongPress are triggered',
      (tester) async {
    var tapped = false;
    var longPressed = false;
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: AdaptiveListTile(
              title: const Text('ActionMe'),
              platform: 'android',
              onTap: () {
                tapped = true;
              },
              onLongPress: () {
                longPressed = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('ActionMe'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);

    await tester.longPress(find.text('ActionMe'));
    await tester.pumpAndSettle();
    expect(longPressed, isTrue);
  });

  testWidgets('AdaptiveListTile respects dense and contentPadding',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: AdaptiveListTile(
              title: Text('Dense'),
              dense: true,
              contentPadding: EdgeInsets.all(20),
              platform: 'android',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final listTile = tester.widget<ListTile>(find.byType(ListTile));
    expect(listTile.dense, isTrue);
    expect(listTile.contentPadding, const EdgeInsets.all(20));
  });

  testWidgets('AdaptiveListTile long press works on iOS and macOS',
      (tester) async {
    for (final platform in ['ios', 'macos']) {
      var longPressed = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: AdaptiveListTile(
                title: const Text('CopyMe'),
                platform: platform,
                onLongPress: () {
                  longPressed++;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CupertinoListTile), findsOneWidget);

      await tester.longPress(find.text('CopyMe'));
      await tester.pumpAndSettle();
      expect(longPressed, 1, reason: 'long press was dropped on $platform');
    }
  });

  testWidgets('AdaptiveListTile keeps onTap separate from the long press',
      (tester) async {
    var tapped = 0;
    var longPressed = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: AdaptiveListTile(
              title: const Text('TapMe'),
              platform: 'ios',
              onTap: () {
                tapped++;
              },
              onLongPress: () {
                longPressed++;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('TapMe'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
    expect(longPressed, 0);
  });

  // The settings list mixes plain ListTiles with these tiles, and the Cupertino
  // branch used to sit 6px left of every Material row on the same page.
  testWidgets('Cupertino rows share the Material leading edge', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DarkThemeProvider>(
        create: (_) => DarkThemeProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AdaptiveListTile(
                  title: Text('WhatsNew'),
                  platform: 'ios',
                ),
                ListTile(title: Text('Theme')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Measured on the painted titles rather than on a padding constant, so a
    // change to either branch's defaults shows up as the misalignment users
    // see instead of a passing comparison against a number.
    expect(
      tester.getTopLeft(find.text('WhatsNew')).dx,
      tester.getTopLeft(find.text('Theme')).dx,
      reason: 'both branches must start on one edge',
    );
  });

  // CupertinoListTile clamps leading to a square sized for an icon, which
  // clipped the port number in the device detail scan results.
  testWidgets('leadingSize widens only the Cupertino leading box',
      (tester) async {
    Future<void> pump(double? leadingSize) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DarkThemeProvider>(
          create: (_) => DarkThemeProvider(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: AdaptiveListTile(
                  title: const Text('Service'),
                  // The style the device detail port rows hand to `leading`.
                  leading: Text(
                    '65535',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  leadingSize: leadingSize,
                  platform: 'ios',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // A box with room to spare paints the string at its natural width, in
    // whatever font the test binding loads, so the checks below compare against
    // that rather than against a guessed pixel budget.
    await pump(400);
    final naturalWidth = tester.getSize(find.text('65535')).width;
    expect(naturalWidth, greaterThan(28));

    await pump(null);
    expect(
      tester.getSize(find.text('65535')).width,
      28,
      reason: 'the icon-sized default box clips a five-digit port',
    );

    // The device detail port rows size the box from a TextPainter of the same
    // string, so a box this wide is the contract that stops the clipping.
    await pump(naturalWidth);
    expect(
      tester
          .widget<CupertinoListTile>(find.byType(CupertinoListTile))
          .leadingSize,
      naturalWidth,
    );
    expect(
      tester.getSize(find.text('65535')).width,
      naturalWidth,
      reason: 'the whole port number must be painted',
    );
  });
}
