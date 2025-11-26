import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logistics_toolkit/providers/chat_provider.dart';
import 'package:logistics_toolkit/services/gemini_service.dart';
import 'package:logistics_toolkit/widgets/chat_screen.dart';
import 'package:logistics_toolkit/widgets/floating_chat_control.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
// For Styling the page
import 'package:logistics_toolkit/config/theme.dart';
import 'package:provider/provider.dart';
// Services
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logistics_toolkit/features/auth/services/supabase_service.dart';
// Pages
import 'package:logistics_toolkit/features/auth/presentation/screens/dashboard_router.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/role_selection_page.dart';
import 'features/auth/utils/user_role.dart';
import 'features/disable/unable_account_page.dart';
// Localization
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('supabaseUrl', dotenv.env['SUPABASE_URL']!);
  await prefs.setString('supabaseAnonKey', dotenv.env['SUPABASE_ANON_KEY']!);

  OneSignal.initialize(dotenv.env['ONESIGNAL_APP_ID']!);
  OneSignal.Notifications.requestPermission(true);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
        child: ChangeNotifierProvider(
        create:  (_) => ThemeNotifier(),
        child: const MyApp(),
      )
      ),
  );
}

// Supabase client instance
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, notifier, child) {
        return MultiProvider(providers: [
          ChangeNotifierProvider(create: (_) =>
          ChatProvider(gemini: GeminiService(), supabase: supabase))
        ],

         child:  MaterialApp(
          title: 'Logistics Toolkit',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: notifier.themeMode, // <-- Switches theme
           home: Builder(builder: (context) {
             return Stack(
               children: [
                 const RootPage(),

                 // ye yhan add kr dia hai home me
                 FloatingChatControl(
                   onOpenChat: () {
                     Navigator.of(context).push(
                       MaterialPageRoute(
                         builder: (_) => ChatScreen(
                           onNavigate: (s) {
                             Navigator.of(context).pushNamed('/$s');
                           },
                         ),
                       ),
                     );
                   },
                   listening: false,


                 )
               ],
             );
           }
           ),
          debugShowCheckedModeBanner: false,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
        )
        );
      },
    );
  }
}

