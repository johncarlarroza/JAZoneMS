import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:jazone_monitoring_dashboard/widgets/chartcard.dart';
import 'package:jazone_monitoring_dashboard/widgets/statcard.dart';

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  String _normalizeStatus(Map<String, dynamic> data) {
    // ✅ Prefer statusCode if available
    final code = (data['statusCode'] ?? '').toString().toLowerCase().trim();
    if (code.isNotEmpty) return code;

    // ✅ New schema support
    if (data['citizenSolved'] == true || data['responderSolved'] == true) {
      return 'problem_solved';
    }

    final adminDecision = (data['adminDecision'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    if (adminDecision == 'denied' || adminDecision == 'rejected') {
      return 'denied_by_admin';
    }

    if (adminDecision == 'accepted' || adminDecision == 'approved') {
      // ✅ FIX: support BOTH assignedResponderUid (new) and assignedResponderId (old)
      final assignedUid = (data['assignedResponderUid'] ?? '')
          .toString()
          .trim();
      final assignedId = (data['assignedResponderId'] ?? '').toString().trim();

      final hasAssigned = assignedUid.isNotEmpty || assignedId.isNotEmpty;

      if (hasAssigned) return 'responder_dispatched';
      return 'accepted_by_admin';
    }

    // ✅ Backward compatible: map legacy "status" strings
    final s = (data['status'] ?? '').toString().toLowerCase().trim();
    if (s == 'accepted') return 'accepted_by_admin';
    if (s == 'under action') return 'under_surveillance';
    if (s == 'resolved') return 'problem_solved';
    if (s == 'rejected' || s == 'denied') return 'denied_by_admin';
    if (s == 'reported') return 'pending_admin';
    if (s == 'okay') return 'pending_admin';

    return 'pending_admin';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2435), Color(0xFF163A52), Color(0xFF2D5F7B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('reports').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final incidents = snapshot.data!.docs;

          final totalRequests = incidents.length;

          int accepted = 0;
          int underAction = 0;
          int resolved = 0;
          int denied = 0;
          int dispatched = 0;
          int pending = 0; // ✅ FIX: count pending directly (no subtraction)

          for (final doc in incidents) {
            final data = doc.data();
            final st = _normalizeStatus(data);

            if (st == 'accepted_by_admin') {
              accepted++;
            } else if (st == 'under_surveillance') {
              underAction++;
            } else if (st == 'responder_dispatched') {
              dispatched++;
            } else if (st == 'problem_solved') {
              resolved++;
            } else if (st == 'denied_by_admin') {
              denied++;
            } else {
              // ✅ Anything else goes to pending
              pending++;
            }
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              final statColumns = (width / 260).floor().clamp(1, 5);
              final chartColumns = (width / 560).floor().clamp(1, 2);

              final today = DateFormat('MMM dd, yyyy').format(DateTime.now());

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderBar(today: today),

                    const SizedBox(height: 18),

                    _GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: const Icon(
                              Icons.monitor_heart,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Live Incident Monitoring',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'All metrics update in real-time as new reports are filed and statuses change.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _Pill(
                            text: 'Realtime',
                            icon: Icons.circle,
                            iconSize: 10,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    Row(
                      children: const [
                        Icon(Icons.insights, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Overview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: statColumns,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 18,
                        childAspectRatio: 1.25,
                      ),
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        final stats = [
                          StatCard(
                            title: 'Total Requests',
                            value: '$totalRequests',
                            icon: Icons.assignment,
                            color: const Color(0xFF4DB8FF),
                          ),
                          StatCard(
                            title: 'Accepted',
                            value: '$accepted',
                            icon: Icons.check_circle,
                            color: const Color(0xFF4CAF50),
                          ),
                          StatCard(
                            title: 'Under Surveillance',
                            value: '$underAction',
                            icon: Icons.visibility,
                            color: const Color(0xFFFFC107),
                          ),
                          StatCard(
                            title: 'Responder Dispatched',
                            value: '$dispatched',
                            icon: Icons.local_hospital,
                            color: const Color(0xFF00BCD4),
                          ),
                          StatCard(
                            title: 'Resolved',
                            value: '$resolved',
                            icon: Icons.done_all,
                            color: const Color(0xFF8BC34A),
                          ),
                          StatCard(
                            title: 'Denied',
                            value: '$denied',
                            icon: Icons.block,
                            color: const Color(0xFFFF5A5F),
                          ),
                          StatCard(
                            title: 'Pending',
                            value: '$pending',
                            icon: Icons.schedule,
                            color: const Color(0xFFFF9800),
                          ),
                        ];
                        return stats[index];
                      },
                    ),

                    const SizedBox(height: 34),

                    Row(
                      children: const [
                        Icon(Icons.analytics, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Analytics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: chartColumns,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 18,
                        childAspectRatio: 1.45,
                      ),
                      itemCount: 2,
                      itemBuilder: (context, index) {
                        final chartData = <String, double>{
                          'Accepted': accepted.toDouble(),
                          'Under Surveillance': underAction.toDouble(),
                          'Responder Dispatched': dispatched.toDouble(),
                          'Resolved': resolved.toDouble(),
                          'Denied': denied.toDouble(),
                          'Pending': pending.toDouble(),
                        };

                        final charts = [
                          ChartCard(
                            title: 'Request Status Distribution',
                            data: chartData,
                            chartType: 'pie',
                          ),
                          ChartCard(
                            title: 'Requests by Status',
                            data: chartData,
                            chartType: 'bar',
                          ),
                        ];

                        return _GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: charts[index],
                        );
                      },
                    ),

                    const SizedBox(height: 26),

                    _GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              resolved > 0
                                  ? 'Good progress: $resolved reports resolved. Keep monitoring responder dispatches for active incidents.'
                                  : 'No resolved incidents yet. Monitor assignments and status updates to improve response time.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final String today;
  const _HeaderBar({required this.today});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Incident Monitoring Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'JAzone Admin System • Real-time updates',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Pill(text: 'Today • $today', icon: Icons.calendar_today),
            const SizedBox(height: 10),
            _Pill(text: 'Firestore Live', icon: Icons.cloud_done),
          ],
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  final double iconSize;

  const _Pill({required this.text, required this.icon, this.iconSize = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
