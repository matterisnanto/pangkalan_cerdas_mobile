import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);
  }

  static Future<void> showBatchProgressNotification({
    required int current,
    required int total,
    required int success,
    required int fail,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'batch_channel',
      'Batch Transactions',
      channelDescription: 'Notifikasi status transaksi batch',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: total,
      progress: current,
    );

    final details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      1,
      'Proses Transaksi Batch ($current/$total)',
      'Berhasil: $success | Gagal: $fail',
      details,
    );
  }

  static Future<void> showTokenExpiredNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'token_channel',
      'Token Status',
      channelDescription: 'Peringatan sesi token',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      2,
      'Sesi Token Kadaluarsa',
      'Buka tab WebView untuk memperbarui sesi MyPertamina.',
      details,
    );
  }
}
