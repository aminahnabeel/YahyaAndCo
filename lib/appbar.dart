import 'package:flutter/material.dart';

import 'services/localization_service.dart';
import 'theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.titleKey = 'enter_phone',
    this.showLanguageSelector = true,
    this.showBackButton = true,
    this.backAction,
  });

  final String titleKey;
  final bool showLanguageSelector;
  final bool showBackButton;
  final VoidCallback? backAction;

  @override
  Size get preferredSize => const Size.fromHeight(60);

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
          titleSpacing: 0,
          leadingWidth: showBackButton ? 52 : 0,
          leading: showBackButton
              ? IconButton(
                  onPressed: backAction ?? () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  splashRadius: 22,
                )
              : null,
          title: Text(
            LocalizationService.instance.t(titleKey),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: showLanguageSelector
              ? [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.public, size: 16, color: Colors.black),
                            const SizedBox(width: 4),
                            Text(
                              currentLanguage == 'en'
                                  ? LocalizationService.instance.t('english_short')
                                  : LocalizationService.instance.t('roman_short'),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                  ),
                ]
              : null,
        );
      },
    );
  }
}
