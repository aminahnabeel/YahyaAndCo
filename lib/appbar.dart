import 'package:flutter/material.dart';

import 'services/localization_service.dart';
import 'theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.language,
      builder: (context, currentLanguage, _) {
        return AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          centerTitle: true,
          title: Text(
            LocalizationService.instance.t('enter_phone'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: PopupMenuButton<String>(
                initialValue: currentLanguage,
                onSelected: (value) {
                  LocalizationService.instance.setLanguage(value);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'en',
                    child: Text(LocalizationService.instance.t('english')),
                  ),
                  PopupMenuItem<String>(
                    value: 'roman',
                    child: Text(LocalizationService.instance.t('roman')),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.public, size: 18, color: Colors.black),
                      const SizedBox(width: 6),
                      Text(
                        currentLanguage == 'en'
                            ? LocalizationService.instance.t('english_short')
                            : LocalizationService.instance.t('roman_short'),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
