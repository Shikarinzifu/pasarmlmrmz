import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pasar_malam/core/constants/api_constants.dart';
import 'package:pasar_malam/core/services/dio_client.dart';
import 'package:pasar_malam/core/services/notification_service.dart';
import 'package:pasar_malam/core/services/secure_storage.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, emailNotVerified, error }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ─── State ──────────────────────────────────────────────
  AuthStatus _status = AuthStatus.initial;
  String? _backendToken;
  String? _errorMessage;
  String? _userName;
  String? _userEmail;

  // ─── Getters ────────────────────────────────────────────
  AuthStatus get status => _status;
  String? get backendToken => _backendToken;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;
  String? get userName => _userName;
  String? get userEmail => _userEmail;

  // ─── Init: Restore token dari secure storage ────────────
  Future<void> init() async {
    debugPrint('[AUTH] init() — checking stored token...');
    try {
      final token = await SecureStorageService.getToken();
      if (token != null && token.isNotEmpty) {
        _backendToken = token;
        _status = AuthStatus.authenticated;
        debugPrint('[AUTH] Token ditemukan → status=authenticated');
        notifyListeners();
      } else {
        _status = AuthStatus.unauthenticated;
        debugPrint('[AUTH] Tidak ada token → status=unauthenticated');
      }
    } catch (e) {
      debugPrint('[AUTH] Error reading token: $e');
      _status = AuthStatus.unauthenticated;
    }
  }

  // ─── Register dengan Email & Password (langsung ke backend) ───
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading();
    try {
      final response = await DioClient.instance.post(
        ApiConstants.emailRegister,
        data: {'name': name, 'email': email, 'password': password},
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final backendToken = data['access_token'] as String;
      _backendToken = backendToken;
      _userName = name;
      _userEmail = email;

      await SecureStorageService.saveToken(backendToken);

      _status = AuthStatus.emailNotVerified;
      notifyListeners();

      NotificationService.updateFcmToken();
      return true;
    } catch (e) {
      debugPrint('[AUTH] Register gagal: $e');
      _setError(_extractErrorMessage(e));
      return false;
    }
  }

  // ─── Login dengan Email & Password (langsung ke backend) ───
  Future<bool> loginWithEmail({required String email, required String password}) async {
    _setLoading();
    try {
      final response = await DioClient.instance.post(
        ApiConstants.emailLogin,
        data: {'email': email, 'password': password},
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final backendToken = data['access_token'] as String;
      final userData = data['user'] as Map<String, dynamic>;
      _backendToken = backendToken;
      _userName = userData['name'] as String?;
      _userEmail = userData['email'] as String?;

      await SecureStorageService.saveToken(backendToken);

      _status = AuthStatus.authenticated;
      notifyListeners();

      NotificationService.updateFcmToken();
      return true;
    } catch (e) {
      debugPrint('[AUTH] Login gagal: $e');
      _setError(_extractErrorMessage(e));
      return false;
    }
  }

  // ─── Login dengan Google ─────────────────────────────────
  Future<bool> loginWithGoogle() async {
    _setLoading();
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setError('Login Google dibatalkan');
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final firebaseUser = userCred.user;

      final firebaseToken = await firebaseUser?.getIdToken();
      if (firebaseToken == null) throw Exception('Token Firebase null');

      final response = await DioClient.instance.post(
        ApiConstants.verifyToken,
        data: {'firebase_token': firebaseToken},
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final backendToken = data['access_token'] as String;
      _backendToken = backendToken;

      await SecureStorageService.saveToken(backendToken);

      _status = AuthStatus.authenticated;
      notifyListeners();

      NotificationService.updateFcmToken();
      return true;
    } catch (e) {
      debugPrint('[AUTH] Google login gagal: $e');
      _setError('Gagal login dengan Google');
      return false;
    }
  }

  // ─── Resend verification email ──────────────────────────
  Future<void> resendVerificationEmail() async {
    debugPrint('[AUTH] Resend verification email (backend OTP)');
    // Kirim ulang OTP via backend
    try {
      await DioClient.instance.post(
        '/otp/send-email',
      );
      debugPrint('[AUTH] OTP email dikirim ulang');
    } catch (e) {
      debugPrint('[AUTH] Gagal kirim ulang OTP: $e');
    }
  }

  // ─── Setelah email terverifikasi ────────────────────────
  Future<bool> loginAfterEmailVerification() async {
    _status = AuthStatus.authenticated;
    notifyListeners();
    return true;
  }

  // ─── Verify OTP Email ───────────────────────────────────
  Future<bool> verifyEmailOTP(String code) async {
    try {
      await DioClient.instance.post(
        ApiConstants.verifyEmailOtp,
        data: {'code': code},
      );

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AUTH] Verify OTP gagal: $e');
      _setError(_extractErrorMessage(e));
      return false;
    }
  }

  // ─── Logout ─────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    await SecureStorageService.clearAll();
    _backendToken = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ─── Private Helpers ────────────────────────────────────
  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  String _extractErrorMessage(dynamic error) {
    try {
      // Dio error dengan response dari backend
      if (error.toString().contains('message')) {
        final match = RegExp(r'"message":"([^"]+)"').firstMatch(error.toString());
        if (match != null) return match.group(1)!;
      }
    } catch (_) {}
    return 'Terjadi kesalahan. Coba lagi.';
  }
}
