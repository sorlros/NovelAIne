import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_palette.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../../screens/profile/settings_screen.dart';

class UserHeaderWidget extends ConsumerWidget {
  const UserHeaderWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    // Fetch actual user data from Provider/Riverpod
    final authState = ref.watch(authProvider);
    final storiesState = ref.watch(storiesProvider);

    final username = authState.value?.username ?? "Traveler";
    final avatarUrl =
        authState.value?.avatarUrl ??
        "https://api.dicebear.com/7.x/avataaars/png?seed=guest";

    final storiesCount = storiesState.when(
      data: (stories) => stories.length.toString(),
      loading: () => "...",
      error: (error, stackTrace) => "0",
    );

    final readingCount = storiesState.when(
      data: (stories) =>
          stories.where((s) => s.status == 'active').length.toString(),
      loading: () => "...",
      error: (error, stackTrace) => "0",
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
              border: Border.all(color: palette.accent, width: 2),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 80,
                  height: 80,
                  color: palette.surface,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 80,
                  height: 80,
                  color: palette.surface,
                  child: Icon(Icons.person, color: palette.faint, size: 40),
                ),
              ),
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
                    color: palette.text,
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
                      readingCount,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: palette.muted),
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
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: palette.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: palette.muted)),
      ],
    );
  }
}
