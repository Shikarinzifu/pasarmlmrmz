import 'package:flutter/foundation.dart';
import 'package:flutter_biometric_kit/flutter_biometric_kit.dart';

class BiometricLockProvider extends ChangeNotifier {
  final BiometricService _service = BiometricService();

  bool _isLocked = false;
  bool _isBiometricAvailable = false;
  bool _isAuthenticating = false;
  String? _errorMessage;
  BiometricErrorCode? _errorCode;

  bool get isLocked => _isLocked;
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get isAuthenticating => _isAuthenticating;
  String? get errorMessage => _errorMessage;
  BiometricErrorCode? get errorCode => _errorCode;

  /// Dipanggil satu kali saat app start — cek ketersediaan hardware.
  Future<void> initialize() async {
    _isBiometricAvailable = await _service.isBiometricAvailable();
    notifyListeners();
  }

  /// Kunci aplikasi — hanya aktif jika biometrik tersedia.
  void lock() {
    if (!_isBiometricAvailable) return;
    _isLocked = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
  }

  /// Tampilkan dialog biometrik OS untuk membuka kunci.
  Future<void> unlock() async {
    // Guard: cegah dua dialog muncul bersamaan
    if (_isAuthenticating) return;

    if (!_isBiometricAvailable) {
      _isLocked = false;
      notifyListeners();
      return;
    }

    _isAuthenticating = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      await _service.authenticate(reason: 'Verifikasi untuk membuka Pasar Malam');
      _isLocked = false;
      _errorMessage = null;
      _errorCode = null;
    } on BiometricException catch (e) {
      _errorMessage = e.userMessage;
      _errorCode = e.code;
      debugPrint('[BiometricLock] unlock failed: $e');
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }
}
