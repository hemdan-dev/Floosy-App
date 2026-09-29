import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('ar')];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const delegate = _AppLocalizationsDelegate();

  bool get isArabic => locale.languageCode == 'ar';

  String text(String key) =>
      (_values[locale.languageCode] ?? _values['en']!)[key] ?? key;

  static const _values = <String, Map<String, String>>{
    'en': {
      'appName': 'Floosy',
      'overview': 'Overview',
      'transactions': 'Transactions',
      'add': 'Add',
      'insights': 'Insights',
      'ask': 'Ask',
      'thisMonth': 'This month',
      'spent': 'Spent',
      'income': 'Income',
      'balance': 'Total balance',
      'budgets': 'Budgets',
      'accounts': 'Accounts',
      'recent': 'Recent transactions',
      'seeAll': 'See all',
      'expense': 'Expense',
      'transfer': 'Transfer',
      'amount': 'Amount',
      'category': 'Category',
      'account': 'Account',
      'merchant': 'Merchant',
      'note': 'Note',
      'date': 'Date',
      'save': 'Save transaction',
      'speak': 'Speak',
      'typeNaturally': 'Type naturally',
      'manual': 'Manual',
      'pending': 'Needs review',
      'emptyTransactions': 'Your transactions will appear here.',
      'askHint': 'Ask about your money…',
      'settings': 'Settings',
      'sync': 'Google Drive sync',
      'apiKey': 'OpenAI API key',
      'security': 'Security',
      'language': 'Language',
      'exports': 'Export data',
      'assets': 'Assets & net worth',
      'installments': 'Installments',
      'cards': 'Cards',
      'offline': 'Offline — changes are saved locally',
      'online': 'Online',
      'noKey': 'Add your OpenAI API key in Settings first.',
      'comingFromAi': 'AI-generated results should be reviewed before saving.',
      'editTransaction': 'Edit transaction',
      'balanceAdjustment': 'Balance adjustment',
      'adjustmentExcluded':
          'Affects your balance but is excluded from income, expenses, and category reports.',
      'increase': 'Increase',
      'decrease': 'Decrease',
      'destinationAccount': 'Destination account',
      'time': 'Time',
      'saveChanges': 'Save changes',
      'amountMustNotBeZero': 'Amount must not be zero.',
      'invalidAmount': 'Enter a valid amount.',
      'chooseAccount': 'Choose an account.',
      'noBalanceAccounts': 'No account is included in total balance.',
      'editTotalBalance': 'Edit total balance',
      'currentBalance': 'Current balance',
      'correctedBalance': 'Corrected total',
      'adjustmentAccount': 'Account to adjust',
      'cancel': 'Cancel',
      'noAdjustmentNeeded': 'The balance is already correct.',
      'balanceUpdated': 'Balance updated with an adjustment transaction.',
      'uncategorized': 'Uncategorized',
      'noMonthlyExpenses': 'No expenses recorded in this month.',
      'expensesByCategory': 'Expenses by category',
      'emptyCategoryTransactions':
          'There are no transactions in this category for this month.',
    },
    'ar': {
      'appName': 'فلوسي',
      'overview': 'الرئيسية',
      'transactions': 'المعاملات',
      'add': 'إضافة',
      'insights': 'التحليلات',
      'ask': 'اسأل',
      'thisMonth': 'هذا الشهر',
      'spent': 'المصروفات',
      'income': 'الدخل',
      'balance': 'إجمالي الرصيد',
      'budgets': 'الميزانيات',
      'accounts': 'الحسابات',
      'recent': 'أحدث المعاملات',
      'seeAll': 'عرض الكل',
      'expense': 'مصروف',
      'transfer': 'تحويل',
      'amount': 'المبلغ',
      'category': 'التصنيف',
      'account': 'الحساب',
      'merchant': 'التاجر',
      'note': 'ملاحظة',
      'date': 'التاريخ',
      'save': 'حفظ المعاملة',
      'speak': 'تحدث',
      'typeNaturally': 'اكتب بطريقتك',
      'manual': 'يدوي',
      'pending': 'تحتاج مراجعة',
      'emptyTransactions': 'ستظهر معاملاتك هنا.',
      'askHint': 'اسأل عن فلوسك…',
      'settings': 'الإعدادات',
      'sync': 'المزامنة مع Google Drive',
      'apiKey': 'مفتاح OpenAI API',
      'security': 'الأمان',
      'language': 'اللغة',
      'exports': 'تصدير البيانات',
      'assets': 'الأصول وصافي الثروة',
      'installments': 'الأقساط',
      'cards': 'البطاقات',
      'offline': 'غير متصل — تم حفظ التغييرات على الجهاز',
      'online': 'متصل',
      'noKey': 'أضف مفتاح OpenAI API في الإعدادات أولاً.',
      'comingFromAi': 'راجع النتائج التي أنشأها الذكاء الاصطناعي قبل الحفظ.',
      'editTransaction': 'تعديل المعاملة',
      'balanceAdjustment': 'تسوية الرصيد',
      'adjustmentExcluded':
          'تؤثر على الرصيد ولا تُحتسب ضمن الدخل أو المصروفات أو تقارير التصنيفات.',
      'increase': 'زيادة',
      'decrease': 'نقصان',
      'destinationAccount': 'الحساب المستلم',
      'time': 'الوقت',
      'saveChanges': 'حفظ التغييرات',
      'amountMustNotBeZero': 'يجب ألا يكون المبلغ صفراً.',
      'invalidAmount': 'أدخل مبلغاً صحيحاً.',
      'chooseAccount': 'اختر حساباً.',
      'noBalanceAccounts': 'لا يوجد حساب مضاف إلى إجمالي الرصيد.',
      'editTotalBalance': 'تعديل إجمالي الرصيد',
      'currentBalance': 'الرصيد الحالي',
      'correctedBalance': 'الإجمالي الصحيح',
      'adjustmentAccount': 'الحساب المطلوب تسويته',
      'cancel': 'إلغاء',
      'noAdjustmentNeeded': 'الرصيد صحيح بالفعل.',
      'balanceUpdated': 'تم تحديث الرصيد وإضافة معاملة تسوية.',
      'uncategorized': 'غير مصنف',
      'noMonthlyExpenses': 'لا توجد مصروفات مسجلة في هذا الشهر.',
      'expensesByCategory': 'المصروفات حسب التصنيف',
      'emptyCategoryTransactions':
          'لا توجد معاملات في هذا التصنيف خلال هذا الشهر.',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