// Root page for redirecting users
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool _loading = true;
  Widget? _home;
  late StreamSubscription<AuthState> _authStateSubscription;
  Timer? _authCheckTimer;
  int _loginPageCheckCount = 0;

  @override
  void initState() {
    super.initState();
    _checkSession();
    _setupAuthStateListener();
    _startPeriodicAuthCheck();
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    _authCheckTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicAuthCheck() {
    _authCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (
        timer,
        ) {
      final currentUser = supabase.auth.currentUser;
      if (_home is LoginPage) {
        _loginPageCheckCount++;
      } else {
        _loginPageCheckCount = 0;
      }
      bool shouldLog =
          timer.tick % 20 == 0 ||
              (_loginPageCheckCount > 0 && _loginPageCheckCount % 6 == 0);
      if (shouldLog) {
        print(
          '🔄 Periodic auth check #${timer.tick} - User: ${currentUser?.email}',
        );
        print('🔄 Current home widget: ${_home.runtimeType}');
        if (_loginPageCheckCount > 0) {
          print(
            '🔄 Login page check count: ${_loginPageCheckCount} (${_loginPageCheckCount * 0.5}s on login)',
          );
        }
      }

      if (currentUser != null &&
          (_home is LoginPage ||
              _home.runtimeType.toString().contains('ProfileSetupPage'))) {
        print(
          '🔄 ⚡ OAUTH CALLBACK DETECTED: Found authenticated user on ${_home.runtimeType}',
        );
        print('🔄 ⚡ User: ${currentUser.email} (ID: ${currentUser.id})');
        print('🔄 ⚡ Provider: ${currentUser.appMetadata['provider']}');
        print('🔄 ⚡ Login page duration: ${_loginPageCheckCount * 0.5}s');
        print('🔄 ⚡ Immediately handling auth state to redirect user');
        _handleAuthStateChange(currentUser);
        if (_home is LoginPage) {
          timer.cancel();
          _loginPageCheckCount = 0;
          print(
            '🔄 ⚡ Periodic check timer cancelled - user redirected from login',
          );
        }
      }
    });
  }

  void _setupAuthStateListener() {
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      print('🔐 Auth State Change: $event');
      print('🔐 Session User: ${session?.user.email}');
      print('🔐 Current home widget: ${_home.runtimeType}');
      if (event == AuthChangeEvent.signedIn && session?.user != null) {
        print('🔐 Processing signedIn event for user: ${session!.user.email}');
        print('🔐 User providers: ${session.user.appMetadata['providers']}');
        _handleAuthStateChange(session.user);
      }
      else if (event == AuthChangeEvent.tokenRefreshed &&
          session?.user != null) {
        print(
          '🔐 Processing tokenRefreshed event for user: ${session!.user.email}',
        );
        _handleAuthStateChange(session.user);
      } else if (event == AuthChangeEvent.signedOut) {
        print('🔐 User signed out, redirecting to login');
        _redirectToLogin();
      } else {
        print('🔐 Unhandled auth event: $event');
      }
    });
  }

  Future<void> _handleAuthStateChange(User user) async {
    try {
      print('🔍 ===== HANDLING AUTH STATE CHANGE =====');
      print('🔍 User: ${user.email} (ID: ${user.id})');
      print('🔍 User created at: ${user.createdAt}');
      print('🔍 Authentication method: ${user.appMetadata['provider']}');
      print('🔍 Querying user_profiles table for user_id: ${user.id}');

      final userProfile = await supabase
          .from('user_profiles')
          .select(
        'role, account_disable, profile_completed, name, custom_user_id, user_id, email, mobile_number, profile_picture',
      )
          .eq('user_id', user.id)
          .maybeSingle();

      print('🔍 Database query completed successfully');
      print('🔍 User profile found: ${userProfile != null}');

      if (userProfile != null) {
        print('🔍 ===== PROFILE DETAILS =====');
        print('🔍 Role: ${userProfile['role']}');
        print('🔍 Account disabled: ${userProfile['account_disable']}');
        print('🔍 Profile completed: ${userProfile['profile_completed']}');
        print('🔍 Name: ${userProfile['name']}');
        print('🔍 Email: ${userProfile['email']}');
        print('🔍 ==============================');
      } else {
        print('🔍 No profile found in database for this user');
      }

      if (userProfile == null) {
        // New user - redirect to role selection for profile setup
        print('🆕 New user detected (no profile in user_profiles table)');
        print('🆕 Redirecting to role selection for profile setup');
        _redirectToRoleSelection();
      } else {
        // Existing user - check account status first
        final isDisabled = userProfile['account_disable'] as bool? ?? false;
        print('🔍 Account disabled status: $isDisabled');

        if (isDisabled) {
          print('🚫 Account disabled, redirecting to unable account page');
          _redirectToUnableAccount(userProfile);
          return;
        }

        // Check if profile is completed
        final isProfileCompleted =
            userProfile['profile_completed'] as bool? ?? false;
        final role = userProfile['role'];

        print('🔍 Profile completed: $isProfileCompleted');
        print('🔍 User role: $role');

        if (!isProfileCompleted || role == null) {
          print('⚠️ Incomplete profile, redirecting to role selection');
          _redirectToRoleSelection();
        } else {
          print(
            '✅ Existing user with complete profile, redirecting to dashboard',
          );
          print('✅ User role: $role');
          _redirectToDashboard(role);
        }
      }
    } catch (e) {
      print('❌ Error handling auth state change: $e');
      print('❌ Stack trace: ${e.toString()}');
      _redirectToLogin();
    }
  }

  void _redirectToLogin() {
    if (mounted) {
      print('🔄 Setting home widget to LoginPage');
      setState(() {
        _home = const LoginPage();
        _loading = false;
      });
      print('✅ Successfully redirected to LoginPage');
    } else {
      print('❌ Widget not mounted, cannot redirect to LoginPage');
    }
  }

  void _redirectToRoleSelection() {
    if (mounted) {
      print('🔄 Setting home widget to RoleSelectionPage');
      setState(() {
        _home = const RoleSelectionPage();
        _loading = false;
      });
      print('✅ Successfully redirected to RoleSelectionPage');
    } else {
      print('❌ Widget not mounted, cannot redirect to RoleSelectionPage');
    }
  }

  void _redirectToDashboard(String role) {
    if (mounted) {
      final userRole = UserRoleExtension.fromDbValue(role);
      if (userRole != null) {
        setState(() {
          _home = DashboardRouter(role: userRole);
          _loading = false;
        });
      } else {
        print('⚠️ Unknown role: $role, redirecting to role selection');
        _redirectToRoleSelection();
      }
    }
  }

  void _redirectToUnableAccount(Map<String, dynamic> userProfile) {
    if (mounted) {
      setState(() {
        _home = UnableAccountPage(userProfile: userProfile);
        _loading = false;
      });
    }
  }

  // Force an immediate auth check (useful after OAuth callbacks)
  void forceAuthCheck() {
    print('🔥 FORCE AUTH CHECK: Manually checking authentication state');
    _checkSession();
  }

  //Checks if Users is logged in or not
  Future<void> _checkSession() async {
    print('🔍 Checking current session...');
    final user = SupabaseService.getCurrentUser();
    print('🔍 Current user from SupabaseService: ${user?.email}');

    // Also check Supabase client directly
    final directUser = supabase.auth.currentUser;
    print('🔍 Current user from Supabase client: ${directUser?.email}');

    if (user != null) {
      print('✅ User is logged in, handling authentication for: ${user.email}');
      // User is logged in, handle the authentication
      await _handleAuthStateChange(user);
    } else if (directUser != null) {
      print('✅ User found via direct client check: ${directUser.email}');
      await _handleAuthStateChange(directUser);
    } else {
      print('❌ No user logged in, redirecting to login');
      // No user logged in, redirect to login
      _redirectToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _home!;
  }
}