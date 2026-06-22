import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/awanis_service.dart';
import 'package:easy_localization/easy_localization.dart';

class AwanisChatScreen extends StatefulWidget {
  const AwanisChatScreen({super.key});

  @override
  State<AwanisChatScreen> createState() => _AwanisChatScreenState();
}

class _AwanisChatScreenState extends State<AwanisChatScreen> {
  final _service = AwanisService();
  final _msgCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'isBot': true,
      'text': 'Hai, saya AWANIS. AI Pembantu Bencana anda. Apa yang boleh saya bantu hari ini? Anda boleh tanya saya dalam Bahasa Malaysia atau English.'.tr(),
    });
  }

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'isBot': false, 'text': text});
      _isLoading = true;
    });
    _msgCtrl.clear();

    final response = await _service.chatWithCitizen(text);
    
    if (mounted) {
      setState(() {
        _messages.add({'isBot': true, 'text': response});
        _isLoading = false;
      });
    }
  }

  void _sendQuickQuery(String query) {
    _msgCtrl.text = query;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.smart_toy_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('AWANIS'.tr(), style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          _buildQuickAccessChips(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isBot = msg['isBot'] as bool;
                return _buildChatBubble(msg['text'] as String, isBot);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isBot) {
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isBot ? Colors.white : AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isBot ? const Radius.circular(0) : const Radius.circular(16),
            bottomRight: isBot ? const Radius.circular(16) : const Radius.circular(0),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: isBot ? AppColors.textPrimary : Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                decoration: InputDecoration(
                  hintText:'Tanya soalan kecemasan...'.tr(),
                  hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessChips() {
    final quickQuestions = [
      {
        'icon': '🚨', 
        'label': 'Hantar SOS'.tr(), 
        'query': 'Macam mana nak hantar SOS?'.tr(),
        'color': AppColors.danger,
      },
      {
        'icon': '👥', 
        'label': 'Keluarga saya'.tr(), 
        'query': 'Bagaimana nak kesan keselamatan keluarga saya?'.tr(),
        'color': AppColors.safe,
      },
      {
        'icon': '📍', 
        'label': 'Pusat pemindahan'.tr(), 
        'query': 'Di mana pusat pemindahan (PPS) terdekat?'.tr(),
        'color': AppColors.warning,
      },
      {
        'icon': '🌧️', 
        'label': 'Status cuaca'.tr(), 
        'query': 'Boleh berikan amaran cuaca terkini?'.tr(),
        'color': AppColors.primary,
      },
    ];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: quickQuestions.map((q) {
            final color = q['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _sendQuickQuery(q['query'] as String),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(q['icon'] as String, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          q['label'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
