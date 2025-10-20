import 'package:equatable/equatable.dart';

import '../../models/payment.dart';
import '../../services/wallet_service.dart';

enum WalletViewStatus { initial, loading, loaded, error }

typedef PaymentId = String;

typedef ReleaseErrors = Map<PaymentId, String>;

class WalletState extends Equatable {
  const WalletState({
    this.status = WalletViewStatus.initial,
    this.summary,
    this.payments = const <Payment>[],
    this.errorMessage,
    this.releaseErrors = const <PaymentId, String>{},
    this.releasing = const <PaymentId>{},
    this.successMessage,
  });

  final WalletViewStatus status;
  final WalletSummary? summary;
  final List<Payment> payments;
  final String? errorMessage;
  final ReleaseErrors releaseErrors;
  final Set<PaymentId> releasing;
  final String? successMessage;

  bool get isLoading => status == WalletViewStatus.loading;
  bool get isLoaded => status == WalletViewStatus.loaded;

  WalletState copyWith({
    WalletViewStatus? status,
    WalletSummary? summary,
    List<Payment>? payments,
    String? errorMessage,
    ReleaseErrors? releaseErrors,
    Set<PaymentId>? releasing,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return WalletState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      payments: payments ?? this.payments,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      releaseErrors: releaseErrors ?? this.releaseErrors,
      releasing: releasing ?? this.releasing,
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  WalletState withReleaseStart(PaymentId id) {
    return copyWith(
      releasing: {...releasing, id},
      releaseErrors: {...releaseErrors}..remove(id),
      clearSuccess: true,
      clearError: true,
    );
  }

  WalletState withReleaseResult(Payment payment, {String? error}) {
    final paymentsMap = Map<PaymentId, Payment>.fromEntries(
      payments.map((existingPayment) => MapEntry(existingPayment.id, existingPayment)),
    );
    paymentsMap[payment.id] = payment;
    final currentSummary = summary;
    var updatedSummary = currentSummary;
    if (currentSummary != null) {
      var pending = currentSummary.pending;
      var released = currentSummary.released;
      if (payment.isReleased) {
        pending = (pending - payment.amount).clamp(0, double.infinity);
        released = released + payment.amount;
      }
      updatedSummary = WalletSummary(
        balance: currentSummary.balance,
        pending: pending,
        released: released,
        withdrawn: currentSummary.withdrawn,
      );
    }
    return copyWith(
      payments: paymentsMap.values.toList(growable: false),
      releaseErrors: {
        ...releaseErrors,
        if (error != null) payment.id: error,
      },
      releasing: {...releasing}..remove(payment.id),
      summary: updatedSummary,
      successMessage: error == null ? 'Payment released successfully.' : successMessage,
      clearSuccess: error != null,
    );
  }

  @override
  List<Object?> get props => [
        status,
        summary,
        payments,
        errorMessage,
        releaseErrors,
        releasing,
        successMessage,
      ];
}
