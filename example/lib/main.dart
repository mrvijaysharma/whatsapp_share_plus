import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'whatsapp_share_plus',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF25D366),
        useMaterial3: true,
      ),
      home: const SharePage(),
    );
  }
}

class SharePage extends StatefulWidget {
  const SharePage({super.key});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  final _messageController = TextEditingController(
    text: 'Sent from whatsapp_share_plus',
  );
  final _phoneController = TextEditingController();
  final _picker = ImagePicker();

  final _attachments = <ShareFile>[];
  Set<WhatsAppTarget> _installed = const <WhatsAppTarget>{};
  WhatsAppTarget _target = WhatsAppTarget.standard;

  @override
  void initState() {
    super.initState();
    _refreshInstalledTargets();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _refreshInstalledTargets() async {
    final installed = await WhatsAppShare.installedTargets();
    if (!mounted) return;
    setState(() => _installed = installed);
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage();
      if (picked.isEmpty) return;

      final files = <ShareFile>[
        for (final image in picked)
          // A browser has no file system path to share from, so on web the
          // bytes have to travel with the file. Everywhere else a path is
          // cheaper — it avoids copying the image through Dart.
          if (kIsWeb)
            ShareFile.fromBytes(
              await image.readAsBytes(),
              name: image.name,
              mimeType: image.mimeType,
            )
          else
            ShareFile.fromXFile(image),
      ];

      setState(() => _attachments.addAll(files));
    } on MissingPluginException {
      _report('Picking images is not supported on this platform.');
    }
  }

  /// Runs a share and turns any failure into a readable message.
  ///
  /// Every call in this package throws a [WhatsAppShareException] subtype, so
  /// one handler covers the lot — this is the pattern to copy into a real app.
  Future<void> _run(Future<ShareResult> Function() action) async {
    try {
      final result = await action();
      _report(switch (result.status) {
        ShareStatus.opened =>
          'Opened ${result.target?.displayName ?? 'WhatsApp'}.',
        ShareStatus.sheetPresented => 'Shared through the system share sheet.',
        ShareStatus.fallback =>
          'WhatsApp is not installed — opened wa.me instead.',
        ShareStatus.dismissed => 'You closed the share sheet.',
      });
    } on WhatsAppNotInstalledException catch (error) {
      _report('${error.target.displayName} is not installed.');
    } on InvalidShareArgumentException catch (error) {
      _report(error.message);
    } on ShareFileException catch (error) {
      _report('That file could not be shared: ${error.message}');
    } on UnsupportedShareException catch (error) {
      _report(error.message);
    } on WhatsAppShareException catch (error) {
      _report(error.message);
    }
  }

  /// The anchor an iPad or Mac share sheet points at.
  ///
  /// Without it the popover lands in the corner with its arrow pointing at
  /// nothing, and on some iPad configurations UIKit refuses to present at all.
  Rect _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share() => _run(
        () => WhatsAppShare.share(
          text: _messageController.text.trim().isEmpty
              ? null
              : _messageController.text.trim(),
          files: _attachments,
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          target: _target,
          sharePositionOrigin: _shareOrigin(),
        ),
      );

  Future<void> _openChat() => _run(
        () => WhatsAppShare.openChat(
          phone: _phoneController.text.trim(),
          text: _messageController.text.trim(),
          target: _target,
        ),
      );

  Future<void> _diagnose() async {
    final report = await WhatsAppShare.diagnose();
    if (kDebugMode) debugPrint(report.toString());
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.isHealthy ? 'Configuration OK' : 'Issues found'),
        content: SingleChildScrollView(
          child: Text(report.toString(), style: const TextStyle(fontSize: 13)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('whatsapp_share_plus'),
        actions: <Widget>[
          IconButton(
            onPressed: _diagnose,
            icon: const Icon(Icons.health_and_safety_outlined),
            tooltip: 'Run diagnostics',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _InstalledTargets(
            installed: _installed,
            onRefresh: _refreshInstalledTargets,
          ),
          const SizedBox(height: 16),
          SegmentedButton<WhatsAppTarget>(
            segments: WhatsAppTarget.values
                .map(
                  (target) => ButtonSegment<WhatsAppTarget>(
                    value: target,
                    label: Text(target.displayName),
                  ),
                )
                .toList(),
            selected: <WhatsAppTarget>{_target},
            onSelectionChanged: (selection) =>
                setState(() => _target = selection.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Recipient (optional)',
              helperText: 'Any format: +91 98765 43210, 0091…, 919876543210',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _Attachments(
            files: _attachments,
            onAdd: _pickImages,
            onClear: () => setState(_attachments.clear),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.send),
            label: const Text('Share'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openChat,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Open chat (no attachment)'),
          ),
          const SizedBox(height: 24),
          _LinkPreview(
            phone: _phoneController.text,
            text: _messageController.text,
          ),
        ],
      ),
    );
  }
}

/// Shows which WhatsApp apps the device has.
class _InstalledTargets extends StatelessWidget {
  const _InstalledTargets({required this.installed, required this.onRefresh});

  final Set<WhatsAppTarget> installed;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          installed.isEmpty ? Icons.error_outline : Icons.check_circle_outline,
          color: installed.isEmpty
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          installed.isEmpty
              ? 'No WhatsApp app detected'
              : installed.map((target) => target.displayName).join(' + '),
        ),
        subtitle: Text(
          installed.isEmpty
              ? 'Shares will fall back to a wa.me link. Tap the shield icon '
                  'above if you expected an app to be found.'
              : 'Ready to share.',
        ),
        trailing: IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}

/// Lists the files queued for the next share.
class _Attachments extends StatelessWidget {
  const _Attachments({
    required this.files,
    required this.onAdd,
    required this.onClear,
  });

  final List<ShareFile> files;
  final VoidCallback onAdd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Attachments', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add'),
            ),
            if (files.isNotEmpty)
              TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
        if (files.isEmpty)
          const Text('None — the share will be text only.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: files
                .map(
                  (file) => Chip(
                    avatar: Icon(
                      file.isImage
                          ? Icons.image_outlined
                          : file.isVideo
                              ? Icons.movie_outlined
                              : Icons.description_outlined,
                      size: 18,
                    ),
                    label: Text(file.name ?? 'attachment'),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

/// Shows the `wa.me` link for the current input.
///
/// [WhatsAppLink] is pure Dart, so this works with no plugin registered — the
/// same call builds links for QR codes, emails, and web pages.
class _LinkPreview extends StatelessWidget {
  const _LinkPreview({required this.phone, required this.text});

  final String phone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final link = WhatsAppLink.chat(
      phone: phone.isEmpty ? null : phone,
      text: text.isEmpty ? null : text,
    );

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Shareable link',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            SelectableText(link.toString(),
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
