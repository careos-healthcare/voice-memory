import 'package:go_router/go_router.dart';

import '../screens/account_screen.dart';
import '../screens/delete_account_screen.dart';
import '../screens/entry_detail_screen.dart';
import '../screens/export_screen.dart';
import '../screens/home_screen.dart';
import '../screens/journal_screen.dart';
import '../screens/memory_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/pricing_screen.dart';
import '../screens/record_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(path: '/record', builder: (context, state) => const RecordScreen()),
    GoRoute(
      path: '/journal',
      builder: (context, state) => const JournalScreen(),
    ),
    GoRoute(path: '/memory', builder: (context, state) => const MemoryScreen()),
    GoRoute(
      path: '/entry/:id',
      builder: (context, state) => EntryDetailScreen(
        entryId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(
      path: '/pricing',
      builder: (context, state) => const PricingScreen(),
    ),
    GoRoute(
      path: '/account',
      builder: (context, state) => const AccountScreen(),
    ),
    GoRoute(path: '/export', builder: (context, state) => const ExportScreen()),
    GoRoute(
      path: '/delete-account',
      builder: (context, state) => const DeleteAccountScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
