import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  static const String _ipApiUrl = 'https://ipapi.co/json/';  // Using more reliable HTTPS endpoint
  static const List<String> _allowedCountries = ['US', 'CA'];

  static Future<bool> isLocationAllowed() async {
    try {
      // Try both IP checks
      final ipAllowed = await _checkIpLocation();
      print('Primary IP Location Check Result: $ipAllowed');
      
      final backupIpAllowed = await _checkBackupIpLocation();
      print('Backup IP Location Check Result: $backupIpAllowed');

      // If either IP check shows allowed country, permit access
      if (ipAllowed || backupIpAllowed) {
        return true;
      }

      // If both IP checks fail, try GPS as last resort
      final gpsAllowed = await _checkGpsLocation();
      print('GPS Location Check Result: $gpsAllowed');
      return gpsAllowed;

    } catch (e) {
      print('Location check error: $e');
      return false; // Default to blocked if all checks fail
    }
  }

  static Future<bool> _checkIpLocation() async {
    try {
      final response = await http.get(Uri.parse(_ipApiUrl));
      print('Primary IP API Response: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final countryCode = data['country_code'];
        print('Primary IP Country Code: $countryCode');
        return _allowedCountries.contains(countryCode);
      }
    } catch (e) {
      print('Primary IP check error: $e');
    }
    return false;
  }

  static Future<bool> _checkBackupIpLocation() async {
    try {
      final response = await http.get(Uri.parse('http://ip-api.com/json/'));
      print('Backup IP API Response: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final countryCode = data['countryCode'];
        print('Backup IP Country Code: $countryCode');
        return _allowedCountries.contains(countryCode);
      }
    } catch (e) {
      print('Backup IP check error: $e');
    }
    return false;
  }

  static Future<bool> _checkGpsLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission denied forever');
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      print('GPS Position: ${position.latitude}, ${position.longitude}');

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final countryCode = placemarks.first.isoCountryCode ?? '';
        print('GPS Country Code: $countryCode');
        return _allowedCountries.contains(countryCode);
      }
    } catch (e) {
      print('GPS check error: $e');
    }
    return false;
  }

  static Future<String> getCurrentIp() async {
    try {
      final response = await http.get(Uri.parse(_ipApiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['ip'] ?? 'Unknown';
      }
    } catch (e) {
      print('Error getting IP: $e');
    }
    return 'Unknown';
  }

  static Future<void> openSuperVpn() async {
    final vpnUrl = 'https://play.google.com/store/apps/details?id=com.vpnhood.connect.android';
    if (await canLaunchUrl(Uri.parse(vpnUrl))) {
      await launchUrl(Uri.parse(vpnUrl));
    }
  }
} 