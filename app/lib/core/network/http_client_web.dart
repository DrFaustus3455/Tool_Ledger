import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Web client that sends/receives the HttpOnly session cookie cross-origin.
http.Client createPlatformClient() => BrowserClient()..withCredentials = true;
