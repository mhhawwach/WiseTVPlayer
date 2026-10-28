// In-app update installer: native platforms only (web builds get a stub).
export 'update_installer_stub.dart'
    if (dart.library.io) 'update_installer_io.dart';
