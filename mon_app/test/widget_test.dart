import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_app/app.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_platform_interface/webview_platform_interface.dart';

class FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) {
    return FakePlatformWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) {
    return FakePlatformWebViewWidget(params);
  }
}

class FakePlatformWebViewController extends PlatformWebViewController {
  FakePlatformWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
}

class FakePlatformWebViewWidget extends PlatformWebViewWidget {
  FakePlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  setUp(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  testWidgets('affiche le site web directement si présent, ou les podcasts/news sinon', (tester) async {
    await tester.pumpWidget(const RadioCampusApp());
    await tester.pumpAndSettle();

    // 1. Radio Campus Paris a un site web : affiche le Direct et la webview (pas de section podcasts/news)
    await tester.scrollUntilVisible(find.text('Radio Campus Paris'), 300);
    await tester.tap(find.text('Radio Campus Paris'));
    await tester.pumpAndSettle();

    expect(find.text('Direct'), findsOneWidget);
    expect(find.text('Podcasts'), findsNothing);
    expect(find.text('News et agenda'), findsNothing);

    // Retour à la liste
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 2. Radio Cortes n'a pas de site web (elle est plus haut dans la liste)
    await tester.scrollUntilVisible(find.text('Radio Cortes'), -300);
    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Radio Cortes'));
    await tester.pumpAndSettle();

    expect(find.text('Podcasts'), findsOneWidget);
    expect(find.text('News et agenda'), findsOneWidget);
  });
}
