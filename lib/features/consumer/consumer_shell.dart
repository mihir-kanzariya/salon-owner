import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'home/presentation/screens/home_screen.dart';
import 'bookings_list/presentation/screens/bookings_list_screen.dart';
import 'favorites/presentation/screens/favorites_screen.dart';
import '../chat/presentation/screens/chat_list_screen.dart';
import 'profile/presentation/screens/consumer_profile_screen.dart';

class ConsumerShell extends StatefulWidget {
  const ConsumerShell({super.key});

  @override
  State<ConsumerShell> createState() => _ConsumerShellState();
}

class _ConsumerShellState extends State<ConsumerShell> {
  int _currentIndex = 0;
  final Set<int> _loadedTabs = {0}; // Only load home initially

  Widget _buildScreen(int index) {
    // Only build screens that have been visited
    if (!_loadedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const BookingsListScreen();
      case 2:
        return const FavoritesScreen();
      case 3:
        return const ChatListScreen();
      case 4:
        return const ConsumerProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(5, _buildScreen),
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), activeIcon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
