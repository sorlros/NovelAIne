import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants.dart';
import 'package:frontend/data/models/plan_models.dart';
import 'package:frontend/data/models/play_models.dart';
import 'package:frontend/data/services/api_service.dart';
import 'package:frontend/presentation/widgets/play_choices_panel.dart';

void main() {
  group('PlanStatus', () {
    test('reads every field', () {
      final plan = PlanStatus.fromJson({
        'plan': 'premium',
        'premium': true,
        'limits': {'story': 10, 'turn': 300, 'direct_input': 50},
        'used': {'story': 2, 'turn': 295, 'direct_input': 0},
      });
      expect(plan.premium, isTrue);
      expect(plan.remaining('story'), 8);
      expect(plan.remaining('turn'), 5);
      expect(plan.remaining('direct_input'), 50);
    });

    test('missing fields mean free with the free limits', () {
      final plan = PlanStatus.fromJson({});
      expect(plan.premium, isFalse);
      expect(plan.remaining('story'), 1);
      expect(plan.remaining('turn'), 30);
      expect(plan.remaining('direct_input'), 10);
    });

    test('remaining never goes below zero', () {
      final plan = PlanStatus.fromJson({
        'limits': {'turn': 30},
        'used': {'turn': 35},
      });
      expect(plan.remaining('turn'), 0);
    });

    test('free constant is not premium', () {
      expect(PlanStatus.free.premium, isFalse);
    });

    test('only free users are locked out of the pro model', () {
      expect(PlanStatus.free.locks(AppConstants.proLlmModel), isTrue);
      expect(PlanStatus.free.locks(AppConstants.defaultLlmModel), isFalse);
      final premium = PlanStatus.fromJson({'premium': true});
      expect(premium.locks(AppConstants.proLlmModel), isFalse);
    });
  });

  group('ApiService.parsePlan', () {
    test('a failed response gives free', () {
      expect(ApiService.parsePlan(500, '{}').premium, isFalse);
      expect(ApiService.parsePlan(200, 'not json').premium, isFalse);
      expect(ApiService.parsePlan(401, '{"detail":"x"}').premium, isFalse);
    });

    test('reads the data of a successful response', () {
      final plan = ApiService.parsePlan(
        200,
        '{"success":true,"data":{"plan":"premium","premium":true}}',
      );
      expect(plan.premium, isTrue);
    });
  });

  testWidgets('panel shows the remaining scenes only when given', (
    tester,
  ) async {
    Future<void> pump(int? remaining) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayChoicesPanel(
            status: PlayStatus.fromJson({
              'choices': [
                {'id': 'c1', 'label': '문을 연다'},
              ],
            }),
            busy: false,
            loadFailed: false,
            remainingTurns: remaining,
            onChoose: (_) {},
            onWrite: (_) {},
            onUndo: () {},
            onReload: () {},
          ),
        ),
      ),
    );

    await pump(12);
    expect(find.text('오늘 남은 장면 12'), findsOneWidget);
    await pump(null);
    expect(find.textContaining('오늘 남은 장면'), findsNothing);
  });
}
