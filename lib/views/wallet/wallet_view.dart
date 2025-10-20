import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../controllers/wallet/wallet_cubit.dart';
import '../../controllers/wallet/wallet_state.dart';
import '../../models/payment.dart';
import '../../services/storage_service.dart';
import '../../services/wallet_service.dart';

class WalletView extends StatefulWidget {
  const WalletView({super.key});

  static const routeName = '/wallet';

  @override
  State<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<WalletView> {
  StorageService get _storage => RepositoryProvider.of<StorageService>(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletCubit>().load();
    });
  }

  bool get _canRelease => _storage.role == 'client' ||
      _storage.getUser()?.role.toLowerCase() == 'client';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: BlocConsumer<WalletCubit, WalletState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.successMessage!)),
            );
          }
        },
        builder: (context, state) {
          if (state.status == WalletViewStatus.loading && state.summary == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == WalletViewStatus.error && state.summary == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(state.errorMessage ?? 'Unable to load wallet.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.read<WalletCubit>().load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final summary = state.summary;
          final payments = state.payments;
          return RefreshIndicator(
            onRefresh: () => context.read<WalletCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (summary != null)
                  _WalletSummaryCard(summary: summary),
                const SizedBox(height: 24),
                Text(
                  'Transactions',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (payments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'No payments yet',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Completed contracts will appear here.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  ...payments.map(
                    (payment) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text('Job #${payment.jobId}'),
                        subtitle: Text(payment.status.label),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '\$${payment.amount.toStringAsFixed(2)}',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (state.releasing.contains(payment.id))
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            else if (payment.status == PaymentStatus.pending && _canRelease)
                              TextButton(
                                onPressed: () => context.read<WalletCubit>().releasePayment(payment.id),
                                child: const Text('Release Payment'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({required this.summary});

  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Balance', style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            '\$${summary.balance.toStringAsFixed(2)}',
            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryStat(label: 'Pending (Escrow)', value: summary.pending),
              _SummaryStat(label: 'Released', value: summary.released),
              _SummaryStat(label: 'Withdrawn', value: summary.withdrawn),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
