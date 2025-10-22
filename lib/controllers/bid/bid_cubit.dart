import 'package:bloc/bloc.dart';

import '../../models/bid.dart';
import '../../services/bid_service.dart';
import 'bid_state.dart';

class BidCubit extends Cubit<BidState> {
  BidCubit(this._bidService, {required this.jobId}) : super(const BidState());

  final BidService _bidService;
  final String jobId;

  Future<void> load() async {
    emit(state.copyWith(status: BidViewStatus.loading, clearError: true));
    try {
      final bids = await _bidService.fetchBids(jobId);
      emit(
        state.copyWith(
          status: BidViewStatus.loaded,
          bids: bids,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: BidViewStatus.error,
          errorMessage: 'Unable to load bids.',
        ),
      );
    }
  }

  Future<void> submitBid(
      {required double amount, required String message}) async {
    emit(state.copyWith(status: BidViewStatus.loading, clearError: true));
    try {
      final bid = await _bidService.submitBid(
          jobId: jobId, amount: amount, message: message);
      emit(
        state.copyWith(
          status: BidViewStatus.loaded,
          bids: [bid, ...state.bids],
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: BidViewStatus.error,
          errorMessage: 'Unable to submit bid.',
        ),
      );
    }
  }

  Future<void> acceptBid(Bid bid) async {
    await _transitionBid(
      bid,
      (bidId) => _bidService.acceptBid(jobId, bidId),
      successStatus: BidStatus.accepted,
    );
  }

  Future<void> rejectBid(Bid bid) async {
    await _transitionBid(
      bid,
      (bidId) => _bidService.rejectBid(jobId, bidId),
      successStatus: BidStatus.rejected,
    );
  }

  Future<void> _transitionBid(
      Bid bid, Future<Bid> Function(String bidId) transition,
      {required BidStatus successStatus}) async {
    emit(state.copyWith(status: BidViewStatus.loading, clearError: true));
    try {
      final updated = await transition(bid.id);
      final bids =
          state.bids.map((item) => item.id == bid.id ? updated : item).toList();
      emit(state.copyWith(status: BidViewStatus.loaded, bids: bids));
    } catch (error) {
      emit(
        state.copyWith(
          status: BidViewStatus.error,
          errorMessage: 'Unable to update bid.',
        ),
      );
    }
  }

  void changeFilter(BidStatusFilter filter) {
    if (state.filter == filter) return;
    emit(state.copyWith(filter: filter));
  }
}
