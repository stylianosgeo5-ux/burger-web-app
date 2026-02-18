import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class UpdateChecker {
  static const String versionUrl = 'https://burgercy.com/version.json';
  static const String currentVersion = '2.5.0'; // Update this when you make changes
  
  static Timer? _timer;
  
  static void startChecking(BuildContext context) {
    // Check immediately
    _checkForUpdates(context);
    
    // Check every 5 minutes
    _timer = Timer.periodic(Duration(minutes: 5), (_) {
      _checkForUpdates(context);
    });
  }
  
  static void stopChecking() {
    _timer?.cancel();
  }
  
  static Future<void> _checkForUpdates(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(versionUrl));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final serverVersion = data['version'] as String;
        
        if (serverVersion != currentVersion) {
          _showUpdateDialog(context, serverVersion);
        }
      }
    } catch (e) {
      // Silently fail - don't bother user with network errors
    }
  }
  
  static void _showUpdateDialog(BuildContext context, String newVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: Colors.orange, size: 30),
            SizedBox(width: 10),
            Text('Update Available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version of the app is available!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Current: v$currentVersion'),
            Text('New: v$newVersion'),
            SizedBox(height: 12),
            Text(
              'Please update to get the latest features and improvements.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Check again in 1 hour
              Future.delayed(Duration(hours: 1), () {
                _checkForUpdates(context);
              });
            },
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Reload the page
              _reloadApp();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Update Now'),
          ),
        ],
      ),
    );
  }
  
  static void _reloadApp() {
    // For web, reload the page
    html.window.location.reload();
  }
}
