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

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              // 🔥 Responsive columns
              final statColumns = (width / 260).floor().clamp(1, 5);
              final chartColumns = (width / 500).floor().clamp(1, 2);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
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
                            fontSize: 26,
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

                    // 🔹 Stats Grid (Responsive)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: statColumns,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        final stats = [
                          StatCard(
                            title: 'Total Requests',
                            value: '$totalRequests',
                            icon: Icons.assignment,
                            color: Color(0xFF4DB8FF),
                          ),
                          StatCard(
                            title: 'Accepted',
                            value: '$accepted',
                            icon: Icons.check_circle,
                            color: Color(0xFF4CAF50),
                          ),
                          StatCard(
                            title: 'Under Action',
                            value: '$underAction',
                            icon: Icons.autorenew,
                            color: Color(0xFFFFC107),
                          ),
                          StatCard(
                            title: 'Resolved',
                            value: '$resolved',
                            icon: Icons.done_all,
                            color: Color(0xFF8BC34A),
                          ),
                          StatCard(
                            title: 'Pending',
                            value: '$pending',
                            icon: Icons.schedule,
                            color: Color(0xFFFF9800),
                          ),
                        ];
                        return stats[index];
                      },
                    ),

                    const SizedBox(height: 40),

                    // Charts Header
                    Text(
                      'Analytics',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 20),

                    // 🔹 Charts Grid (Responsive)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: chartColumns,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: 1.4,
                      ),
                      itemCount: 2,
                      itemBuilder: (context, index) {
                        final charts = [
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
                        ];
                        return charts[index];
                      },
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
