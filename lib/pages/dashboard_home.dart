import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jazone_monitoring_dashboard/widgets/chartcard.dart';
import 'package:jazone_monitoring_dashboard/widgets/statcard.dart';

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A3A52), Color(0xFF2D5F7B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('incidents').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final incidents = snapshot.data!.docs;
          final totalRequests = incidents.length;
          final accepted = incidents
              .where((d) => (d.data() as Map)['status'] == 'Accepted')
              .length;
          final underAction = incidents
              .where((d) => (d.data() as Map)['status'] == 'Under Action')
              .length;
          final resolved = incidents
              .where((d) => (d.data() as Map)['status'] == 'Resolved')
              .length;
          final pending = totalRequests - accepted - underAction - resolved;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Incident Management Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Today: ${DateTime.now().toString().split(' ')[0]}',
                      style: const TextStyle(
                        color: Color(0xFF4DB8FF),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Stats Grid
                GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 1.1,
                  children: [
                    StatCard(
                      title: 'Total Requests',
                      value: totalRequests.toString(),
                      icon: Icons.assignment,
                      color: const Color(0xFF4DB8FF),
                    ),
                    StatCard(
                      title: 'Accepted',
                      value: accepted.toString(),
                      icon: Icons.check_circle,
                      color: const Color(0xFF4CAF50),
                    ),
                    StatCard(
                      title: 'Under Action',
                      value: underAction.toString(),
                      icon: Icons.autorenew,
                      color: const Color(0xFFFFC107),
                    ),
                    StatCard(
                      title: 'Resolved',
                      value: resolved.toString(),
                      icon: Icons.done_all,
                      color: const Color(0xFF8BC34A),
                    ),
                    StatCard(
                      title: 'Pending',
                      value: pending.toString(),
                      icon: Icons.schedule,
                      color: const Color(0xFFFF9800),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Charts Section
                Text(
                  'Analytics',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Chart Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 1.3,
                  children: [
                    ChartCard(
                      title: 'Request Status Distribution',
                      data: {
                        'Accepted': accepted.toDouble(),
                        'Under Action': underAction.toDouble(),
                        'Resolved': resolved.toDouble(),
                        'Pending': pending.toDouble(),
                      },
                      chartType: 'pie',
                    ),
                    ChartCard(
                      title: 'Requests by Status',
                      data: {
                        'Accepted': accepted.toDouble(),
                        'Under Action': underAction.toDouble(),
                        'Resolved': resolved.toDouble(),
                        'Pending': pending.toDouble(),
                      },
                      chartType: 'bar',
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
