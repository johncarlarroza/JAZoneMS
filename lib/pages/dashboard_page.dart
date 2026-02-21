import 'package:flutter/material.dart';
import 'package:jazone_monitoring_dashboard/pages/citizen_managment.dart';
import 'package:jazone_monitoring_dashboard/pages/responder_management.dart';

import 'dashboard_home.dart';
import 'incident_list_page.dart';
import 'reports_page.dart';
import '../widgets/sidebar.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int index = 0;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = const [
      DashboardHome(),
      IncidentListPage(),
      ReportsPage(),
      CitizensManagementPage(),
      RespondersManagementPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(index: index, onSelect: (i) => setState(() => index = i)),
          Expanded(child: pages[index]),
        ],
      ),
    );
  }
}
