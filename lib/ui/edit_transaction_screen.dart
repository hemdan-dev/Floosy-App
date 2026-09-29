import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../core/app_localizations.dart';
import '../core/money.dart';
import '../data/database/app_database.dart' hide Card;
import '../data/repositories/finance_repository.dart';

class EditTransactionScreen extends ConsumerStatefulWidget {
  const EditTransactionScreen({super.key, required this.transaction});

  final FinanceTransaction transaction;

  @override
  ConsumerState<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState extends ConsumerState<EditTransactionScreen> {
  late final TextEditingController _amount;
  late final TextEditingController _merchant;
  late final TextEditingController _note;
  late String _kind;
  late String _currency;
  late String? _accountId;
  late String? _destinationAccountId;
  late String? _categoryId;
  late DateTime _occurredAt;
  late bool _adjustmentIncreasesBalance;
  bool _busy = false;

  bool get _isAdjustment => widget.transaction.kind == 'adjustment';

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _amount = TextEditingController(
      text: (transaction.amountMinor.abs() / 100).toStringAsFixed(2),
    );
    _merchant = TextEditingController(text: transaction.merchant ?? '');
    _note = TextEditingController(text: transaction.note ?? '');
    _kind = transaction.kind;
    _currency = transaction.currencyCode;
    _accountId = transaction.accountId;
    _destinationAccountId = transaction.destinationAccountId;
    _categoryId = transaction.categoryId;
    _occurredAt = transaction.occurredAt.toLocal();
    _adjustmentIncreasesBalance = transaction.amountMinor >= 0;
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('editTransaction'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          if (_isAdjustment) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: Text(strings.text('balanceAdjustment')),
                subtitle: Text(strings.text('adjustmentExcluded')),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(strings.text('increase')),
                ),
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.remove_rounded),
                  label: Text(strings.text('decrease')),
                ),
              ],
              selected: {_adjustmentIncreasesBalance},
              onSelectionChanged: (value) =>
                  setState(() => _adjustmentIncreasesBalance = value.first),
            ),
          ] else
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'expense',
                  label: Text(strings.text('expense')),
                ),
                ButtonSegment(
                  value: 'income',
                  label: Text(strings.text('income')),
                ),
                ButtonSegment(
                  value: 'transfer',
                  label: Text(strings.text('transfer')),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (value) {
                setState(() {
                  _kind = value.first;
                  if (_kind == 'transfer') {
                    _categoryId = null;
                  } else {
                    _destinationAccountId = null;
                    final selectedCategory = categories
                        .where((item) => item.id == _categoryId)
                        .firstOrNull;
                    if (selectedCategory != null &&
                        selectedCategory.kind != _kind &&
                        selectedCategory.kind != 'both') {
                      _categoryId = null;
                    }
                  }
                });
              },
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
              if (_isAdjustment)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_currency),
                )
              else
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
            key: ValueKey('account-$_accountId'),
            initialValue: accounts.any((item) => item.id == _accountId)
                ? _accountId
                : null,
            decoration: InputDecoration(labelText: strings.text('account')),
            items: accounts
                .where((item) => !_isAdjustment || item.includeInNetWorth)
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _accountId = value;
                if (_destinationAccountId == value) {
                  _destinationAccountId = null;
                }
                if (_isAdjustment && value != null) {
                  _currency = accounts
                      .firstWhere((item) => item.id == value)
                      .currencyCode;
                }
              });
            },
          ),
          if (_kind == 'transfer') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('destination-$_destinationAccountId-$_accountId'),
              initialValue:
                  accounts.any((item) => item.id == _destinationAccountId)
                  ? _destinationAccountId
                  : null,
              decoration: InputDecoration(
                labelText: strings.text('destinationAccount'),
              ),
              items: accounts
                  .where((item) => item.id != _accountId)
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _destinationAccountId = value),
            ),
          ] else if (!_isAdjustment) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('category-$_categoryId-$_kind'),
              initialValue:
                  categories.any(
                    (item) =>
                        item.id == _categoryId &&
                        (item.kind == _kind || item.kind == 'both'),
                  )
                  ? _categoryId
                  : null,
              decoration: InputDecoration(labelText: strings.text('category')),
              items: categories
                  .where((item) => item.kind == _kind || item.kind == 'both')
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _categoryId = value),
            ),
          ],
          if (!_isAdjustment) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _merchant,
              decoration: InputDecoration(labelText: strings.text('merchant')),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: strings.text('note')),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(strings.text('date')),
            subtitle: Text(
              MaterialLocalizations.of(context).formatFullDate(_occurredAt),
            ),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded),
            title: Text(strings.text('time')),
            subtitle: Text(
              MaterialLocalizations.of(
                context,
              ).formatTimeOfDay(TimeOfDay.fromDateTime(_occurredAt)),
            ),
            onTap: _pickTime,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(strings.text('saveChanges')),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _occurredAt,
    );
    if (value == null) return;
    setState(() {
      _occurredAt = DateTime(
        value.year,
        value.month,
        value.day,
        _occurredAt.hour,
        _occurredAt.minute,
        _occurredAt.second,
      );
    });
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (value == null) return;
    setState(() {
      _occurredAt = DateTime(
        _occurredAt.year,
        _occurredAt.month,
        _occurredAt.day,
        value.hour,
        value.minute,
      );
    });
  }

  Future<void> _save() async {
    final strings = AppLocalizations.of(context);
    try {
      final parsedAmount = Money.parseMinor(_amount.text).abs();
      if (parsedAmount == 0) {
        throw StateError(strings.text('amountMustNotBeZero'));
      }
      if (_accountId == null) {
        throw StateError(strings.text('chooseAccount'));
      }
      final amount = _isAdjustment
          ? (_adjustmentIncreasesBalance ? parsedAmount : -parsedAmount)
          : parsedAmount;
      setState(() => _busy = true);
      await ref
          .read(financeRepositoryProvider)
          .updateTransaction(
            widget.transaction.id,
            UpdateTransactionInput(
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
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
