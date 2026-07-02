import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/donors/presentation/donors_screen.dart';
import '../../features/donors/presentation/donor_detail_screen.dart';
import '../../features/donors/presentation/add_donor_screen.dart';
import '../../features/donors/presentation/donor_categories_screen.dart';
import '../../features/donations/presentation/donations_screen.dart';
import '../../features/donations/presentation/add_donation_screen.dart';
import '../../features/students/presentation/students_screen.dart';
import '../../features/students/presentation/student_detail_screen.dart';
import '../../features/students/presentation/add_student_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/offices/presentation/offices_screen.dart';
import '../../features/payment_links/presentation/payment_links_screen.dart';
import '../../features/reminders/presentation/reminders_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/tracker/presentation/donation_tracker_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/achievements/presentation/achievements_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/settings_sub_screens.dart';
import '../../features/roles/presentation/roles_screen.dart';
import '../../features/approvals/presentation/approvals_screen.dart';
import '../auth/session.dart';
import '../shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    // Signed-out users can only see the login screen — never an admin view.
    redirect: (ctx, state) {
      final onLogin = state.matchedLocation == '/login';
      if (!isLoggedIn && !onLogin) return '/login';
      if (isLoggedIn && onLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
      ShellRoute(
        builder: (ctx, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard',       builder: (ctx, state) => const DashboardScreen()),
          GoRoute(path: '/donors',            builder: (ctx, state) => const DonorsScreen()),
          GoRoute(path: '/donors/new',        builder: (ctx, state) => const AddDonorScreen()),
          GoRoute(path: '/donors/categories', builder: (ctx, state) => const DonorCategoriesScreen()),
          GoRoute(path: '/donors/:id',      builder: (ctx, state) => DonorDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(path: '/donations',       builder: (ctx, state) => const DonationsScreen()),
          GoRoute(path: '/donations/new',   builder: (ctx, state) => const AddDonationScreen()),
          GoRoute(path: '/students',        builder: (ctx, state) => const StudentsScreen()),
          GoRoute(path: '/students/new',    builder: (ctx, state) => const AddStudentScreen()),
          GoRoute(path: '/students/:id',    builder: (ctx, state) => StudentDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(path: '/more',            builder: (ctx, state) => const MoreScreen()),
          GoRoute(path: '/offices',         builder: (ctx, state) => const OfficesScreen()),
          GoRoute(path: '/payment-links',   builder: (ctx, state) => const PaymentLinksScreen()),
          GoRoute(path: '/reminders',       builder: (ctx, state) => const RemindersScreen()),
          GoRoute(path: '/notifications',   builder: (ctx, state) => const NotificationsScreen()),
          GoRoute(path: '/donation-tracker',builder: (ctx, state) => const DonationTrackerScreen()),
          GoRoute(path: '/reports',         builder: (ctx, state) => const ReportsScreen()),
          GoRoute(path: '/achievements',    builder: (ctx, state) => const AchievementsScreen()),
          GoRoute(path: '/settings',        builder: (ctx, state) => const SettingsScreen()),
          // Settings sub-screens
          GoRoute(path: '/settings/edit-profile',    builder: (ctx, state) => const EditProfileScreen()),
          GoRoute(path: '/settings/security-pin',    builder: (ctx, state) => const SecurityPinScreen()),
          GoRoute(path: '/settings/linked-devices',  builder: (ctx, state) => const LinkedDevicesScreen()),
          GoRoute(path: '/settings/team-members',    builder: (ctx, state) => const TeamMembersScreen()),
          GoRoute(path: '/settings/donation-types',  builder: (ctx, state) => const DonationTypesScreen()),
          GoRoute(path: '/settings/export-data',     builder: (ctx, state) => const ExportDataScreen()),
          GoRoute(path: '/settings/backup-sync',     builder: (ctx, state) => const BackupSyncScreen()),
          GoRoute(path: '/settings/privacy-policy',  builder: (ctx, state) => const PrivacyPolicyScreen()),
          GoRoute(path: '/settings/terms-of-service',builder: (ctx, state) => const TermsOfServiceScreen()),
          GoRoute(path: '/settings/about-us',        builder: (ctx, state) => const AboutUsScreen()),
          GoRoute(path: '/settings/server-url',      builder: (ctx, state) => const ServerUrlScreen()),
          GoRoute(path: '/settings/razorpay',        builder: (ctx, state) => const RazorpayCredentialsScreen()),
          GoRoute(path: '/settings/centres',         builder: (ctx, state) => const ManageCentresScreen()),
          GoRoute(path: '/settings/manage-roles',    builder: (ctx, state) => const ManageRolesScreen()),
          GoRoute(path: '/settings/admin-panel',     builder: (ctx, state) => const AdminPanelScreen()),
          GoRoute(path: '/centres',         builder: (ctx, state) => const ManageCentresScreen()),
          GoRoute(path: '/roles',           builder: (ctx, state) => const RolesScreen()),
          GoRoute(path: '/approvals',       builder: (ctx, state) => const ApprovalsScreen()),
          GoRoute(path: '/help',            builder: (ctx, state) => const HelpSupportScreen()),
        ],
      ),
    ],
  );
});
