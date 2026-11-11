import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/plan_models.dart';
import '../../data/services/api_service.dart';
import 'auth_provider.dart';

/// The signed-in user's plan; refetched whenever the user changes.
final planProvider = FutureProvider<PlanStatus>((ref) async {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return PlanStatus.free;
  return ApiService().fetchPlan();
});

/// The plan as known right now: free until the first fetch finishes.
final currentPlanProvider = Provider<PlanStatus>(
  (ref) => ref.watch(planProvider).valueOrNull ?? PlanStatus.free,
);
