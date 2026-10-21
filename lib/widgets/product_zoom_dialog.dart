import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

void showProductZoomDialog(BuildContext context, String imageUrl, String productName) {
  if (imageUrl.trim().isEmpty) return;
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // خلفية سوداء شفافة قابلة للإغلاق
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              color: Colors.black.withOpacity(0.9),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // الصورة مع إمكانية التكبير والتصحيح
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
                errorWidget: (_, __, ___) => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image, color: Colors.white, size: 60),
                    SizedBox(height: 8),
                    Text('تعذر تحميل الصورة', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          // اسم المنتج وزر الإغلاق في الأعلى
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    productName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
