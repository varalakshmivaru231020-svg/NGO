import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/donors/presentation/donors_screen.dart';
import '../../features/donors/presentation/donor_detail_screen.dart';
import '../../features/donors/presentation/add_donor_screen.dart';
import '../../features/donors/presentation/import_donors_screen.dart';
import '../../features/donors/presentation/donor_categories_screen.dart';
import '../../features/donors/presentation/category_donors_screen.dart';
import '../../features/donations/presentation/donations_screen.dart';
import '../../features/donations/presentation/add_donation_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/expenses/presentation/add_expense_screen.dart';
import '../../features/students/presentation/students_screen.dart';
import '../../features/students/presentation/student_detail_screen.dart';
import '../../features/students/presentation/add_student_screen.dart';
import '../../features/staff/presentation/staff_screen.dart';
import '../../features/staff/presentation/staff_detail_screen.dart';
import '../../features/staff/presentation/add_staff_screen.dart';
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
import '../../features/settings/presentation/student_masters_screen.dart';
import '../../features/roles/presentation/roles_screen.dart';
import '../../features/approvals/presentation/approvals_screen.dart';
import '../auth/session.dart';
import '../shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authChanges,
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
          GoRoute(path: '/donors/import',     builder: (ctx, state) => const ImportDonorsScreen()),
          GoRoute(path: '/donors/categories', builder: (ctx, state) => const DonorCategoriesScreen()),
          GoRoute(path: '/donors/categories/:id', builder: (ctx, state) => CategoryDonorsScreen(
            categoryId: state.pathParameters['id']!,
            category: state.extra as DonorCategory?,
          )),
          GoRoute(path: '/donors/:id/edit', builder: (ctx, state) => AddDonorScreen(donorId: state.pathParameters['id']!)),
          GoRoute(path: '/donors/:id',      builder: (ctx, state) => DonorDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(path: '/donations',       builder: (ctx, state) => const DonationsScreen()),
          GoRoute(path: '/donations/new',   builder: (ctx, state) => const AddDonationScreen()),
          GoRoute(path: '/donations/:id/edit', builder: (ctx, state) => AddDonationScreen(donationId: state.pathParameters['id']!)),
          GoRoute(path: '/expenses',        builder: (ctx, state) => const ExpensesScreen()),
          GoRoute(path: '/expenses/new',    builder: (ctx, state) => const AddExpenseScreen()),
          GoRoute(path: '/expenses/:id/edit', builder: (ctx, state) => AddExpenseScreen(expenseId: state.pathParameters['id']!)),
          GoRoute(path: '/students',        builder: (ctx, state) => const StudentsScreen()),
          GoRoute(path: '/students/new',    builder: (ctx, state) => const AddStudentScreen()),
          GoRoute(path: '/students/:id',    builder: (ctx, state) => StudentDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(path: '/staff',           builder: (ctx, state) => const StaffScreen()),
          GoRoute(path: '/staff/new',       builder: (ctx, state) => const AddStaffScreen()),
          GoRoute(path: '/staff/:id/edit',  builder: (ctx, state) => AddStaffScreen(staffId: state.pathParameters['id']!)),
          GoRoute(path: '/staff/:id',       builder: (ctx, state) => StaffDetailScreen(
            id: state.pathParameters['id']!,
            initialTab: state.uri.queryParameters['tab'] == 'salary' ? 1 : 0,
          )),
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
          GoRoute(path: '/settings/student-categories', builder: (ctx, state) => const StudentCategoriesScreen()),
          GoRoute(path: '/settings/student-statuses',   builder: (ctx, state) => const StudentStatusesScreen()),
          GoRoute(path: '/settings/education-levels',   builder: (ctx, state) => const EducationLevelsScreen()),
          GoRoute(path: '/settings/document-types',     builder: (ctx, state) => const DocumentTypesScreen()),
          GoRoute(path: '/settings/expense-categories', builder: (ctx, state) => const ExpenseCategoriesScreen()),
          GoRoute(path: '/settings/export-data',     builder: (ctx, state) => const ExportDataScreen()),
          GoRoute(path: '/settings/backup-sync',     builder: (ctx, state) => const BackupSyncScreen()),
          GoRoute(path: '/settings/privacy-policy',  builder: (ctx, state) => const PrivacyPolicyScreen()),
          GoRoute(path: '/settings/terms-of-service',builder: (ctx, state) => const TermsOfServiceScreen()),
          GoRoute(path: '/settings/about-us',        builder: (ctx, state) => const AboutUsScreen()),
          GoRoute(path: '/settings/razorpay',        builder: (ctx, state) => const RazorpayCredentialsScreen()),
          GoRoute(path: '/settings/whatsapp',        builder: (ctx, state) => const WhatsappSettingsScreen()),
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
