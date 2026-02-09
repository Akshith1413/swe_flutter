import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/main_app.dart';

/// App Router Configuration
/// Matches React Router routes from App.jsx
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const MainApp(),
      ),
      // Additional routes can be added here for deep linking
      // GoRoute(
      //   path: '/llm-advice',
      //   name: 'llm-advice',
      //   builder: (context, state) => const LLMAdvicePage(),
      // ),
    ],
  );
}
