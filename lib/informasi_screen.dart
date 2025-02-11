import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:project_mbkm/config.dart';
import 'package:project_mbkm/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bottom_nav_bar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class InformasScreen extends StatefulWidget {
  const InformasScreen({super.key, required String token});

  @override
  _InformasiScreenState createState() => _InformasiScreenState();
}

class _InformasiScreenState extends State<InformasScreen> {
  FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _peminjamanData = [];
  List<String> _previousStatuses = [];
  int _currentPage = 1;
  bool _hasMoreData = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _fetchData(_currentPage);
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('status_channel', 'Status Updates',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false);

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchData(_currentPage);
    });
  }

  Future<void> _fetchData(int page) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          _errorMessage = 'User is not authenticated.';
          _isLoading = false;
        });
        return;
      }

      final url = Uri.parse('${Config.baseUrl}/informasi?page=$page');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> newData = data['peminjaman']['data'];
        for (int i = 0; i < newData.length; i++) {
          String newStatus = newData[i]['status'];
          if (i < _previousStatuses.length &&
              _previousStatuses[i] != newStatus) {
            await _showNotification(
              'Status Updated',
              'The status of ${newData[i]['barang']['nama_barang']} has changed to $newStatus',
            );
          }
        }

        setState(() {
          _peminjamanData = newData; // Replace data to avoid duplication
          _isLoading = false;
          _hasMoreData = data['peminjaman']['next_page_url'] != null;
          _previousStatuses =
              newData.map((item) => item['status'] as String).toList();
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch data: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/polindra.png',
              width: 30,
              height: 30,
            ),
            const SizedBox(width: 8),
            const Text(
              'SILK',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0E9F6E),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!))
                  : _peminjamanData.isEmpty
                      ? const Center(child: Text('No data available.'))
                      : Column(
                          children: [
                            // Add the notification card
                            Card(
                              color: Colors.yellow[100], // Light yellow color
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: Colors.yellow,
                                      size: 30,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Pemberitahuan! Silahkan datang ke lab terpadu untuk mengambil atau mengembalikan barang yang dipinjam, sertakan bukti peminjaman.",
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(
                                height:
                                    16), // Space between the card and the list
                            Expanded(
                              child: ListView.builder(
                                itemCount: _peminjamanData.length,
                                itemBuilder: (context, index) {
                                  final peminjaman = _peminjamanData[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${peminjaman['mahasiswa']['nama']}',
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${peminjaman['status']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: _getStatusColor(
                                                      peminjaman),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (peminjaman['barang']['foto'] !=
                                              null)
                                            Image.network(
                                              peminjaman['barang']['foto'],
                                              width: double.infinity,
                                              height: 200,
                                              fit: BoxFit.cover,
                                            ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${peminjaman['barang']['nama_barang']}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Tanggal Pinjam: ${DateTime.fromMillisecondsSinceEpoch(peminjaman['waktu_pinjam_unix'] * 1000).toLocal().toString().split(" ")[0]}',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Waktu Pinjam: ${DateFormat.Hm().format(DateTime.fromMillisecondsSinceEpoch(peminjaman['waktu_pinjam_unix'] * 1000).toLocal())}',
                                            style: const TextStyle(
                                                color: Colors.grey),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Waktu Kembali: ${DateFormat.Hm().format(DateTime.fromMillisecondsSinceEpoch(peminjaman['waktu_kembali_unix'] * 1000).toLocal())}',
                                            style: const TextStyle(
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: Routes.routeToIndex[Routes.informasi]!,
        onTap: (index) {
          setState(() {});
        },
      ),
    );
  }

  Color _getStatusColor(Map<String, dynamic> peminjaman) {
    String status = peminjaman['status'];

    switch (status) {
      case 'Dipinjam':
        return Colors.green;
      case 'Dikembalikan':
        return Colors.purple;
      case 'Menunggu Persetujuan':
        return Colors.yellow;
      default:
        return Colors.black;
    }
  }
}
