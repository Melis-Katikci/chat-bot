import 'dart:convert';
import 'package:flutter/foundation.dart'; // kIsWeb (Platform tespiti) için gerekli
import 'package:http/http.dart' as http;

class ApiService {
  // ---------------------------------------------------------------------------
  // 🌐 DİNAMİK IP / URL YAPILANDIRMASI:
  // - Web (Chrome/Edge) üzerinde çalışıyorsa: 'http://localhost:8080/api'
  // - Android Emülatör üzerinde çalışıyorsa: 'http://10.0.2.2:8080/api'
  // - Gerçek Telefon (Wi-Fi) testi için: 'http://10.0.2.2:8080/api' yerine kendi
  //   bilgisayarınızın IP adresini (Örn: 'http://192.168.1.35:8080/api') yazabilirsiniz.
  // ---------------------------------------------------------------------------
  static String get baseUrl {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return 'http://localhost:8080/api'; // Windows Masaüstü ve Web için Gateway Portu
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api'; // Android Emülatör için Gateway Portu
    } else {
      return 'http://localhost:8080/api';
    }
  }

  /// Chatbot'a Kullanıcı Mesajı Gönderme
  static Future<String> sendMessage(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'message': userMessage}),
      );

      if (response.statusCode == 200) {
        // Türkçe karakterlerin (ı, ş, ğ, ç vs.) bozulmaması için utf8.decode kullanımı
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['response'] ?? 'Yanıt alınamadı.';
      } else {
        return 'Sunucu hatası: ${response.statusCode}';
      }
    } catch (e) {
      return 'Bağlantı hatası: $e';
    }
  }

  /// Mesai Dışı Destek / Şikayet Formu Gönderme (SMTP E-posta Tetikler)
  static Future<bool> sendSupportForm({
    required String name,
    required String email,
    required String phone,
    required String subject,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/support'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'subject': subject,
          'message': message,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
