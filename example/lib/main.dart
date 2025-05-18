import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whatsapp Share Plus Demo',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _textController = TextEditingController();
  final _phoneController = TextEditingController();
  XFile? _pickedImage;
  bool _isWhatsappInstalled = false;
  bool _isWhatsappBusinessInstalled = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkWhatsappInstalled();
  }

  Future<void> _checkWhatsappInstalled() async {
    final whatsapp = await WhatsappSharePlus.isWhatsappInstalled();
    final whatsappBusiness = await WhatsappSharePlus.isWhatsappBusinessInstalled();
    setState(() {
      _isWhatsappInstalled = whatsapp;
      _isWhatsappBusinessInstalled = whatsappBusiness;
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareToWhatsapp({required bool business}) async {
    final text = _textController.text.trim();
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), ''); // digits only

    // iOS warning for image+text sharing
    if (Platform.isIOS && _pickedImage != null && text.isNotEmpty) {
      _showSnackBar("iOS does not support sharing image with text together on WhatsApp.");
      return;
    }

    // Check app installed
    final installed = business ? _isWhatsappBusinessInstalled : _isWhatsappInstalled;
    if (!installed) {
      _showSnackBar(
          business ? "WhatsApp Business is not installed." : "WhatsApp is not installed.");
      return;
    }

    bool? success;
    try {
      if (_pickedImage != null) {
        // Share image with optional text
        success = business
            ? await WhatsappSharePlus.shareImageToWhatsappBusiness(
          imagePath: _pickedImage!.path,
          text: text.isEmpty ? null : text,
          phone: phone.isEmpty ? null : phone,
        )
            : await WhatsappSharePlus.shareImageToWhatsapp(
          imagePath: _pickedImage!.path,
          text: text.isEmpty ? null : text,
          phone: phone.isEmpty ? null : phone,
        );
      } else {
        // Share only text
        if (text.isEmpty) {
          _showSnackBar("Please enter a message or select an image to share.");
          return;
        }
        success = business
            ? await WhatsappSharePlus.shareToWhatsappBusiness(
          text: text,
          phone: phone.isEmpty ? null : phone,
        )
            : await WhatsappSharePlus.shareToWhatsapp(
          text: text,
          phone: phone.isEmpty ? null : phone,
        );
      }
      if (success == true) {
        _showSnackBar("Shared successfully!");
      } else {
        _showSnackBar("Sharing failed or cancelled.");
      }
    } catch (e) {
      print(e.toString());
      _showSnackBar("Error while sharing: $e");
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = _pickedImage != null
        ? Image.file(
      File(_pickedImage!.path),
      width: 200,
      height: 200,
      fit: BoxFit.cover,
    )
        : const SizedBox(
      width: 200,
      height: 200,
      child: Center(child: Text("No image selected")),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Whatsapp Share Plus Demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number (with country code, digits only)',
                hintText: 'e.g. 919876543210',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message Text',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            imageWidget,
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.image),
              label: const Text('Pick Image from Gallery'),
              onPressed: _pickImage,
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isWhatsappInstalled
                        ? () => _shareToWhatsapp(business: false)
                        : null,
                    child: const Text('Share to WhatsApp'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isWhatsappBusinessInstalled
                        ? () => _shareToWhatsapp(business: true)
                        : null,
                    child: const Text('Share to WhatsApp Business'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
