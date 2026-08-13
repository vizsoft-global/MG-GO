import 'dart:async';

import 'package:dpd_userapp/core/notifications/notification_media_repository.dart';
import 'package:dpd_userapp/features/notifications/widgets/notification_hero_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('resolve runs once when the parent rebuilds', (tester) async {
    var calls = 0;
    final completer = Completer<NotificationMediaReadUrl?>();

    await tester.pumpWidget(
      _Host(
        child: NotificationHeroBanner(
          resolve: () {
            calls += 1;
            return completer.future;
          },
          imageBuilder: (url) => Text(url),
        ),
      ),
    );

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.text('rebuild'));
    await tester.pump();

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('keeps the banner after load instead of returning to the spinner', (
    tester,
  ) async {
    final completer = Completer<NotificationMediaReadUrl?>();

    await tester.pumpWidget(
      _Host(
        child: NotificationHeroBanner(
          resolve: () => completer.future,
          imageBuilder: (url) => Text(url),
        ),
      ),
    );

    completer.complete(
      const NotificationMediaReadUrl(
        readUrl: 'https://cdn.example/banner.jpg',
        role: NotificationMediaRole.banner,
      ),
    );
    await tester.pump();

    expect(find.text('https://cdn.example/banner.jpg'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('rebuild'));
    await tester.pump();

    expect(find.text('https://cdn.example/banner.jpg'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

class _Host extends StatefulWidget {
  const _Host({required this.child});

  final Widget child;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextButton(
              onPressed: () => setState(() {}),
              child: const Text('rebuild'),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}
