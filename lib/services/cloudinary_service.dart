import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class CloudinaryService {
  static const String cloudName = 'ddivvpavh';         // Replace this
  static const String uploadPreset = 'extra_menu';   // Replace this

  static Future<String?> uploadImage(File imageFile, {String folder = "extra_menu"}) async {
    final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

    final mimeType = lookupMimeType(imageFile.path);
    if (mimeType == null) return null;

    final mimeParts = mimeType.split('/');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType(mimeParts[0], mimeParts[1]),
      ));

    final response = await request.send();

    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final jsonResp = json.decode(respStr);
      return jsonResp['secure_url']; // Image URL
    } else {
      print("Upload failed: ${response.statusCode}");
      return null;
    }
  }
}
