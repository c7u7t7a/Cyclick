import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/main_scaffold.dart';
import '../screens/feedback/post_ride_feedback_screen.dart';
import '../models/ride_history_model.dart';
import 'constants.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Listen to auth state so the router rebuilds on login/logout.
  final authNotifier = ValueNotifier<bool>(false);

  ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
    authNotifier.value = next.valueOrNull?.isLoggedIn ?? false;
  });

  return GoRouter(
    initialLocation: kRouteAuth,
    refreshListenable: authNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final loggedIn =
          ref.read(authStateProvider).valueOrNull?.isLoggedIn ?? false;
      final isOnAuth = state.matchedLocation == kRouteAuth;

      if (!loggedIn && !isOnAuth) return kRouteAuth;
      if (loggedIn && isOnAuth) return kRouteHome;
      return null;
    },
    routes: [
      GoRoute(
        path: kRouteAuth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: kRouteHome,
        builder: (context, state) => const MainScaffold(),
        routes: [
          GoRoute(
            path: kRouteFeedback,
            builder: (context, state) {
              final ride = state.extra as RideHistoryModel?;
              return PostRideFeedbackScreen(completedRide: ride);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});
