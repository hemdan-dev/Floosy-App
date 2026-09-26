import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../core/app_localizations.dart';
import '../core/money.dart';
import '../data/database/app_database.dart' hide Card;
import '../data/repositories/finance_repository.dart';
import '../services/ai_gateway.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  String _mode = 'manual';
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _note = TextEditingController();
  final _natural = TextEditingController();
  String _kind = 'expense';
  String _currency = 'EGP';
  String? _accountId;
  String? _destinationAccountId;
  String? _categoryId;
  DateTime _occurredAt = DateTime.now();
  bool _busy = false;
  bool _recording = false;

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    _natural.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    _accountId ??= accounts.firstOrNull?.id;
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(title: Text(strings.text('add'))),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
          sliver: SliverList.list(
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'manual',
                    label: Text(strings.text('manual')),
                  ),
                  ButtonSegment(
                    value: 'natural',
                    label: Text(strings.text('typeNaturally')),
                  ),
                  ButtonSegment(
                    value: 'voice',
                    label: Text(strings.text('speak')),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (value) =>
                    setState(() => _mode = value.first),
              ),
              const SizedBox(height: 18),
              if (_mode == 'manual')
                _manualForm(strings, accounts, categories)
              else
                _naturalForm(strings, accounts, categories),
              const SizedBox(height: 24),
              _PendingCaptures(
                onReview: (item) => _reviewPending(item, accounts, categories),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _manualForm(
    AppLocalizations strings,
    List<Account> accounts,
    List<Category> categories,
  ) {
    return Column(
      children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'expense',
              label: Text(strings.text('expense')),
            ),
            ButtonSegment(value: 'income', label: Text(strings.text('income'))),
            ButtonSegment(
              value: 'transfer',
              label: Text(strings.text('transfer')),
            ),
          ],
          selected: {_kind},
          onSelectionChanged: (value) => setState(() => _kind = value.first),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: strings.text('amount'),
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _currency,
              items: const ['EGP', 'USD', 'EUR', 'GBP', 'SAR', 'AED']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _currency = value!),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _accountId,
          decoration: InputDecoration(labelText: strings.text('account')),
          items: accounts
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
              )
              .toList(),
          onChanged: (value) => setState(() => _accountId = value),
        ),
        if (_kind == 'transfer') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _destinationAccountId,
            decoration: const InputDecoration(labelText: 'Destination account'),
            items: accounts
                .where((item) => item.id != _accountId)
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => _destinationAccountId = value),
          ),
        ] else ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: InputDecoration(labelText: strings.text('category')),
            items: categories
                .where((item) => item.kind == _kind || item.kind == 'both')
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => _categoryId = value),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _merchant,
          decoration: InputDecoration(labelText: strings.text('merchant')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: InputDecoration(labelText: strings.text('note')),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(
            MaterialLocalizations.of(
              context,
            ).formatFullDate(_occurredAt.toLocal()),
          ),
          onTap: () async {
            final value = await showDatePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDate: _occurredAt,
            );
            if (value != null) setState(() => _occurredAt = value);
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _saveManual,
            icon: const Icon(Icons.check_rounded),
            label: Text(strings.text('save')),
          ),
        ),
      ],
    );
  }

  Widget _naturalForm(
    AppLocalizations strings,
    List<Account> accounts,
    List<Category> categories,
  ) {
    return Column(
      children: [
        TextField(
          controller: _natural,
          minLines: 4,
          maxLines: 7,
          decoration: const InputDecoration(
            hintText:
                'مثال: دفعت ٢٥٠ جنيه بنزين امبارح\nExample: Spent E£250 on fuel yesterday',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        if (_mode == 'voice')
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _toggleRecording(accounts, categories),
              icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
              label: Text(
                _recording ? 'Stop and transcribe' : 'Start recording',
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy || _natural.text.trim().isEmpty
                ? null
                : () => _analyze(accounts, categories),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: const Text('Analyze and review'),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          strings.text('comingFromAi'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _saveManual() async {
    try {
      final amount = Money.parseMinor(_amount.text);
      if (_accountId == null) throw StateError('Create an account first.');
      setState(() => _busy = true);
      await ref
          .read(financeRepositoryProvider)
          .createTransaction(
            CreateTransactionInput(
              kind: _kind,
              amountMinor: amount,
              currencyCode: _currency,
              accountId: _accountId!,
              destinationAccountId: _destinationAccountId,
              categoryId: _categoryId,
              merchant: _merchant.text.trim().isEmpty
                  ? null
                  : _merchant.text.trim(),
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              occurredAt: _occurredAt,
            ),
          );
      await ref.read(widgetServiceProvider).refresh();
      _amount.clear();
      _merchant.clear();
      _note.clear();
      if (mounted) _show('Transaction saved offline.');
    } catch (error) {
      if (mounted) _show(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleRecording(
    List<Account> accounts,
    List<Category> categories,
  ) async {
    try {
      if (!_recording) {
        await ref.read(captureServiceProvider).startRecording();
        setState(() => _recording = true);
        return;
      }
      setState(() {
        _recording = false;
        _busy = true;
      });
      final path = await ref.read(captureServiceProvider).stopRecording();
      if (path == null) return;
      _natural.text = await ref.read(aiGatewayProvider).transcribe(path);
      if (mounted) await _analyze(accounts, categories, source: 'voice');
    } catch (error) {
      if (mounted) _show(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _analyze(
    List<Account> accounts,
    List<Category> categories, {
    String source = 'text',
  }) async {
    if (_natural.text.trim().isEmpty) return false;
    setState(() => _busy = true);
    try {
      final extracted = await ref
          .read(aiGatewayProvider)
          .extractTransactions(
            input: _natural.text,
            source: source,
            locale: Localizations.localeOf(context).languageCode,
            categoryNames: categories.map((item) => item.name).toList(),
            accountNames: accounts.map((item) => item.name).toList(),
          );
      for (final item in extracted) {
        if (!mounted) return false;
        await _review(item, accounts, categories, source);
      }
      _natural.clear();
      return true;
    } catch (error) {
      if (mounted) _show(error.toString());
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reviewPending(
    PendingCapture item,
    List<Account> accounts,
    List<Category> categories,
  ) async {
    _natural.text = item.payload;
    setState(() => _mode = 'natural');
    final saved = await _analyze(accounts, categories, source: item.source);
    if (!saved) return;
    final database = ref.read(databaseProvider);
    await (database.update(
      database.pendingCaptures,
    )..where((row) => row.id.equals(item.id))).write(
      PendingCapturesCompanion(
        state: const Value('completed'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> _review(
    ExtractedTransaction item,
    List<Account> accounts,
    List<Category> categories,
    String source,
  ) async {
    if (accounts.isEmpty) return;
    final amount = TextEditingController(text: item.amount.toStringAsFixed(2));
    var accountId = accounts
        .where(
          (account) =>
              account.name.toLowerCase() == item.accountHint?.toLowerCase(),
        )
        .firstOrNull
        ?.id;
    accountId ??= accounts.first.id;
    var categoryId = categories
        .where(
          (category) =>
              category.name.toLowerCase() == item.categoryHint?.toLowerCase(),
        )
        .firstOrNull
        ?.id;
    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review transaction',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(item.description),
              if (item.reviewReasons.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    item.reviewReasons.join(' • '),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (${item.currencyCode})',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: accountId,
                decoration: const InputDecoration(labelText: 'Account'),
                items: accounts
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => update(() => accountId = value!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => update(() => categoryId = value),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (approved != true) return;
    await ref
        .read(financeRepositoryProvider)
        .createTransaction(
          CreateTransactionInput(
            kind: item.kind,
            amountMinor: Money.parseMinor(amount.text),
            currencyCode: item.currencyCode,
            accountId: accountId!,
            categoryId: categoryId,
            merchant: item.merchant,
            note: item.description,
            tags: item.tags,
            source: source,
            occurredAt: item.occurredAt ?? DateTime.now(),
          ),
        );
    await ref.read(widgetServiceProvider).refresh();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PendingCaptures extends ConsumerWidget {
  const _PendingCaptures({required this.onReview});
  final ValueChanged<PendingCapture> onReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCapturesProvider);
    return pending.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).text('pending'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Card(
                child: ListTile(
                  leading: Icon(
                    item.source == 'sms'
                        ? Icons.sms_outlined
                        : Icons.mic_outlined,
                  ),
                  title: Text(item.payload, maxLines: 2),
                  subtitle: Text(item.sender ?? item.source),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onReview(item),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
