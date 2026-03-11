import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../../settings/settings_screen.dart';

class UserHeaderWidget extends ConsumerWidget {
  const UserHeaderWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch actual user data from Provider/Riverpod
    final authState = ref.watch(authProvider);
    final storiesState = ref.watch(storiesProvider);

    final username = authState.value?.username ?? "Traveler";
    final avatarUrl =
        authState.value?.avatarUrl ?? "https://i.pravatar.cc/150?u=guest";
    final storiesCount = storiesState.when(
      data: (stories) => stories.length.toString(),
      loading: () => "...",
      error: (_, __) => "0",
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF7C3AED),
                width: 2,
              ), // Purple border
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(avatarUrl),
              backgroundColor: const Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _buildStatItem(
                      context,
                      AppLocalizations.of(context)!.createdStories,
                      storiesCount,
                    ),
                    _buildStatItem(
                      context,
                      AppLocalizations.of(context)!.reading,
                      "2",
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white54),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }
}
