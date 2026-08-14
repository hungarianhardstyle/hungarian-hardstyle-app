import 'package:in_app_update/in_app_update.dart';

class AppUpdateService {
  Future<AppUpdateInfo?> check() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        return info;
      }
    } catch (_) {
      // Sideloaded APKs and unsupported devices do not expose Play updates.
    }
    return null;
  }

  Future<bool> start(AppUpdateInfo info) async {
    try {
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }
      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
