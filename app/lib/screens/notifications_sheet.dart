import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

void showNotificationsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const NotificationsSheet(),
  );
}

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141418),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Color(0xFF2A2A30), width: 1),
              left: BorderSide(color: Color(0xFF2A2A30), width: 1),
              right: BorderSide(color: Color(0xFF2A2A30), width: 1),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active, color: Color(0xFFE11D48), size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF2A2A30), height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('requests')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFFE11D48)),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_outlined,
                                size: 64, color: Colors.white.withOpacity(0.1)),
                            const SizedBox(height: 16),
                            const Text(
                              'No notifications yet',
                              style: TextStyle(color: Colors.white38, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Emergency alerts will appear here',
                              style: TextStyle(color: Colors.white24, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final message = data['message'] ?? 'Emergency blood request';
                        final status = data['status'] ?? 'pending';
                        final timestamp = data['timestamp'];
                        final bloodType = data['bloodType'] ?? '';

                        String timeAgo = '';
                        if (timestamp != null) {
                          final date = timestamp is Timestamp
                              ? timestamp.toDate()
                              : DateTime.fromMillisecondsSinceEpoch(timestamp is int ? timestamp : 0);
                          timeAgo = DateFormat('MMM d, h:mm a').format(date);
                        }

                        final isPending = status == 'pending';

                        return Container(
                          decoration: BoxDecoration(
                            color: isPending
                                ? const Color(0xFFE11D48).withOpacity(0.06)
                                : Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isPending
                                  ? const Color(0xFFE11D48).withOpacity(0.2)
                                  : Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isPending
                                    ? const Color(0xFFE11D48).withOpacity(0.15)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  bloodType,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isPending
                                        ? const Color(0xFFE11D48)
                                        : Colors.white38,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              message,
                              style: TextStyle(
                                color: isPending ? Colors.white : Colors.white54,
                                fontSize: 14,
                                fontWeight:
                                    isPending ? FontWeight.w600 : FontWeight.w400,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isPending
                                          ? const Color(0xFFE11D48).withOpacity(0.15)
                                          : Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isPending ? 'PENDING' : 'ACKNOWLEDGED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isPending
                                            ? const Color(0xFFE11D48)
                                            : Colors.green,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    timeAgo,
                                    style: const TextStyle(
                                      color: Colors.white24,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPending)
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_outline,
                                        color: Color(0xFFE11D48)),
                                    onPressed: () {
                                      docs[index].reference.update({
                                        'status': 'acknowledged',
                                      });
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white38),
                                  onPressed: () {
                                    docs[index].reference.delete();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
