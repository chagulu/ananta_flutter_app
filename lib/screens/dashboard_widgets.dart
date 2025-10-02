import 'package:flutter/material.dart';

class ResidenceDashboardPage extends StatelessWidget {
  const ResidenceDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("My Flat Requests", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _StatCard(title: "Pending Requests", value: "3"),
          _StatCard(title: "Total Requests", value: "27"),
          _StatCard(title: "Upcoming Events", value: "Ganesh Puja, Diwali"),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
