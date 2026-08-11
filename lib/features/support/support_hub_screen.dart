import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

class SupportHubScreen extends StatelessWidget {
  const SupportHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'RAISE A REQUEST',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tile(
                icon: Icons.event_available_outlined,
                label: 'Leave',
                onTap: () => context.push('/profile/support/requests/new?type=leave'),
              ),
              _Tile(
                icon: Icons.medical_services_outlined,
                label: 'Sick / Accident',
                onTap: () =>
                    context.push('/profile/support/requests/new?type=sick_leave'),
              ),
              _Tile(
                icon: Icons.inventory_2_outlined,
                label: 'Asset',
                onTap: () => context.push('/profile/support/requests/new?type=asset'),
              ),
              _Tile(
                icon: Icons.local_gas_station_outlined,
                label: 'Fuel',
                onTap: () => context.push('/profile/support/requests/new?type=fuel'),
              ),
              _Tile(
                icon: Icons.description_outlined,
                label: 'Document',
                onTap: () =>
                    context.push('/profile/support/requests/new?type=document'),
              ),
              _Tile(
                icon: Icons.report_problem_outlined,
                label: 'Complaint',
                onTap: () =>
                    context.push('/profile/support/requests/new?type=complaint'),
              ),
              _Tile(
                icon: Icons.payments_outlined,
                label: 'Salary justification',
                onTap: () => context
                    .push('/profile/support/requests/new?type=salary_justification'),
              ),
              _Tile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Loan / Advance',
                onTap: () => context.push('/profile/support/requests/new?type=loan'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'VISIT US',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _WideTile(
            icon: Icons.apartment_outlined,
            title: 'Schedule a visit',
            subtitle: 'Book a slot at Central Tower',
            onTap: () => context.push('/profile/support/visits/book'),
          ),
          const SizedBox(height: 20),
          Text(
            'YOUR ACTIVITY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _WideTile(
            icon: Icons.priority_high_rounded,
            title: 'Action required',
            subtitle: 'Clarifications and acknowledgements',
            onTap: () => context.push('/profile/support/action-required'),
          ),
          const SizedBox(height: 8),
          _WideTile(
            icon: Icons.inbox_outlined,
            title: 'My requests',
            subtitle: 'Track RCM status and clarifications',
            onTap: () => context.push('/profile/support/requests'),
          ),
          const SizedBox(height: 8),
          _WideTile(
            icon: Icons.draw_outlined,
            title: 'Documents to sign',
            subtitle: 'Pending signatures and signed proofs',
            onTap: () => context.push('/profile/support/sign'),
          ),
          const SizedBox(height: 8),
          _WideTile(
            icon: Icons.event_note_outlined,
            title: 'Appointments',
            subtitle: 'Scheduled meetings at Central Tower',
            onTap: () => context.push('/profile/support/appointments'),
          ),
          const SizedBox(height: 8),
          _WideTile(
            icon: Icons.qr_code_2_outlined,
            title: 'My visits',
            subtitle: 'Upcoming and past bookings',
            onTap: () => context.push('/profile/support/visits'),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 40) / 2,
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.primaryBlue),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WideTile extends StatelessWidget {
  const _WideTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: AppColors.primaryBlue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
