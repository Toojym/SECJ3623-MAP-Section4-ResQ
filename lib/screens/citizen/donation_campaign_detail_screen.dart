// SIGAP-39 — Donation Campaign Detail Screen
// Full detail view with animated progress ring, fund allocation breakdown,
// donation history, and sticky "Derma Sekarang" CTA.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../models/campaign_model.dart';
import '../../models/donation_model.dart';
import '../../services/firestore_service.dart';
import '../../services/receipt_service.dart';
import '../../widgets/donation/campaign_progress_widgets.dart';

class DonationCampaignDetailScreen extends StatefulWidget {
  final CampaignModel campaign;
  final bool openDonateOnLoad;

  const DonationCampaignDetailScreen({
    super.key,
    required this.campaign,
    this.openDonateOnLoad = false,
  });

  @override
  State<DonationCampaignDetailScreen> createState() =>
      _DonationCampaignDetailScreenState();
}

class _DonationCampaignDetailScreenState
    extends State<DonationCampaignDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  // Hold the latest campaign data from stream for live updates
  late CampaignModel _campaign;

  @override
  void initState() {
    super.initState();
    _campaign = widget.campaign;
    if (widget.openDonateOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDonationDialog(_campaign);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final uid = authState is AuthAuthenticated ? authState.uid : '';

    return StreamBuilder<DocumentSnapshot>(
      // Live update this campaign document
      stream: FirebaseFirestore.instance
          .collection('campaigns')
          .doc(_campaign.id)
          .snapshots(),
      builder: (context, camSnap) {
        if (camSnap.hasData && camSnap.data!.exists) {
          _campaign = CampaignModel.fromMap(
              camSnap.data!.id, camSnap.data!.data() as Map<String, dynamic>);
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProgressSection(),
                          const SizedBox(height: 28),
                          _buildStatsRow(),
                          const SizedBox(height: 28),
                          _buildPurposeSection(),
                          const SizedBox(height: 28),
                          _buildAllocationSection(),
                          const SizedBox(height: 28),
                          _buildDonationHistorySection(uid),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Sticky bottom bar
              if (!_campaign.isClosed) _buildStickyDonateBar(),
            ],
          ),
        );
      },
    );
  }

  // ─── Sliver App Bar ──────────────────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    final hue = (_campaign.name.hashCode.abs() % 360).toDouble();
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      backgroundColor: AppColors.primary,
      actions: [
        if (_campaign.isClosed)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text('Ditutup',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ],
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _campaign.imageUrl != null && _campaign.imageUrl!.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(_campaign.imageUrl!, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      HSLColor.fromAHSL(1, hue, 0.65, 0.40).toColor(),
                      HSLColor.fromAHSL(1, (hue + 40) % 360, 0.55, 0.55).toColor(),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(Icons.volunteer_activism_rounded,
                      size: 72, color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),
        title: Text(
          _campaign.name,
          style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ─── Progress Ring + Amount Section ─────────────────────────────────────────
  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          CampaignProgressRing(
            fraction: _campaign.progressFraction,
            size: 110,
            strokeWidth: 12,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_campaign.progressPercent}%',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _campaign.isClosed ? AppColors.textSecondary : AppColors.primary,
                  ),
                ),
                Text(
                  'Sasaran',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RM ${_fmtFull(_campaign.currentAmount)}',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _campaign.isClosed ? AppColors.textSecondary : AppColors.primary,
                  ),
                ),
                Text(
                  'terkumpul',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                CampaignProgressBar(
                  fraction: _campaign.progressFraction,
                  height: 8,
                  color: _campaign.isClosed ? AppColors.textSecondary : null,
                ),
                const SizedBox(height: 6),
                Text(
                  'Sasaran: RM ${_fmtFull(_campaign.targetAmount)}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats Row ───────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final daysActive = _campaign.createdAt != null
        ? DateTime.now().difference(_campaign.createdAt!).inDays
        : 0;

    return Row(
      children: [
        _statBox(Icons.calendar_today_rounded, '$daysActive', 'Hari Aktif',
            AppColors.primary),
        const SizedBox(width: 12),
        _statBox(
          Icons.savings_rounded,
          'RM ${_fmtShort(_campaign.targetAmount - _campaign.currentAmount)}',
          'Baki Diperlukan',
          AppColors.warning,
        ),
        const SizedBox(width: 12),
        _statBox(
          _campaign.isClosed ? Icons.lock_rounded : Icons.check_circle_rounded,
          _campaign.isClosed ? 'Tutup' : 'Aktif',
          'Status',
          _campaign.isClosed ? AppColors.textSecondary : AppColors.safe,
        ),
      ],
    );
  }

  Widget _statBox(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ─── Purpose Section ─────────────────────────────────────────────────────────
  Widget _buildPurposeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Tujuan Kempen'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Text(
            _campaign.purpose,
            style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.6),
          ),
        ),
      ],
    );
  }

  // ─── Fund Allocation Section ─────────────────────────────────────────────────
  Widget _buildAllocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Pengagihan Dana'),
        const SizedBox(height: 4),
        Text(
          'Peratus wang yang diagihkan kepada setiap kategori.',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: FundAllocationLegend(allocations: _campaign.allocations),
        ),
      ],
    );
  }

  // ─── Donation History Section ─────────────────────────────────────────────────
  Widget _buildDonationHistorySection(String uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Rekod Sumbangan Anda'),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.streamUserDonations(uid),
          builder: (context, snapshot) {
            final myDonations = snapshot.hasData
                ? (snapshot.data!.docs
                    .map((d) =>
                        DonationModel.fromMap(d.id, d.data() as Map<String, dynamic>))
                    .where((d) => d.campaignId == _campaign.id)
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
                : <DonationModel>[];

            if (myDonations.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite_border_rounded,
                        color: AppColors.textHint, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Belum Ada Sumbangan',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          Text('Sumbangan anda akan dipaparkan di sini.',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            final total = myDonations.fold(0.0, (s, d) => s + d.amount);
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite_rounded,
                            color: Colors.pink, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Jumlah Saya: RM ${total.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...myDonations.map((d) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.receipt_long_rounded,
                              size: 18, color: AppColors.primary),
                        ),
                        title: Text('RM ${d.amount.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        subtitle: Text(
                          '${d.paymentMethod} • ${_fmtDate(d.createdAt)}',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: TextButton(
                          onPressed: () => _showReceiptDialog(d),
                          child: Text('Resit',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ),
                      )),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─── Sticky Donate Bar ───────────────────────────────────────────────────────
  Widget _buildStickyDonateBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, -6))
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () => _showDonationDialog(_campaign),
          icon: const Icon(Icons.favorite_rounded, size: 20),
          label: Text('Derma Sekarang',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String title) {
    return Text(title,
        style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary));
  }

  String _fmtFull(double v) {
    // Always show 2 decimal places for currency
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}J';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  String _fmtShort(double v) {
    if (v < 0) return '0';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}J';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ─── Donate Dialog ───────────────────────────────────────────────────────────
  void _showDonationDialog(CampaignModel campaign) {
    String selectedMethod = 'FPX';
    bool isProcessing = false;
    final amountCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.displayName.isNotEmpty) {
      nameCtrl.text = authState.displayName;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.favorite_rounded, color: Colors.pink, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        campaign.name,
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Quick amount chips
                Text('Jumlah Cepat',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [10, 20, 50, 100, 200, 500].map((amt) {
                    return ActionChip(
                      label: Text('RM $amt'),
                      onPressed: () {
                        amountCtrl.text = amt.toString();
                        setModalState(() {});
                      },
                      backgroundColor: AppColors.primaryLight,
                      labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Penderma',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah Derma (RM)',
                    prefixText: 'RM ',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                Text('Kaedah Pembayaran',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  items: ['FPX', 'Kad Kredit / Debit']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedMethod = val);
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (selectedMethod == 'FPX') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    items: ['Maybank2U', 'CIMB Clicks', 'RHB Now', 'Bank Islam', 'Public Bank']
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (_) {},
                    decoration: InputDecoration(
                      labelText: 'Pilih Bank',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const TextField(
                    decoration: InputDecoration(labelText: 'Nombor Kad'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Expanded(child: TextField(decoration: InputDecoration(labelText: 'Luput (MM/YY)'))),
                      SizedBox(width: 8),
                      Expanded(child: TextField(decoration: InputDecoration(labelText: 'CVV'))),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                            final donorName = nameCtrl.text.trim();
                            if (amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sila masukkan jumlah yang sah.')));
                              return;
                            }
                            if (donorName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sila masukkan nama penderma.')));
                              return;
                            }
                            setModalState(() => isProcessing = true);
                            await Future.delayed(const Duration(seconds: 2));
                            if (!mounted) return;
                            final state = context.read<AuthBloc>().state;
                            if (state is AuthAuthenticated) {
                              final receiptNo = 'SIGAP-${DateTime.now().millisecondsSinceEpoch}';
                              final donation = DonationModel(
                                id: '',
                                campaignId: campaign.id,
                                campaignName: campaign.name,
                                citizenId: state.uid,
                                amount: amount,
                                paymentMethod: selectedMethod,
                                receiptNo: receiptNo,
                                createdAt: DateTime.now(),
                                donorName: donorName,
                              );
                              await _firestoreService.submitDonation(
                                  campaign.id, donation.toMap(), amount);
                              if (mounted) {
                                Navigator.pop(ctx);
                                _showReceiptDialog(donation);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text('Bayar Sekarang',
                            style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Receipt Dialog ──────────────────────────────────────────────────────────
  void _showReceiptDialog(DonationModel donation) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Menjana resit PDF...'),
          ],
        ),
      ),
    );
    try {
      final pdfFile = await ReceiptService.generateReceiptPdf(
        donorName: donation.donorName.isNotEmpty ? donation.donorName : 'Penderma',
        amount: donation.amount,
        campaignName: donation.campaignName,
        transactionId: donation.receiptNo,
        date: donation.createdAt,
        paymentMethod: donation.paymentMethod,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text('Sumbangan Berjaya!',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('RM ${donation.amount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const SizedBox(height: 4),
              Text(donation.campaignName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _receiptRow('No. Resit', donation.receiptNo),
                    _receiptRow('Tarikh', _fmtDate(donation.createdAt)),
                    _receiptRow('Kaedah', donation.paymentMethod),
                    _receiptRow('Penderma',
                        donation.donorName.isNotEmpty ? donation.donorName : 'N/A'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '★ Layak potongan cukai di bawah Subseksyen 44(6) Akta Cukai Pendapatan 1967.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () async =>
                  ReceiptService.shareReceipt(pdfFile, donation.receiptNo),
              icon: const Icon(Icons.share_rounded),
              label: const Text('Kongsi PDF'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal menjana resit: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textSecondary)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
