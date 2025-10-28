import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

Future<bool> downloadAndExtractModel(String url, String filename, String folder) async {
  final appDocDir = await getApplicationDocumentsDirectory();

  if (await _modelExists(folder, appDocDir.path)) {
    debugPrint('Model already exists at ${appDocDir.path}/$folder');
    return true;
  }
  
  // Create a folder for the extracted model weights
  final modelFolderPath = '${appDocDir.path}/$folder';
  final modelFolder = Directory(modelFolderPath);
  
  // Check if the model folder already exists and contains files
  if (await modelFolder.exists()) {
    final files = await modelFolder.list().toList();
    if (files.isNotEmpty) {
      debugPrint('Model folder already exists at $modelFolderPath with ${files.length} files');
      return true;
    }
  }
  
  // Download the ZIP file to temporary location
  final zipFilePath = '${appDocDir.path}/$filename';
  final client = HttpClient();
  
  try {
    debugPrint('Downloading ZIP file from $url');
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Failed to download ZIP file: ${response.statusCode}');
    }

    // Stream the response directly to a file to avoid memory issues
    final zipFile = File(zipFilePath);
    final sink = zipFile.openWrite();
    
    int totalBytes = 0;
    await for (final chunk in response) {
      sink.add(chunk);
      totalBytes += chunk.length;
      
      // Log progress every 10MB
      if (totalBytes % (10 * 1024 * 1024) == 0) {
        debugPrint('Downloaded ${totalBytes ~/ (1024 * 1024)} MB...');
      }
    }
    
    await sink.close();
    debugPrint('Downloaded ${totalBytes} bytes to $zipFilePath');
    
    // Now extract the ZIP file from disk
    debugPrint('Reading ZIP file for extraction...');
    final zipBytes = await zipFile.readAsBytes();
    
    // Create the model folder if it doesn't exist
    await modelFolder.create(recursive: true);
    
    // Extract the ZIP file
    debugPrint('Extracting ZIP file...');
    final archive = ZipDecoder().decodeBytes(zipBytes);
    
    for (final file in archive) {
      if (file.isFile) {
        final extractedFilePath = '$modelFolderPath/${file.name}';
        final extractedFile = File(extractedFilePath);
        
        // Create subdirectories if they don't exist
        await extractedFile.parent.create(recursive: true);
        
        // Write the file content
        await extractedFile.writeAsBytes(file.content as List<int>);
      }
    }
    
    // Clean up the temporary ZIP file
    await zipFile.delete();
    debugPrint('ZIP extraction completed successfully to $modelFolderPath');
    return true;
  } catch (e) {
    debugPrint('Download and extraction failed: $e');
    // Clean up partial files on failure
    try {
      final zipFile = File(zipFilePath);
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    } catch (_) {}
    return false;
  } finally {
    client.close();
  }
}

Future<bool> _modelExists(String folderName, [String? basePath]) async {
  final appDocDir = await getApplicationDocumentsDirectory();
  final modelFolderPath = basePath ?? '${appDocDir.path}/models/$folderName';
  final modelFolder = Directory(modelFolderPath);
  if (await modelFolder.exists()) {
    final files = await modelFolder.list().toList();
    return files.isNotEmpty;
  }
  return false;
}