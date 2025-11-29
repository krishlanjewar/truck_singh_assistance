import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

class DriverDocument {
  final String type;
  final String? fileUrl;
  final String status;

  DriverDocument({
    required this.type,
    this.fileUrl,
    required this.status,
  });
}

class DocumentVaultPage extends StatefulWidget {
  const DocumentVaultPage({super.key});

  @override
  State<DocumentVaultPage> createState() => _DocumentVaultPageState();
}

class _DocumentVaultPageState extends State<DocumentVaultPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _customUserId;

  List<DriverDocument> _documents = [];

  final List<String> _requiredDocTypes = [
    'Drivers License',
    'Vehicle Registration',
    'Vehicle Insurance',
    'Aadhaar Card',
    'PAN Card',
  ];

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _fetchCustomUserId();
    await _fetchDriverDocuments();
  }

  Future<void> _fetchCustomUserId() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("User not authenticated");

      final response = await _supabase
          .from('user_profiles')
          .select('custom_user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted && response != null) {
        setState(() => _customUserId = response['custom_user_id']);
      }
    } catch (e) {
      _showError("Could not load user profile ID");
    }
  }

  Future<void> _fetchDriverDocuments() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("User not authenticated");

      final response = await _supabase
          .from('driver_documents')
          .select()
          .eq('user_id', userId);

      final uploadedDocs = (response as List)
          .map((doc) => DriverDocument(
        type: doc['document_type'],
        fileUrl: doc['file_url'],
        status: doc['status'] ?? "not_uploaded",
      ))
          .toList();

      final List<DriverDocument> allDocs = _requiredDocTypes.map((type) {
        return uploadedDocs.firstWhere(
              (d) => d.type == type,
          orElse: () => DriverDocument(
            type: type,
            fileUrl: null,
            status: "not_uploaded",
          ),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _documents = allDocs;
          _isLoading = false;
        });
      }
    } catch (e) {
      _showError("Error fetching documents");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadDocument(String docType) async {
    if (_customUserId == null) {
      _showError("User ID not loaded");
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) return;

    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      final file = File(picked.path);
      final extension = picked.path.split('.').last;
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.$extension";

      final folderPath = "${_customUserId!}/$docType";
      final filePath = "$folderPath/$fileName";

      final existingFiles =
      await _supabase.storage.from('driver-documents').list(
        path: folderPath,
      );

      if (existingFiles.isNotEmpty) {
        await _supabase.storage.from('driver-documents').remove(
          existingFiles
              .map((e) => "$folderPath/${e.name}")
              .toList(),
        );
      }

      await _supabase.storage.from('driver-documents').upload(
        filePath,
        file,
        fileOptions: const FileOptions(upsert: false),
      );

      final publicUrl =
      _supabase.storage.from('driver-documents').getPublicUrl(filePath);

      await _supabase.from('driver_documents').upsert(
        {
          'user_id': userId,
          'document_type': docType,
          'file_url': publicUrl,
          'status': 'uploaded',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id, document_type',
      );

      _showSuccess("document_uploaded_successfully".tr());
    } catch (e) {
      _showError("Upload failed");
    } finally {
      await _fetchDriverDocuments();
    }
  }

  Future<void> _viewDocument(String? url) async {
    if (url == null) {
      _showError("no_file_url".tr());
      return;
    }
    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError("could_not_open_document".tr());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("document_vault".tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchDriverDocuments,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _documents.length,
          itemBuilder: (context, index) =>
              _buildDocumentCard(_documents[index]),
        ),
      ),
    );
  }

  Widget _buildDocumentCard(DriverDocument doc) {
    final statusLower = doc.status.toLowerCase();

    IconData icon;
    Color color;

    switch (statusLower) {
      case 'verified':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'rejected':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'uploaded':
        icon = Icons.pending;
        color = Colors.orange;
        break;
      default:
        icon = Icons.cloud_off;
        color = Colors.grey;
    }
    final isUploaded = statusLower != "not_uploaded";
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doc.type,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  doc.status.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isUploaded)
                  TextButton(
                    onPressed: () => _viewDocument(doc.fileUrl),
                    child: Text("view".tr()),
                  ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _uploadDocument(doc.type),
                  child: Text(isUploaded ? "re_upload".tr() : "upload".tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}