// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'PersicaRFID Connection';

  @override
  String get appTitleDevMode => 'Bluetooth Devices (Dev Mode)';

  @override
  String get searching => 'جستجو...';

  @override
  String get searchingSubtitle => 'در حال جستجوی PersicaRFID';

  @override
  String get readerFound => 'Reader پیدا شد!';

  @override
  String get readerFoundSubtitle => 'PersicaRFID شناسایی شد';

  @override
  String get connecting => 'در حال اتصال...';

  @override
  String get connectingSubtitle => 'برقراری اتصال به PersicaRFID';

  @override
  String get connected => 'متصل';

  @override
  String get connectedSubtitle => 'PersicaRFID آماده است';

  @override
  String get connectionTimeout => 'اتصال منقضی شد';

  @override
  String get connectionTimeoutSubtitle => 'PersicaRFID یافت نشد';

  @override
  String get connectionError => 'خطای اتصال';

  @override
  String get connectionErrorSubtitle => 'اتصال ناموفق';

  @override
  String get deviceDisconnected => 'دستگاه قطع شد';

  @override
  String get failedToConnect => 'اتصال به دستگاه ناموفق';

  @override
  String get persicaRfidNotFound => 'PersicaRFID یافت نشد';

  @override
  String get openFunctions => 'باز کردن برنامه';

  @override
  String get retryConnection => 'تلاش مجدد اتصال';

  @override
  String get developerModeActive => 'حالت توسعه‌دهنده فعال';

  @override
  String get exit => 'خروج';

  @override
  String get noDevicesFound =>
      'هیچ دستگاهی یافت نشد. مطمئن شوید که بلوتوث فعال است.';

  @override
  String get connect => 'اتصال';

  @override
  String get functions => 'PersicaRFID';

  @override
  String get continuousRead => 'پیوسته';

  @override
  String get singleRead => 'تکی';

  @override
  String get radarSearch => 'رادار';

  @override
  String get settings => 'تنظیمات';

  @override
  String get start => 'شروع';

  @override
  String get clear => 'پاک کردن';

  @override
  String get stop => 'توقف';

  @override
  String get readSingleTag => 'خواندن 1 تگ';

  @override
  String get readResult => 'نتیجه:';

  @override
  String get tagNotRead => 'تگ خوانده نشده';

  @override
  String get singleTagRead => 'خواندن تگ تکی:';

  @override
  String get epc => 'EPC';

  @override
  String get data => 'Data';

  @override
  String get status => 'Status';

  @override
  String get empty => 'خالی';

  @override
  String get name => 'Name';

  @override
  String get saveTag => 'ذخیره تگ';

  @override
  String get tagSaved => 'تگ ذخیره شد';

  @override
  String get memoryBank => 'بانک حافظه';

  @override
  String get selectSavedTagOrEnterEpc =>
      'تگ ذخیره شده را انتخاب کنید یا EPC را دستی وارد کنید:';

  @override
  String get selectSavedTag => 'تگ ذخیره شده را انتخاب کنید';

  @override
  String get epcToSearch => 'EPC برای جستجو';

  @override
  String get detectedEpc => 'EPC شناسایی شده';

  @override
  String get startRadar => 'شروع رادار';

  @override
  String get stopRadar => 'توقف رادار';

  @override
  String get outputPower => 'قدرت خروجی';

  @override
  String get saveParameters => 'ذخیره پارامترها';

  @override
  String get checkBattery => 'بررسی باتری';

  @override
  String get savedTags => 'تگ‌های ذخیره شده';

  @override
  String get noSavedTagsYet =>
      'هنوز تگی ذخیره نشده است.\nتگ‌ها را از تب‌های خواندن مداوم یا تکی ذخیره کنید.';

  @override
  String get deleteTag => 'حذف تگ';

  @override
  String areYouSureDelete(String tagName) {
    return 'آیا مطمئن هستید که می‌خواهید \"$tagName\" را حذف کنید؟';
  }

  @override
  String get cancel => 'انصراف';

  @override
  String get delete => 'حذف';

  @override
  String get disconnect => 'قطع اتصال';

  @override
  String get tagSavedSuccessfully => 'تگ با موفقیت ذخیره شد';

  @override
  String get tagRenamedSuccessfully => 'تگ با موفقیت تغییر نام یافت';

  @override
  String get tagDeletedSuccessfully => 'تگ با موفقیت حذف شد';

  @override
  String get failedToSaveTag => 'ذخیره تگ ناموفق';

  @override
  String get failedToGetDeviceConfig => 'دریافت تنظیمات دستگاه ناموفق';

  @override
  String get parametersSaved => 'پارامترها ذخیره شدند (FLASH)';

  @override
  String get parametersNotWritten => 'پارامترها نوشته نشدند';

  @override
  String get error => 'خطا';

  @override
  String get developerModeEnabled => 'حالت توسعه‌دهنده فعال شد';

  @override
  String get started => 'شروع شد';

  @override
  String get stopped => 'متوقف شد';

  @override
  String get rssi => 'RSSI';

  @override
  String get readCount => 'Count';

  @override
  String get lastSeen => 'Last Seen';

  @override
  String get dBm => 'dBm';

  @override
  String get battery => 'باتری';

  @override
  String get percent => '%';
}
