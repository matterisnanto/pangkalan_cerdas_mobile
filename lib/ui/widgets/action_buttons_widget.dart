import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_queue_provider.dart';
import '../screens/dashboard_screen.dart';

class ActionButtonsWidget extends StatelessWidget {
  final DashboardScreenState dashboardState;

  const ActionButtonsWidget({super.key, required this.dashboardState});

  @override
  Widget build(BuildContext context) {
    final txQueue = Provider.of<TransactionQueueProvider>(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _btn(
          icon: Icons.upload_file,
          label: 'Import Pelanggan',
          color: Colors.teal,
          loading: dashboardState.isImporting,
          onPressed: dashboardState.importPelanggan,
        ),
        _btn(
          icon: Icons.play_arrow,
          label: 'Eksekusi Antrean',
          color: Colors.blue.shade800,
          loading: txQueue.isRunning,
          onPressed: txQueue.isRunning ? null : dashboardState.executeQueue,
        ),
        _btn(
          icon: Icons.replay,
          label: 'Retry All',
          color: Colors.orange.shade800,
          onPressed: txQueue.isRunning ? null : dashboardState.retryAll,
        ),
        _btn(
          icon: Icons.download,
          label: 'Ekspor Excel',
          color: Colors.green.shade800,
          loading: dashboardState.isExporting,
          onPressed: dashboardState.exportExcel,
        ),
        _btn(
          icon: Icons.sync,
          label: 'Sync Web',
          color: Colors.purple,
          loading: dashboardState.isSyncing,
          onPressed: dashboardState.syncWebHistory,
        ),
      ],
    );
  }

  Widget _btn({
    required IconData icon,
    required String label,
    required Color color,
    bool loading = false,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
