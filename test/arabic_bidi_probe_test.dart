import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the composite strings that mix a Latin reference code with Arabic
/// text, so the bidi ordering can be read off a real render instead of being
/// reasoned about. Ordering is a property of the Unicode bidi algorithm, not of
/// the typeface, so a substitute Arabic-capable system font is enough here;
/// line-break and overflow behaviour is font-specific and is not covered.
const _strings = <String, String>{
  'my_requests subtitle': 'RCM-0001 · 9 أغسطس 2026',
  'supportCodeWithType': 'SIG-0142 · اتفاقية السكن',
  'esign captured-with': 'أحمد خان · EMP-2048 · 3 أغسطس 2026, 13:52',
  'visit ticket code': 'VIS-99001 · مركز الاتصال',
  'code inside a sentence': 'تم استلام طلبك RCM-0001 بنجاح.',
  'clarification reason': 'بانتظار التوضيح · مدير التشغيل',
};

Future<void> _loadArabicFont() async {
  const candidates = [
    r'C:\Windows\Fonts\segoeui.ttf',
    r'C:\Windows\Fonts\tahoma.ttf',
    r'C:\Windows\Fonts\arial.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final loader = FontLoader('BidiProbe')
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
    return;
  }
  fail('no Arabic-capable system font found');
}

void main() {
  testWidgets('rtl composite strings', (tester) async {
    await _loadArabicFont();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(393, 420);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'BidiProbe'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in _strings.entries) ...[
                    Text(
                      entry.key,
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                      textDirection: TextDirection.ltr,
                    ),
                    Text(entry.value, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/arabic_bidi_probe.png'),
    );
  });
}
