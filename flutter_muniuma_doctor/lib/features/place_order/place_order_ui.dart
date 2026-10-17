import 'package:flutter/material.dart';

const orderBlue = Color(0xFF007FFF);
const orderTitleBlue = Color(0xFF0081FF);
const orderPageBg = Color(0xFFEEF1F4);
const orderChipBg = Color(0xFFE8F5FF);
const orderChipOn = Color(0xFF0083FF);
const orderInk = Color(0xFF2C2C2E);
const orderMuted = Color(0xFF9F9F9F);
const orderFieldBg = Color(0xFFF7F8F9);

class OrderIcon extends StatelessWidget {
  const OrderIcon(
    this.name, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String name;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/place_order/$name.png',
      width: width,
      height: height,
      fit: fit,
    );
  }
}

class OrderBluePage extends StatelessWidget {
  const OrderBluePage({
    super.key,
    required this.title,
    required this.child,
    this.bottom,
    this.whiteTitle = true,
  });

  final String title;
  final Widget child;
  final Widget? bottom;
  final bool whiteTitle;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: orderPageBg,
      body: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 216,
            child: OrderIcon('icon_choice_hospital_img_bg', fit: BoxFit.cover),
          ),
          Column(
            children: [
              SizedBox(
                height: top + 44,
                child: Padding(
                  padding: EdgeInsets.only(top: top),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: whiteTitle ? Colors.white : orderInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          icon: OrderIcon(
                            whiteTitle ? 'icon_nav_back_white' : 'icon_nav_back',
                            width: 22,
                            height: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: child),
              ?bottom,
            ],
          ),
        ],
      ),
    );
  }
}

class ToothCrossView extends StatelessWidget {
  const ToothCrossView({
    super.key,
    required this.teeth,
    this.width = 145,
    this.height = 54,
  });

  final List<String> teeth;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: orderChipBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: orderTitleBlue),
      ),
      child: Stack(
        children: [
          const Align(
            alignment: Alignment.center,
            child: VerticalDivider(width: 1, thickness: 1, color: orderTitleBlue),
          ),
          const Align(
            alignment: Alignment.center,
            child: Divider(height: 1, thickness: 1, color: orderTitleBlue),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _quad(1, alignRight: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _quad(2, alignRight: false)),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _quad(4, alignRight: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _quad(3, alignRight: false)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quad(int quadrant, {required bool alignRight}) {
    final digits = teeth
        .where((item) => item.startsWith('$quadrant') && item.length > 1)
        .map((item) => item.substring(1))
        .toList()
      ..sort();
    if (alignRight) {
      digits.sort((a, b) => b.compareTo(a));
    }
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        digits.join(),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: const TextStyle(fontSize: 12, color: orderInk, height: 1),
      ),
    );
  }
}

class OrderChoiceButton extends StatelessWidget {
  const OrderChoiceButton({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 28,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: selected ? orderChipOn : orderChipBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : const Color(0xFF2395FF),
              ),
            ),
          ),
          if (selected)
            const Positioned(
              right: -1,
              bottom: -1,
              child: OrderIcon('icon_placeOrder_common_choice', width: 14, height: 14),
            ),
        ],
      ),
    );
  }
}
