/// Shape returned by `GET /me/plan`.
library;

import '../../core/constants.dart';

class PlanStatus {
  static const _freeLimits = {'story': 1, 'turn': 30, 'direct_input': 10};

  final bool premium;
  final Map<String, int> limits;
  final Map<String, int> used;

  const PlanStatus({
    required this.premium,
    required this.limits,
    required this.used,
  });

  /// What the app assumes when the plan is unknown or could not be fetched.
  static const free = PlanStatus(premium: false, limits: _freeLimits, used: {});

  factory PlanStatus.fromJson(Map<String, dynamic> json) {
    final premium = json['premium'] == true;
    return PlanStatus(
      premium: premium,
      limits: {..._freeLimits, ..._counts(json['limits'])},
      used: _counts(json['used']),
    );
  }

  static Map<String, int> _counts(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is num)
          entry.key.toString(): (entry.value as num).toInt(),
    };
  }

  /// How many more of [kind] (story, turn, direct_input) are allowed today.
  int remaining(String kind) {
    final left = (limits[kind] ?? 0) - (used[kind] ?? 0);
    return left < 0 ? 0 : left;
  }

  /// The pro model is for premium users only.
  bool locks(String modelId) => !premium && modelId == AppConstants.proLlmModel;
}
