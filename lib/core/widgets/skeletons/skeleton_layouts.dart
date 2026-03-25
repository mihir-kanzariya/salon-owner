import 'package:flutter/material.dart';
import 'shimmer_wrapper.dart';
import 'skeleton_elements.dart';

/// Repeats a skeleton widget N times inside a shimmer wrapper.
class SkeletonList extends StatelessWidget {
  final Widget child;
  final int count;
  final double spacing;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    required this.child,
    this.count = 4,
    this.spacing = 12,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Padding(
        padding: padding,
        child: Column(
          children: List.generate(
            count,
            (i) => Padding(
              padding: EdgeInsets.only(bottom: i < count - 1 ? spacing : 0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Salon card skeleton matching SalonCard layout.
class SalonCardSkeleton extends StatelessWidget {
  const SalonCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 160, borderRadius: 12),
          const SizedBox(height: 10),
          const SkeletonLine(width: 180, height: 14),
          const SizedBox(height: 6),
          const SkeletonLine(width: 120, height: 12),
          const SizedBox(height: 6),
          Row(
            children: [
              const SkeletonBox(width: 16, height: 16, borderRadius: 4),
              const SizedBox(width: 4),
              const SkeletonLine(width: 40, height: 12),
              const Spacer(),
              const SkeletonLine(width: 60, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// Booking card skeleton matching salon bookings card layout.
class BookingCardSkeleton extends StatelessWidget {
  const BookingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SkeletonCircle(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLine(width: 120, height: 14),
                    const SizedBox(height: 4),
                    const SkeletonLine(width: 80, height: 10),
                  ],
                ),
              ),
              const SkeletonBox(width: 70, height: 24, borderRadius: 6),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const SkeletonLine(width: 90, height: 12),
              const SizedBox(width: 16),
              const SkeletonLine(width: 90, height: 12),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SkeletonLine(width: 80, height: 12),
              const SizedBox(width: 16),
              const SkeletonLine(width: 60, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dashboard skeleton matching the stats grid + quick actions + bookings.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonLine(width: 140, height: 16),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(
                4,
                (_) => const SkeletonBox(height: 80, borderRadius: 12),
              ),
            ),
            const SizedBox(height: 24),
            const SkeletonLine(width: 120, height: 16),
            const SizedBox(height: 12),
            Row(
              children: List.generate(
                3,
                (_) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: const SkeletonBox(height: 72, borderRadius: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SkeletonLine(width: 140, height: 16),
            const SizedBox(height: 12),
            ...List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: const SkeletonBox(height: 60, borderRadius: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Team member card skeleton.
class MemberCardSkeleton extends StatelessWidget {
  const MemberCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SkeletonCircle(size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(width: 100, height: 14),
                const SizedBox(height: 6),
                const SkeletonLine(width: 60, height: 10),
              ],
            ),
          ),
          const SkeletonBox(width: 60, height: 24, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Service card skeleton.
class ServiceCardSkeleton extends StatelessWidget {
  const ServiceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 44, height: 44, borderRadius: 10),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(width: 120, height: 14),
                const SizedBox(height: 6),
                const SkeletonLine(width: 80, height: 10),
              ],
            ),
          ),
          const SkeletonLine(width: 50, height: 14),
        ],
      ),
    );
  }
}

/// Chat list item skeleton.
class ChatListItemSkeleton extends StatelessWidget {
  const ChatListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SkeletonCircle(size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(width: 140, height: 14),
                const SizedBox(height: 6),
                const SkeletonLine(width: 200, height: 10),
              ],
            ),
          ),
          const SkeletonLine(width: 40, height: 10),
        ],
      ),
    );
  }
}

/// Review card skeleton.
class ReviewCardSkeleton extends StatelessWidget {
  const ReviewCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonCircle(size: 36),
              const SizedBox(width: 10),
              Expanded(child: const SkeletonLine(width: 100, height: 14)),
              Row(
                children: List.generate(
                  5,
                  (_) => const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: SkeletonBox(width: 16, height: 16, borderRadius: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const SkeletonLine(height: 12),
          const SizedBox(height: 6),
          const SkeletonLine(width: 200, height: 12),
        ],
      ),
    );
  }
}

/// Profile screen skeleton.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SkeletonBox(height: 180, borderRadius: 16),
            const SizedBox(height: 16),
            const SkeletonCircle(size: 80),
            const SizedBox(height: 12),
            const SkeletonLine(width: 160, height: 16),
            const SizedBox(height: 6),
            const SkeletonLine(width: 120, height: 12),
            const SizedBox(height: 24),
            ...List.generate(
              5,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: const SkeletonBox(height: 56, borderRadius: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Earnings stats grid + list skeleton.
class EarningsSkeleton extends StatelessWidget {
  const EarningsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(
                4,
                (_) => const SkeletonBox(height: 80, borderRadius: 14),
              ),
            ),
            const SizedBox(height: 24),
            const SkeletonBox(height: 200, borderRadius: 16),
            const SizedBox(height: 24),
            ...List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: const SkeletonBox(height: 64, borderRadius: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Notification list item skeleton.
class NotificationItemSkeleton extends StatelessWidget {
  const NotificationItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        children: [
          const SkeletonCircle(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(width: 180, height: 14),
                const SizedBox(height: 6),
                const SkeletonLine(width: 120, height: 10),
              ],
            ),
          ),
          const SkeletonLine(width: 40, height: 10),
        ],
      ),
    );
  }
}

/// Booking detail skeleton.
class BookingDetailSkeleton extends StatelessWidget {
  const BookingDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SkeletonBox(height: 80, borderRadius: 12),
            const SizedBox(height: 16),
            const SkeletonBox(height: 120, borderRadius: 12),
            const SizedBox(height: 16),
            const SkeletonBox(height: 100, borderRadius: 12),
            const SizedBox(height: 16),
            const SkeletonBox(height: 80, borderRadius: 12),
          ],
        ),
      ),
    );
  }
}

/// Salon detail full-page skeleton.
class SalonDetailSkeleton extends StatelessWidget {
  const SalonDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(height: 240, borderRadius: 0),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonLine(width: 200, height: 18),
                  const SizedBox(height: 8),
                  const SkeletonLine(width: 160, height: 12),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SkeletonBox(width: 60, height: 24, borderRadius: 12),
                      const SizedBox(width: 8),
                      const SkeletonBox(width: 60, height: 24, borderRadius: 12),
                      const SizedBox(width: 8),
                      const SkeletonBox(width: 80, height: 24, borderRadius: 12),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SkeletonBox(height: 40, borderRadius: 8),
                  const SizedBox(height: 16),
                  ...List.generate(
                    5,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: const SkeletonBox(height: 64, borderRadius: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transaction list item skeleton.
class TransactionItemSkeleton extends StatelessWidget {
  const TransactionItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 42, height: 42, borderRadius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(width: 140, height: 14),
                const SizedBox(height: 6),
                const SkeletonLine(width: 80, height: 10),
              ],
            ),
          ),
          const SkeletonLine(width: 60, height: 14),
        ],
      ),
    );
  }
}
