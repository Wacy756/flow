import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';

/// Shows the profile bottom sheet.
void showProfileSheet(BuildContext context, UserProfile profile) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProfileSheet(profile: profile),
  );
}

/// Avatar button to place in the app bar.
Widget profileAvatarButton(BuildContext context, UserProfile profile) {
  final initial = profile.fullName.isNotEmpty
      ? profile.fullName[0].toUpperCase()
      : '?';
  return Padding(
    padding: const EdgeInsets.only(right: 16),
    child: GestureDetector(
      onTap: () => showProfileSheet(context, profile),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppTheme.roleBg(profile.role),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------

class _ProfileSheet extends StatelessWidget {
  final UserProfile profile;
  const _ProfileSheet({required this.profile});

  @override
  Widget build(BuildContext context) {
    final initial = profile.fullName.isNotEmpty
        ? profile.fullName[0].toUpperCase()
        : '?';

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 12, 24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.roleBg(profile.role),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Name
          Text(
            profile.fullName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          if (profile.email != null) ...[
            const SizedBox(height: 3),
            Text(
              profile.email!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Role badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.roleBg(profile.role),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              profile.role.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),

          const SizedBox(height: 28),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Settings
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push(AppRoutes.settings);
              },
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Settings'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                minimumSize: const Size(double.infinity, 44),
                alignment: Alignment.centerLeft,
              ),
            ),
          ),

          const SizedBox(height: 4),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Sign out
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await supabase.auth.signOut();
                if (context.mounted) context.go(AppRoutes.landing);
              },
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textMuted,
                side: const BorderSide(color: AppTheme.border, width: 0.5),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
