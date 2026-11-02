import 'package:http/http.dart' as http;

/// Native (Android/Desktop) client.
http.Client createPlatformClient() => http.Client();
