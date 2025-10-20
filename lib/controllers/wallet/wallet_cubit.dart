import 'package:bloc/bloc.dart';

import '../../models/payment.dart';
import '../../services/wallet_service.dart';
import 'wallet_state.dart';

class WalletCubit extends Cubit<WalletState> {
  WalletCubit(this._walletService) : super(const WalletState());

  final WalletService _walletService;

  Future<void> load() async {
    emit(state.copyWith(status: WalletViewStatus.loading, clearError: true, clearSuccess: true));
    try {
      final summary = await _walletService.fetchSummary();
      final payments = await _walletService.fetchPayments();
      emit(
        state.copyWith(
          status: WalletViewStatus.loaded,
          summary: summary,
          payments: payments,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: WalletViewStatus.error,
          errorMessage: 'Unable to load wallet at the moment.',
        ),
      );
    }
  }

  Future<void> releasePayment(String paymentId) async {
    emit(state.withReleaseStart(paymentId));
    try {
      final payment = await _walletService.releasePayment(paymentId);
      emit(state.withReleaseResult(payment));
    } catch (error) {
      final existing = state.payments.firstWhere(
        (payment) => payment.id == paymentId,
        orElse: () => Payment(
          id: paymentId,
          jobId: '',
          amount: 0,
          status: PaymentStatus.pending,
          updatedAt: DateTime.now(),
        ),
      );
      emit(state.withReleaseResult(existing, error: 'Failed to release payment.'));
    }
  }
}
