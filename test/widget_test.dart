import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aiface/app.dart';
import 'package:aiface/core/utils.dart';
import 'package:aiface/features/face/expression.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AIFaceApp()),
    );
    // The app shows a loading indicator first, then navigates
    await tester.pump(const Duration(seconds: 1));
    // Just verify no crash - the app renders something
    expect(tester.takeException(), isNull);
  });

  group('Expression parsing', () {
    test('parses expression tag', () {
      expect(
        AppUtils.parseExpression('[EXPRESSION:happy] Hello!'),
        'happy',
      );
    });

    test('returns neutral for no tag', () {
      expect(AppUtils.parseExpression('Hello!'), 'neutral');
    });

    test('removes expression tags', () {
      expect(
        AppUtils.removeExpressionTags('[EXPRESSION:happy] Hello!'),
        'Hello!',
      );
    });
  });

  group('Expression enum', () {
    test('converts string to expression', () {
      expect(expressionFromString('happy'), Expression.happy);
      expect(expressionFromString('thinking'), Expression.thinking);
      expect(expressionFromString('unknown'), Expression.neutral);
    });

    test('all expressions have pixel data', () {
      for (final expr in Expression.values) {
        final data = ExpressionData.getExpression(expr);
        expect(data.length, ExpressionData.size);
        expect(data[0].length, ExpressionData.size);
      }
    });
  });
}
