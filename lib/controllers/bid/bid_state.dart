import 'package:equatable/equatable.dart';

import '../../models/bid.dart';

enum BidStatusFilter { all, pending, accepted, rejected }

enum BidViewStatus { initial, loading, loaded, error }

class BidState extends Equatable {
  const BidState({
    this.bids = const <Bid>[],
    this.status = BidViewStatus.initial,
    this.errorMessage,
    this.filter = BidStatusFilter.all,
  });

  final List<Bid> bids;
  final BidViewStatus status;
  final String? errorMessage;
  final BidStatusFilter filter;

  List<Bid> get visibleBids {
    switch (filter) {
      case BidStatusFilter.all:
        return bids;
      case BidStatusFilter.pending:
        return bids.where((bid) => bid.status == BidStatus.pending).toList();
      case BidStatusFilter.accepted:
        return bids.where((bid) => bid.status == BidStatus.accepted).toList();
      case BidStatusFilter.rejected:
        return bids.where((bid) => bid.status == BidStatus.rejected).toList();
    }
  }

  BidState copyWith({
    List<Bid>? bids,
    BidViewStatus? status,
    String? errorMessage,
    BidStatusFilter? filter,
    bool clearError = false,
  }) {
    return BidState(
      bids: bids ?? this.bids,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      filter: filter ?? this.filter,
    );
  }

  @override
  List<Object?> get props => [bids, status, errorMessage, filter];
}
