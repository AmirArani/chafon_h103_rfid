import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('fa')];

  /// No description provided for @appTitle.
  ///
  /// In fa, this message translates to:
  /// **'PersicaRFID Connection'**
  String get appTitle;

  /// No description provided for @appTitleDevMode.
  ///
  /// In fa, this message translates to:
  /// **'Bluetooth Devices (Dev Mode)'**
  String get appTitleDevMode;

  /// No description provided for @searching.
  ///
  /// In fa, this message translates to:
  /// **'جستجو...'**
  String get searching;

  /// No description provided for @searchingSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'در حال جستجوی PersicaRFID'**
  String get searchingSubtitle;

  /// No description provided for @readerFound.
  ///
  /// In fa, this message translates to:
  /// **'Reader پیدا شد!'**
  String get readerFound;

  /// No description provided for @readerFoundSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'PersicaRFID شناسایی شد'**
  String get readerFoundSubtitle;

  /// No description provided for @connecting.
  ///
  /// In fa, this message translates to:
  /// **'در حال اتصال...'**
  String get connecting;

  /// No description provided for @connectingSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'برقراری اتصال به PersicaRFID'**
  String get connectingSubtitle;

  /// No description provided for @connected.
  ///
  /// In fa, this message translates to:
  /// **'متصل'**
  String get connected;

  /// No description provided for @connectedSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'PersicaRFID آماده است'**
  String get connectedSubtitle;

  /// No description provided for @connectionTimeout.
  ///
  /// In fa, this message translates to:
  /// **'اتصال منقضی شد'**
  String get connectionTimeout;

  /// No description provided for @connectionTimeoutSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'PersicaRFID یافت نشد'**
  String get connectionTimeoutSubtitle;

  /// No description provided for @connectionError.
  ///
  /// In fa, this message translates to:
  /// **'خطای اتصال'**
  String get connectionError;

  /// No description provided for @connectionErrorSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'اتصال ناموفق'**
  String get connectionErrorSubtitle;

  /// No description provided for @deviceDisconnected.
  ///
  /// In fa, this message translates to:
  /// **'دستگاه قطع شد'**
  String get deviceDisconnected;

  /// No description provided for @failedToConnect.
  ///
  /// In fa, this message translates to:
  /// **'اتصال به دستگاه ناموفق'**
  String get failedToConnect;

  /// No description provided for @persicaRfidNotFound.
  ///
  /// In fa, this message translates to:
  /// **'PersicaRFID یافت نشد'**
  String get persicaRfidNotFound;

  /// No description provided for @openFunctions.
  ///
  /// In fa, this message translates to:
  /// **'باز کردن برنامه'**
  String get openFunctions;

  /// No description provided for @retryConnection.
  ///
  /// In fa, this message translates to:
  /// **'تلاش مجدد اتصال'**
  String get retryConnection;

  /// No description provided for @developerModeActive.
  ///
  /// In fa, this message translates to:
  /// **'حالت توسعه‌دهنده فعال'**
  String get developerModeActive;

  /// No description provided for @exit.
  ///
  /// In fa, this message translates to:
  /// **'خروج'**
  String get exit;

  /// No description provided for @noDevicesFound.
  ///
  /// In fa, this message translates to:
  /// **'هیچ دستگاهی یافت نشد. مطمئن شوید که بلوتوث فعال است.'**
  String get noDevicesFound;

  /// No description provided for @connect.
  ///
  /// In fa, this message translates to:
  /// **'اتصال'**
  String get connect;

  /// No description provided for @functions.
  ///
  /// In fa, this message translates to:
  /// **'PersicaRFID'**
  String get functions;

  /// No description provided for @continuousRead.
  ///
  /// In fa, this message translates to:
  /// **'پیوسته'**
  String get continuousRead;

  /// No description provided for @singleRead.
  ///
  /// In fa, this message translates to:
  /// **'تکی'**
  String get singleRead;

  /// No description provided for @radarSearch.
  ///
  /// In fa, this message translates to:
  /// **'رادار'**
  String get radarSearch;

  /// No description provided for @settings.
  ///
  /// In fa, this message translates to:
  /// **'تنظیمات'**
  String get settings;

  /// No description provided for @start.
  ///
  /// In fa, this message translates to:
  /// **'شروع'**
  String get start;

  /// No description provided for @clear.
  ///
  /// In fa, this message translates to:
  /// **'پاک کردن'**
  String get clear;

  /// No description provided for @stop.
  ///
  /// In fa, this message translates to:
  /// **'توقف'**
  String get stop;

  /// No description provided for @readSingleTag.
  ///
  /// In fa, this message translates to:
  /// **'خواندن 1 تگ'**
  String get readSingleTag;

  /// No description provided for @readResult.
  ///
  /// In fa, this message translates to:
  /// **'نتیجه:'**
  String get readResult;

  /// No description provided for @tagNotRead.
  ///
  /// In fa, this message translates to:
  /// **'تگ خوانده نشده'**
  String get tagNotRead;

  /// No description provided for @singleTagRead.
  ///
  /// In fa, this message translates to:
  /// **'خواندن تگ تکی:'**
  String get singleTagRead;

  /// No description provided for @epc.
  ///
  /// In fa, this message translates to:
  /// **'EPC'**
  String get epc;

  /// No description provided for @data.
  ///
  /// In fa, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @status.
  ///
  /// In fa, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @empty.
  ///
  /// In fa, this message translates to:
  /// **'خالی'**
  String get empty;

  /// No description provided for @name.
  ///
  /// In fa, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @saveTag.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره تگ'**
  String get saveTag;

  /// No description provided for @tagSaved.
  ///
  /// In fa, this message translates to:
  /// **'تگ ذخیره شد'**
  String get tagSaved;

  /// No description provided for @memoryBank.
  ///
  /// In fa, this message translates to:
  /// **'بانک حافظه'**
  String get memoryBank;

  /// No description provided for @selectSavedTagOrEnterEpc.
  ///
  /// In fa, this message translates to:
  /// **'تگ ذخیره شده را انتخاب کنید یا EPC را دستی وارد کنید:'**
  String get selectSavedTagOrEnterEpc;

  /// No description provided for @selectSavedTag.
  ///
  /// In fa, this message translates to:
  /// **'تگ ذخیره شده را انتخاب کنید'**
  String get selectSavedTag;

  /// No description provided for @epcToSearch.
  ///
  /// In fa, this message translates to:
  /// **'EPC برای جستجو'**
  String get epcToSearch;

  /// No description provided for @detectedEpc.
  ///
  /// In fa, this message translates to:
  /// **'EPC شناسایی شده'**
  String get detectedEpc;

  /// No description provided for @startRadar.
  ///
  /// In fa, this message translates to:
  /// **'شروع رادار'**
  String get startRadar;

  /// No description provided for @stopRadar.
  ///
  /// In fa, this message translates to:
  /// **'توقف رادار'**
  String get stopRadar;

  /// No description provided for @outputPower.
  ///
  /// In fa, this message translates to:
  /// **'قدرت خروجی'**
  String get outputPower;

  /// No description provided for @saveParameters.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره پارامترها'**
  String get saveParameters;

  /// No description provided for @checkBattery.
  ///
  /// In fa, this message translates to:
  /// **'بررسی باتری'**
  String get checkBattery;

  /// No description provided for @savedTags.
  ///
  /// In fa, this message translates to:
  /// **'تگ‌های ذخیره شده'**
  String get savedTags;

  /// No description provided for @noSavedTagsYet.
  ///
  /// In fa, this message translates to:
  /// **'هنوز تگی ذخیره نشده است.\nتگ‌ها را از تب‌های خواندن مداوم یا تکی ذخیره کنید.'**
  String get noSavedTagsYet;

  /// No description provided for @deleteTag.
  ///
  /// In fa, this message translates to:
  /// **'حذف تگ'**
  String get deleteTag;

  /// No description provided for @areYouSureDelete.
  ///
  /// In fa, this message translates to:
  /// **'آیا مطمئن هستید که می‌خواهید \"{tagName}\" را حذف کنید؟'**
  String areYouSureDelete(String tagName);

  /// No description provided for @cancel.
  ///
  /// In fa, this message translates to:
  /// **'انصراف'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In fa, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @disconnect.
  ///
  /// In fa, this message translates to:
  /// **'قطع اتصال'**
  String get disconnect;

  /// No description provided for @tagSavedSuccessfully.
  ///
  /// In fa, this message translates to:
  /// **'تگ با موفقیت ذخیره شد'**
  String get tagSavedSuccessfully;

  /// No description provided for @tagRenamedSuccessfully.
  ///
  /// In fa, this message translates to:
  /// **'تگ با موفقیت تغییر نام یافت'**
  String get tagRenamedSuccessfully;

  /// No description provided for @tagDeletedSuccessfully.
  ///
  /// In fa, this message translates to:
  /// **'تگ با موفقیت حذف شد'**
  String get tagDeletedSuccessfully;

  /// No description provided for @failedToSaveTag.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره تگ ناموفق'**
  String get failedToSaveTag;

  /// No description provided for @failedToGetDeviceConfig.
  ///
  /// In fa, this message translates to:
  /// **'دریافت تنظیمات دستگاه ناموفق'**
  String get failedToGetDeviceConfig;

  /// No description provided for @parametersSaved.
  ///
  /// In fa, this message translates to:
  /// **'پارامترها ذخیره شدند (FLASH)'**
  String get parametersSaved;

  /// No description provided for @parametersNotWritten.
  ///
  /// In fa, this message translates to:
  /// **'پارامترها نوشته نشدند'**
  String get parametersNotWritten;

  /// No description provided for @error.
  ///
  /// In fa, this message translates to:
  /// **'خطا'**
  String get error;

  /// No description provided for @developerModeEnabled.
  ///
  /// In fa, this message translates to:
  /// **'حالت توسعه‌دهنده فعال شد'**
  String get developerModeEnabled;

  /// No description provided for @started.
  ///
  /// In fa, this message translates to:
  /// **'شروع شد'**
  String get started;

  /// No description provided for @stopped.
  ///
  /// In fa, this message translates to:
  /// **'متوقف شد'**
  String get stopped;

  /// No description provided for @rssi.
  ///
  /// In fa, this message translates to:
  /// **'RSSI'**
  String get rssi;

  /// No description provided for @readCount.
  ///
  /// In fa, this message translates to:
  /// **'Count'**
  String get readCount;

  /// No description provided for @lastSeen.
  ///
  /// In fa, this message translates to:
  /// **'Last Seen'**
  String get lastSeen;

  /// No description provided for @dBm.
  ///
  /// In fa, this message translates to:
  /// **'dBm'**
  String get dBm;

  /// No description provided for @battery.
  ///
  /// In fa, this message translates to:
  /// **'باتری'**
  String get battery;

  /// No description provided for @percent.
  ///
  /// In fa, this message translates to:
  /// **'%'**
  String get percent;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
