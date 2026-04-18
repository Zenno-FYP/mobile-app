import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.body,
    required this.timestamp,
  });

  final String id;
  final IconData icon;
  final List<Color> iconGradient;
  final String title;
  final String body;
  final String timestamp;
}

class NotificationMockRepo {
  static const List<NotificationItem> notifications = [
    NotificationItem(
      id: '1',
      icon: Icons.emoji_events,
      iconGradient: [AppColors.primaryStart, AppColors.primaryEnd],
      title: 'Milestone reached!',
      body: 'You\'ve completed 7 consecutive active days. Keep the streak going!',
      timestamp: '2 hours ago',
    ),
    NotificationItem(
      id: '2',
      icon: Icons.smart_toy,
      iconGradient: [AppColors.teal, AppColors.tealDark],
      title: 'Agent suggestion',
      body: 'Your debugging time increased 15% this week. Consider using breakpoints more effectively.',
      timestamp: '5 hours ago',
    ),
    NotificationItem(
      id: '3',
      icon: Icons.code,
      iconGradient: [AppColors.yellow, AppColors.yellowDark],
      title: 'TypeScript milestone',
      body: 'You\'ve written over 10,000 lines of TypeScript across your projects.',
      timestamp: '1 day ago',
    ),
    NotificationItem(
      id: '4',
      icon: Icons.chat_bubble,
      iconGradient: [AppColors.pink, AppColors.pinkLight],
      title: 'New message',
      body: 'A peer wants to connect with you. Check your chat inbox.',
      timestamp: '2 days ago',
    ),
    NotificationItem(
      id: '5',
      icon: Icons.flag,
      iconGradient: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
      title: 'Weekly goal',
      body: 'You hit 85% of your weekly flow focus target. Great progress!',
      timestamp: '3 days ago',
    ),
  ];
}
