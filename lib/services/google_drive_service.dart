import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;

class GoogleDriveService {
  // Target shared Google Drive Folder ID
  static const String folderId = '1NTL1oX6929bvzi-R1sWxg0KLj2KAtaLm';

  /// --- METHOD A: GOOGLE APPS SCRIPT WEB APP METHOD (Highly Recommended for Production) ---
  /// Deployed Google Apps Script URL. This method is secure because it doesn't expose 
  /// any Google Cloud credentials inside the Flutter client bundle.
  /// Replace this with your actual Apps Script URL when deployed.
  static const String googleAppsScriptUrl = 'YOUR_GOOGLE_APPS_SCRIPT_WEB_APP_URL';

  /// --- METHOD B: SERVICE ACCOUNT METHOD (Direct API client-side) ---
  /// Paste your Google Cloud Service Account credentials JSON string here.
  /// Ensure you share the Drive folder with the Service Account email as "Editor".
  static const String serviceAccountJsonCredentials = '''{
  "type": "service_account",
  "project_id": "YOUR_PROJECT_ID",
  "private_key_id": "YOUR_PRIVATE_KEY_ID",
  "private_key": "-----BEGIN PRIVATE KEY-----\\nYOUR_PRIVATE_KEY\\n-----END PRIVATE KEY-----\\n",
  "client_email": "YOUR_SERVICE_ACCOUNT_EMAIL@YOUR_PROJECT_ID.iam.gserviceaccount.com",
  "client_id": "YOUR_CLIENT_ID",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/brands",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/YOUR_SERVICE_ACCOUNT_EMAIL"
}''';

  /// Uploads an image to Google Drive and returns the direct public download URL.
  /// Automatically uses Google Apps Script if a URL is provided, otherwise falls 
  /// back to the direct Service Account API method.
  Future<String> uploadImage({
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
  }) async {
    // If the Google Apps Script Web App URL is configured, use it (recommended for production)
    if (googleAppsScriptUrl.isNotEmpty && !googleAppsScriptUrl.startsWith('YOUR_')) {
      return _uploadViaAppsScript(fileName, fileBytes, mimeType);
    }

    // Otherwise, use the direct Google Drive API via Service Account credentials
    return _uploadViaServiceAccount(fileName, fileBytes, mimeType);
  }

  /// 1. Uploads via Google Apps Script Proxy (Secure for Production)
  Future<String> _uploadViaAppsScript(
    String fileName,
    Uint8List fileBytes,
    String mimeType,
  ) async {
    try {
      final String base64Image = base64Encode(fileBytes);
      
      final response = await http.post(
        Uri.parse(googleAppsScriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fileName': fileName,
          'mimeType': mimeType,
          'folderId': folderId,
          'fileData': base64Image,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          final String fileId = result['fileId'];
          // Construct the direct, downloadable/displayable Google Drive link
          return 'https://drive.google.com/uc?export=view&id=$fileId';
        } else {
          throw Exception(result['message'] ?? 'Failed to upload via Apps Script');
        }
      } else {
        throw Exception('Apps Script server returned status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Apps Script Upload Error: $e');
    }
  }

  /// 2. Uploads directly via Service Account & Google APIs (Standard direct API)
  Future<String> _uploadViaServiceAccount(
    String fileName,
    Uint8List fileBytes,
    String mimeType,
  ) async {
    // Validate credentials have been filled out
    if (serviceAccountJsonCredentials.contains('YOUR_PROJECT_ID')) {
      throw Exception(
        'Google Cloud credentials are not configured.\n'
        'Please paste your Service Account JSON credentials inside '
        'lib/services/google_drive_service.dart or deploy a Google Apps Script.'
      );
    }

    auth.AutoRefreshingAuthClient? client;
    try {
      // Decode Service Account credentials
      final Map<String, dynamic> accountCredentials = jsonDecode(serviceAccountJsonCredentials);
      final credentials = auth.ServiceAccountCredentials.fromJson(accountCredentials);

      // Request Drive scope
      final List<String> scopes = [drive.DriveApi.driveFileScope];

      // Authenticate with Google
      client = await auth.clientViaServiceAccount(credentials, scopes);
      final driveApi = drive.DriveApi(client);

      // 1. Prepare Google Drive File Metadata
      final fileMetadata = drive.File()
        ..name = fileName
        ..mimeType = mimeType
        ..parents = [folderId]; // Put file into the shared target folder

      // 2. Prepare file stream payload
      final mediaStream = Stream<List<int>>.value(fileBytes);
      final uploadMedia = drive.Media(mediaStream, fileBytes.length);

      // 3. Upload file to Google Drive
      debugPrint('Uploading file to Google Drive folder...');
      final drive.File uploadedFile = await driveApi.files.create(
        fileMetadata,
        uploadMedia: uploadMedia,
      );

      final String? fileId = uploadedFile.id;
      if (fileId == null || fileId.isEmpty) {
        throw Exception('Uploaded file ID is null.');
      }

      // 4. Configure permissions to make the file publicly readable by anyone with the link.
      // This is crucial for rendering the image in CircleAvatar or Image.network.
      debugPrint('Setting public reader permission for file ID: $fileId');
      final permission = drive.Permission()
        ..role = 'reader'
        ..type = 'anyone';
      
      await driveApi.permissions.create(permission, fileId);

      // 5. Construct and return the direct Google Drive download/render link
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    } catch (e) {
      throw Exception('Google Drive API Service Account Upload Error: $e');
    } finally {
      client?.close();
    }
  }
}
