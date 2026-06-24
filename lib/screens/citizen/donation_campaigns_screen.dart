// SIGAP-38 — Browse Active Donation Campaigns
// Full-screen campaign browser for citizens with search, progress bars, and donate entry point.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';

import '../../models/campaign_model.dart';
import '../../models/donation_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/donation/campaign_progress_widgets.dart';
import 'donation_campaign_detail_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class DonationCampaignsScreen extends StatefulWidget {
  const DonationCampaignsScreen({super.key});

  @override
  State<DonationCampaignsScreen> createState() => _DonationCampaignsScreenState();
}

class _DonationCampaignsScreenState extends State<DonationCampaignsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';
  String _filterStatus = 'Semua'.tr(); // 'Semua'.tr(), 'Aktif'.tr(), 'Ditutup'.tr()

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final uid = authState is AuthAuthenticated ? authState.uid : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.streamUserDonations(uid),
        builder: (context, donationSnapshot) {
          // Build user donation map: campaignId → total donated
          final Map<String, double> userDonatedMap = {};
          if (donationSnapshot.hasData) {
            for (final doc in donationSnapshot.data!.docs) {
              final d = DonationModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
              userDonatedMap[d.campaignId] = (userDonatedMap[d.campaignId] ?? 0) + d.amount;
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.streamActiveCampaigns(),
            builder: (context, snapshot) {
              return CustomScrollView(
                slivers: [
                  _buildSliverAppBar(snapshot, userDonatedMap),
                  SliverToBoxAdapter(
                    child: _buildSearchAndFilter(),
                  ),
                  _buildCampaignSliver(snapshot, userDonatedMap),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ─── Sliver App Bar with gradient hero ──────────────────────────────────────
  Widget _buildSliverAppBar(
    AsyncSnapshot<QuerySnapshot> snapshot,
    Map<String, double> userDonatedMap,
  ) {
    // Compute totals for the stats strip
    double totalRaised = 0;
    int activeCampaigns = 0;
    if (snapshot.hasData) {
      for (final doc in snapshot.data!.docs) {
        final c = CampaignModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
        if (!c.isClosed) {
          totalRaised += c.currentAmount;
          activeCampaigns++;
        }
      }
    }

    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'Tabung Bantuan'.tr(),
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tabung Bantuan'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sumbangkan untuk membantu mangsa bencana'.tr(),
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _statChip(
                        Icons.volunteer_activism_rounded,
                        'rmCollected'.tr(args: [_formatAmount(totalRaised)]),
                      ),
                      const SizedBox(width: 10),
                      _statChip(
                        Icons.campaign_rounded,
                        '$activeCampaigns kempen aktif',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ─── Search + Filter bar ─────────────────────────────────────────────────────
  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText:'Cari kempen...'.tr(),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Semua'.tr(), 'Aktif'.tr(), 'Ditutup'.tr()].map((f) {
                final selected = _filterStatus == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) => setState(() => _filterStatus = f),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Campaign List Sliver ────────────────────────────────────────────────────
  Widget _buildCampaignSliver(
    AsyncSnapshot<QuerySnapshot> snapshot,
    Map<String, double> userDonatedMap,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    // Parse + sort + filter
    var campaigns = snapshot.data!.docs
        .map((doc) => CampaignModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .where((c) {
          bool isClosed = c.isClosed || c.currentAmount >= c.targetAmount;
          if (_filterStatus == 'Aktif'.tr()) return !isClosed;
          if (_filterStatus == 'Ditutup'.tr()) return isClosed;
          return true;
        })
        .where((c) =>
            _searchQuery.isEmpty ||
            c.name.toLowerCase().contains(_searchQuery) ||
            c.purpose.toLowerCase().contains(_searchQuery))
        .toList()
      ..sort((a, b) {
        // Active first, then by creation date
        bool aClosed = a.isClosed || a.currentAmount >= a.targetAmount;
        bool bClosed = b.isClosed || b.currentAmount >= b.targetAmount;
        if (aClosed != bClosed) return aClosed ? 1 : -1;
        final at = a.createdAt ?? DateTime(2000);
        final bt = b.createdAt ?? DateTime(2000);
        return bt.compareTo(at);
      });

    if (campaigns.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _CampaignCard(
              campaign: campaigns[index],
              userDonated: userDonatedMap[campaigns[index].id] ?? 0,
              onTap: () => _openDetail(campaigns[index]),
              onDonate: () => _openDetailAndDonate(campaigns[index]),
            ),
          ),
          childCount: campaigns.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volunteer_activism_rounded, size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Tiada Kempen Dijumpai'.tr(),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tiada kempen derma yang sepadan dengan carian anda.'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(CampaignModel campaign) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AuthBloc>(),
          child: DonationCampaignDetailScreen(campaign: campaign),
        ),
      ),
    );
  }

  void _openDetailAndDonate(CampaignModel campaign) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AuthBloc>(),
          child: DonationCampaignDetailScreen(campaign: campaign, openDonateOnLoad: true),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}J';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Campaign Card Widget
// ═══════════════════════════════════════════════════════════════════════════════

class _CampaignCard extends StatelessWidget {
  final CampaignModel campaign;
  final double userDonated;
  final VoidCallback onTap;
  final VoidCallback onDonate;

  const _CampaignCard({
    required this.campaign,
    required this.userDonated,
    required this.onTap,
    required this.onDonate,
  });

  @override
  Widget build(BuildContext context) {
    final progress = campaign.progressFraction;
    final isClosed = campaign.isClosed || campaign.currentAmount >= campaign.targetAmount;
    final hasDonated = userDonated > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: isClosed
              ? Border.all(color: AppColors.divider)
              : (hasDonated
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)
                  : null),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image or gradient banner
            _buildBanner(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row + badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          campaign.name,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isClosed)
                        _badge('Ditutup'.tr(), AppColors.textSecondary, Icons.lock_rounded)
                      else if (hasDonated)
                        _badge('Penderma'.tr(), Colors.amber.shade700, Icons.verified_rounded),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    campaign.purpose,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),

                  // Amount row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RM ${_fmt(campaign.currentAmount)}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isClosed ? AppColors.textSecondary : AppColors.primary,
                            ),
                          ),
                          Text(
                            'fromRm'.tr(args: [_fmt(campaign.targetAmount)]),
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isClosed
                              ? AppColors.background
                              : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${campaign.progressPercent}%',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isClosed ? AppColors.textSecondary : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Progress bar
                  CampaignProgressBar(
                    fraction: progress,
                    height: 8,
                    color: isClosed ? AppColors.textSecondary : null,
                  ),
                  const SizedBox(height: 14),

                  // Allocation chips
                  if (campaign.allocations.isNotEmpty) ...[
                    AllocationChipRow(allocations: campaign.allocations),
                    const SizedBox(height: 14),
                  ],

                  // Action row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onTap,
                          icon: const Icon(Icons.info_outline_rounded, size: 16),
                          label: Text('Butiran'.tr()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      if (!isClosed) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onDonate,
                            icon: const Icon(Icons.favorite_rounded, size: 16),
                            label: Text('Derma'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    if (campaign.imageUrl != null && campaign.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Image.network(
          campaign.imageUrl!,
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _gradientBanner(),
        ),
      );
    }
    return _gradientBanner();
  }

  Widget _gradientBanner() {
    // Generate a consistent gradient from campaign name hash
    final hue = (campaign.name.hashCode.abs() % 360).toDouble();
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        gradient: LinearGradient(
          colors: [
            HSLColor.fromAHSL(1, hue, 0.65, 0.45).toColor(),
            HSLColor.fromAHSL(1, (hue + 40) % 360, 0.55, 0.60).toColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.volunteer_activism_rounded, size: 48, color: Colors.white.withValues(alpha: 0.85)),
      ),
    );
  }

  Widget _badge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}J';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}
