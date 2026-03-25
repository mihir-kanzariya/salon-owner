import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import 'providers/salon_provider.dart';
import 'dashboard/presentation/screens/dashboard_screen.dart';
import 'bookings/presentation/screens/salon_bookings_screen.dart';
import 'services/presentation/screens/service_management_screen.dart';
import 'services/presentation/screens/stylist_service_screen.dart';
import 'team/presentation/screens/team_screen.dart';
import 'profile/presentation/screens/salon_profile_screen.dart';
import 'profile/presentation/screens/stylist_profile_screen.dart';
import '../chat/presentation/screens/chat_list_screen.dart';

class SalonShell extends StatefulWidget {
  const SalonShell({super.key});

  static void switchToTab(int index) {
    _SalonShellState._instance?._switchTab(index);
  }

  @override
  State<SalonShell> createState() => _SalonShellState();
}

class _SalonShellState extends State<SalonShell> {
  static _SalonShellState? _instance;
  int _currentIndex = 0;

  void _switchTab(int index) {
    if (index >= 0 && index < 5) {
      setState(() {
        _loadedTabs.add(index);
        _currentIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _instance = this;
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    super.dispose();
  }

  final Set<int> _loadedTabs = {0}; // Only load dashboard initially

  Widget _buildScreen(int index, SalonProvider sp) {
    if (!_loadedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    if (sp.isStaffRole) {
      // Stylist & Receptionist: Dashboard, Bookings, Services(read-only), Chat, Profile
      switch (index) {
        case 0:
          return const DashboardScreen();
        case 1:
          return const SalonBookingsScreen();
        case 2:
          return const StylistServiceScreen();
        case 3:
          return const ChatListScreen();
        case 4:
          return const StylistProfileScreen();
        default:
          return const SizedBox.shrink();
      }
    }
    // Owner / Manager: Dashboard, Bookings, Services, Team, Salon
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const SalonBookingsScreen();
      case 2:
        return const ServiceManagementScreen();
      case 3:
        return const TeamScreen();
      case 4:
        return const SalonProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SalonProvider>();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(5, (i) => _buildScreen(i, sp)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() {
            _loadedTabs.add(i);
            _currentIndex = i;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        items: sp.isStaffRole
            ? const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Bookings'),
                BottomNavigationBarItem(icon: Icon(Icons.content_cut_outlined), activeIcon: Icon(Icons.content_cut), label: 'Services'),
                BottomNavigationBarItem(icon: Icon(Icons.chat_outlined), activeIcon: Icon(Icons.chat), label: 'Chat'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
              ]
            : const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Bookings'),
                BottomNavigationBarItem(icon: Icon(Icons.content_cut_outlined), activeIcon: Icon(Icons.content_cut), label: 'Services'),
                BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Team'),
                BottomNavigationBarItem(icon: Icon(Icons.store_outlined), activeIcon: Icon(Icons.store), label: 'Salon'),
              ],
      ),
    );
  }
}
