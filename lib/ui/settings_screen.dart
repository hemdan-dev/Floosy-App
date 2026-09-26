import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../app_providers.dart';
import '../core/app_localizations.dart';
import 'management_screens.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onLocaleChanged,
    required this.onThemeChanged,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;
  bool _lockEnabled = false;
  String? _lastSync;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final lock = await db.getSetting('lockEnabled') == 'true';
    final lastSync = await db.getSetting('lastSyncAt');
    if (mounted) {
      setState(() {
        _lockEnabled = lock;
        _lastSync = lastSync;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _heading(context, 'Cloud & AI'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(strings.text('sync')),
                  subtitle: Text(
                    _lastSync == null
                        ? 'Not synced yet • private appDataFolder'
                        : 'Last sync: ${DateTime.parse(_lastSync!).toLocal()}',
                  ),
                  trailing: _busy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  onTap: _busy ? null : _sync,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: Text(strings.text('apiKey')),
                  subtitle: const Text(
                    'Stored only in this device’s secure storage',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _configureApiKey,
                ),
              ],
            ),
          ),
          _heading(context, 'Preferences'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(strings.text('language')),
                  trailing: DropdownButton<String>(
                    value: locale,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ar', child: Text('العربية')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      await ref
                          .read(databaseProvider)
                          .setSetting('locale', value);
                      widget.onLocaleChanged(Locale(value));
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.contrast_rounded),
                  title: const Text('Appearance'),
                  trailing: DropdownButton<ThemeMode>(
                    value: Theme.of(context).brightness == Brightness.dark
                        ? ThemeMode.dark
                        : ThemeMode.light,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System'),
                      ),
                    ],
                    onChanged: (mode) async {
                      if (mode == null) return;
                      await ref
                          .read(databaseProvider)
                          .setSetting('theme', mode.name);
                      widget.onThemeChanged(mode);
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('App lock'),
                  subtitle: const Text('Use biometrics or device passcode'),
                  value: _lockEnabled,
                  onChanged: _setLock,
                ),
              ],
            ),
          ),
          _heading(context, 'Organize'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Categories'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoriesScreen()),
              ),
            ),
          ),
          _heading(context, strings.text('exports')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text('Share CSV'),
                  onTap: () => _export('csv'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('Share PDF summary'),
                  onTap: () => _export('pdf'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.data_object_rounded),
                  title: const Text('Share JSON backup'),
                  onTap: () => _export('json'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Floosy keeps its database on your device and can replicate it to '
            'your private Google Drive app-data space. There is no Floosy account, '
            'subscription, advertising, or analytics SDK.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Future<void> _sync() async {
    setState(() => _busy = true);
    try {
      final service = ref.read(driveSyncProvider);
      if (service.connectedEmail == null) await service.connect();
      final report = await service.sync(interactive: true);
      await _load();
      if (mounted) {
        _show(
          'Synced: ${report.uploaded} uploaded, ${report.applied} applied, '
          '${report.conflicts} conflicts.',
        );
      }
    } catch (error) {
      if (mounted) _show(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _configureApiKey() async {
    final controller = TextEditingController(
      text: await ref.read(secureKeyProvider).readOpenAiKey() ?? '',
    );
    if (!mounted) return;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OpenAI API key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                hintText: 'sk-…',
                helperText: 'Used by gpt-4o-mini and gpt-transcribe.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save & test'),
          ),
        ],
      ),
    );
    if (save != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(secureKeyProvider).saveOpenAiKey(controller.text);
      final valid = await ref.read(aiGatewayProvider).validateKey();
      if (!valid) {
        await ref.read(secureKeyProvider).removeOpenAiKey();
        throw StateError('OpenAI rejected this API key.');
      }
      if (mounted) _show('API key saved and validated.');
    } catch (error) {
      if (mounted) _show(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setLock(bool enabled) async {
    if (enabled) {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      if (!supported) {
        if (mounted) _show('Device authentication is not configured.');
        return;
      }
    }
    await ref
        .read(databaseProvider)
        .setSetting('lockEnabled', enabled.toString());
    setState(() => _lockEnabled = enabled);
  }

  Future<void> _export(String format) async {
    try {
      final exporter = ref.read(exportServiceProvider);
      final file = switch (format) {
        'csv' => await exporter.createCsv(),
        'pdf' => await exporter.createPdfSummary(),
        _ => await exporter.createJsonBackup(),
      };
      await exporter.share(file);
    } catch (error) {
      if (mounted) _show(error.toString());
    }
  }

  void _show(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
