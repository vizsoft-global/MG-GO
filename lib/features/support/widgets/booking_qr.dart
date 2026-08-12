import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';

/// Reception check-in QR for a visit booking (Figma RSup/15, RSup/16).
///
/// Encodes `visit_bookings.booking_code` verbatim — no prefix, no URL. The
/// admin ticket (`visit-detail-page-shell.tsx`) renders `QRCodeSVG
/// value={visit.booking_code} level="M"`, and reception matches the scanned
/// text against `booking_code`, so any decoration here would resolve to no
/// booking. Callers must not pass a placeholder when the code is missing.
class BookingQr extends StatelessWidget {
  const BookingQr({required this.bookingCode, this.size = 88, super.key});

  final String bookingCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: QrImageView(
        data: bookingCode,
        size: size,
        // Explicit white keeps the quiet zone opaque; QrImageView defaults to
        // a transparent background, which scanners read as low contrast.
        backgroundColor: AppColors.white,
        padding: const EdgeInsets.all(8),
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      ),
    );
  }
}
