import 'package:http/http.dart' as http;

/// true  -> utilise la VM (192.168.101.128)
/// false -> utilise ta machine locale (localhost)
const bool useVmBackend = false;

String get apiBaseUrl {
  if (useVmBackend) {
    // 🔹 BACKEND SUR LA VM
    return 'http://192.168.101.128:8080/api';
  } else {
    // 🔹 BACKEND DOCKER EN LOCAL
    return 'http://localhost:8080/api';
  }
}

// Exemple d'appel
Future<http.Response> getLatestNews() {
  final uri = Uri.parse('$apiBaseUrl/news/latest');
  return http.get(uri);
}
