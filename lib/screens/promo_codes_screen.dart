import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/promo_code.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class PromoCodesScreen extends StatelessWidget {
  const PromoCodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Promo Codes'),
      ),
      body: StreamBuilder<List<PromoCode>>(
        stream: firestoreService.getPromoCodesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final codes = snapshot.data ?? [];

          if (codes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_offer_outlined, size: 80, color: AppTheme.secondaryText),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Promo Codes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later for exclusive discounts and seasonal offers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.secondaryText),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24.0),
            itemCount: codes.length,
            itemBuilder: (context, index) {
              final promo = codes[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildVoucherCard(context, promo),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildVoucherCard(BuildContext context, PromoCode promo) {
    final expStr = '${promo.expiryDate.day}/${promo.expiryDate.month}/${promo.expiryDate.year}';
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDarkMode ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left Section - Accent Discount Tag
              Container(
                width: 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppTheme.isDarkMode
                        ? [const Color(0xFF2C2C2C), const Color(0xFF1E1E1E)]
                        : [AppTheme.primaryText, const Color(0xFF444444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${promo.discountPercentage.toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'OFF',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Custom Ticket Divider
              CustomPaint(
                size: const Size(1, double.infinity),
                painter: _TicketDividerPainter(color: Theme.of(context).dividerColor),
              ),

              // Right Section - Details & Copy Action
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  promo.code,
                                  style: TextStyle(
                                    color: AppTheme.accentColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: promo.code));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Promo code "${promo.code}" copied to clipboard!')),
                                  );
                                },
                                child: Icon(Icons.copy, size: 20, color: AppTheme.secondaryText),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            promo.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: AppTheme.secondaryText),
                          const SizedBox(width: 4),
                          Text(
                            'Expires: $expStr',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter to draw ticket dashed line
class _TicketDividerPainter extends CustomPainter {
  final Color color;

  _TicketDividerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double maxExtent = size.height;
    double dashHeight = 5;
    double dashSpace = 3;
    double currentY = 0;

    while (currentY < maxExtent) {
      canvas.drawLine(
        Offset(0, currentY),
        Offset(0, currentY + dashHeight),
        paint,
      );
      currentY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
