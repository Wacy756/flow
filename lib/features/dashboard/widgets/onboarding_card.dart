import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

// ============================================================
// Onboarding / empty-state cards shown when a user has no data
// yet.  Each role gets a tailored welcome card with a step
// guide and a primary CTA.
// ============================================================

// ---------------------------------------------------------------------------
// Landlord onboarding
// ---------------------------------------------------------------------------

class LandlordOnboardingCard extends StatelessWidget {
  final VoidCallback onAddProperty;
  const LandlordOnboardingCard({super.key, required this.onAddProperty});

  @override
  Widget build(BuildContext context) {
    return _OnboardingShell(
      accentColor: AppTheme.green,
      accentBg: AppTheme.greenBg,
      headerIcon: Icons.home_work_outlined,
      headline: 'Welcome to Flow',
      subtitle: 'Get your first property set up in minutes.',
      steps: const [
        _Step(
          icon: Icons.add_home_outlined,
          title: 'Add a property',
          body: 'Create a tenancy record with address and rent details.',
        ),
        _Step(
          icon: Icons.person_add_alt_1_outlined,
          title: 'Invite your tenant',
          body: 'Send an in-app invite — tenants join with one tap.',
        ),
        _Step(
          icon: Icons.verified_outlined,
          title: 'Manage compliance',
          body: 'Upload gas, electrical and EPC certificates to stay legal.',
        ),
      ],
      ctaLabel: 'Add Your First Property',
      onCta: onAddProperty,
      ctaColor: AppTheme.green,
    );
  }
}

// ---------------------------------------------------------------------------
// Agent onboarding
// ---------------------------------------------------------------------------

class AgentOnboardingCard extends StatelessWidget {
  final VoidCallback onAddProperty;
  const AgentOnboardingCard({super.key, required this.onAddProperty});

  @override
  Widget build(BuildContext context) {
    return _OnboardingShell(
      accentColor: AppTheme.agentGlow,
      accentBg: AppTheme.agentBg,
      headerIcon: Icons.business_center_outlined,
      headline: 'Build Your Portfolio',
      subtitle: 'Start managing client properties with Flow.',
      steps: const [
        _Step(
          icon: Icons.add_business_outlined,
          title: 'Add a client property',
          body: 'Create tenancy records on behalf of your landlord clients.',
        ),
        _Step(
          icon: Icons.people_outline,
          title: 'Manage tenancies',
          body: 'Invite tenants, track rent and handle move-in / move-out.',
        ),
        _Step(
          icon: Icons.construction_outlined,
          title: 'Coordinate maintenance',
          body: 'Log incidents and dispatch verified contractors instantly.',
        ),
      ],
      ctaLabel: 'Add First Property',
      onCta: onAddProperty,
      ctaColor: AppTheme.agentGlow,
    );
  }
}

// ---------------------------------------------------------------------------
// Tenant onboarding
// ---------------------------------------------------------------------------

class TenantOnboardingCard extends StatelessWidget {
  const TenantOnboardingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + headline row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.greenBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    color: AppTheme.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Waiting for your invite',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Your landlord will send you an invitation.',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const _Divider(),
          const SizedBox(height: 16),

          // What happens next
          const Text(
            'What happens next',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),

          _tenantStep(
            icon: Icons.home_outlined,
            title: 'Landlord adds your property',
            body: 'They create a tenancy record with your address details.',
          ),
          const SizedBox(height: 10),
          _tenantStep(
            icon: Icons.notifications_outlined,
            title: 'You receive a notification',
            body: 'Accept the invite to link yourself to the tenancy.',
          ),
          const SizedBox(height: 10),
          _tenantStep(
            icon: Icons.build_outlined,
            title: 'Report issues & track compliance',
            body: 'Raise maintenance requests and view safety certificates.',
          ),

          const SizedBox(height: 20),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.greenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, size: 14, color: AppTheme.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Make sure your landlord uses the same email address you registered with.',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.green,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tenantStep({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.bgPage,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Icon(icon, size: 15, color: AppTheme.textMuted),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                body,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Contractor "no jobs" empty state (available / active variants)
// ---------------------------------------------------------------------------

class ContractorNoJobsCard extends StatelessWidget {
  /// true = shown on "Available" tab, false = shown on "My Jobs" tab
  final bool isAvailable;
  final VoidCallback? onSetupProfile;

  const ContractorNoJobsCard({
    super.key,
    required this.isAvailable,
    this.onSetupProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.contractorBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isAvailable
                  ? Icons.search_outlined
                  : Icons.work_history_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isAvailable ? 'No jobs available yet' : 'No active jobs',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAvailable
                ? 'Jobs matching your service area will appear here.'
                : 'Jobs you\'ve accepted will appear here.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),

          if (isAvailable && onSetupProfile != null) ...[
            const SizedBox(height: 16),
            const _Divider(),
            const SizedBox(height: 14),
            const Text(
              'Not seeing jobs?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            _hintRow(
              icon: Icons.map_outlined,
              text: 'Add service areas so landlords in your region can match you.',
            ),
            const SizedBox(height: 6),
            _hintRow(
              icon: Icons.verified_outlined,
              text: 'Upload credentials to unlock more job types.',
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSetupProfile,
                icon: const Icon(Icons.tune_outlined, size: 15),
                label: const Text('Update Service Areas & Credentials'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.contractorGlow,
                  side: const BorderSide(
                      color: AppTheme.contractorGlow, width: 1.5),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _hintRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared shell widget used by Landlord + Agent onboarding cards
// ---------------------------------------------------------------------------

class _OnboardingShell extends StatelessWidget {
  final Color accentColor;
  final Color accentBg;
  final IconData headerIcon;
  final String headline;
  final String subtitle;
  final List<_Step> steps;
  final String ctaLabel;
  final VoidCallback onCta;
  final Color ctaColor;

  const _OnboardingShell({
    required this.accentColor,
    required this.accentBg,
    required this.headerIcon,
    required this.headline,
    required this.subtitle,
    required this.steps,
    required this.ctaLabel,
    required this.onCta,
    required this.ctaColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(headerIcon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const _Divider(),
          const SizedBox(height: 16),

          // Step list
          const Text(
            'HOW IT WORKS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          ...steps.asMap().entries.map((e) => Padding(
                padding: EdgeInsets.only(
                    bottom: e.key < steps.length - 1 ? 12 : 0),
                child: _StepRow(
                  step: e.value,
                  number: e.key + 1,
                  accentColor: accentColor,
                  accentBg: accentBg,
                ),
              )),

          const SizedBox(height: 20),

          // CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCta,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: Text(
                ctaLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ctaColor,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

class _Step {
  final IconData icon;
  final String title;
  final String body;
  const _Step(
      {required this.icon, required this.title, required this.body});
}

class _StepRow extends StatelessWidget {
  final _Step step;
  final int number;
  final Color accentColor;
  final Color accentBg;

  const _StepRow({
    required this.step,
    required this.number,
    required this.accentColor,
    required this.accentBg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number bubble
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: accentBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Icon
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.bgPage,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Icon(step.icon, size: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 10),
        // Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                step.body,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppTheme.border,
    );
  }
}
