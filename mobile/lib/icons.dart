import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Heroicons 图标工具类
/// 统一加载 SVG 图标，保持一致的风格和尺寸
class HeroIcons {
  static const String _path = 'assets/icons/';

  /// 加载 SVG 图标
  static Widget icon(
    String name, {
    double size = 24,
    Color? color,
  }) {
    return SvgPicture.asset(
      '$_path$name.svg',
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color, BlendMode.srcIn)
          : null,
    );
  }

  // 预定义的常用图标
  static Widget shoppingBag({double size = 24, Color? color}) =>
      icon('shopping-bag', size: size, color: color);

  static Widget envelope({double size = 24, Color? color}) =>
      icon('envelope', size: size, color: color);

  static Widget lockClosed({double size = 24, Color? color}) =>
      icon('lock-closed', size: size, color: color);

  static Widget magnifyingGlass({double size = 24, Color? color}) =>
      icon('magnifying-glass', size: size, color: color);

  static Widget bolt({double size = 24, Color? color}) =>
      icon('bolt', size: size, color: color);

  static Widget globeAlt({double size = 24, Color? color}) =>
      icon('globe-alt', size: size, color: color);

  static Widget chatBubble({double size = 24, Color? color}) =>
      icon('chat-bubble-left-ellipsis', size: size, color: color);

  static Widget user({double size = 24, Color? color}) =>
      icon('user', size: size, color: color);

  static Widget photo({double size = 24, Color? color}) =>
      icon('photo', size: size, color: color);

  static Widget bugAnt({double size = 24, Color? color}) =>
      icon('bug-ant', size: size, color: color);

  static Widget bell({double size = 24, Color? color}) =>
      icon('bell', size: size, color: color);

  static Widget trash({double size = 24, Color? color}) =>
      icon('trash', size: size, color: color);

  static Widget chatBubbleAlt({double size = 24, Color? color}) =>
      icon('chat-bubble-left-right', size: size, color: color);

  static Widget heart({double size = 24, Color? color}) =>
      icon('heart', size: size, color: color);

  static Widget clock({double size = 24, Color? color}) =>
      icon('clock', size: size, color: color);

  static Widget mapPin({double size = 24, Color? color}) =>
      icon('map-pin', size: size, color: color);

  static Widget gift({double size = 24, Color? color}) =>
      icon('gift', size: size, color: color);

  static Widget currencyDollar({double size = 24, Color? color}) =>
      icon('currency-dollar', size: size, color: color);

  static Widget cog({double size = 24, Color? color}) =>
      icon('cog-6-tooth', size: size, color: color);

  static Widget questionCircle({double size = 24, Color? color}) =>
      icon('question-mark-circle', size: size, color: color);

  static Widget creditCard({double size = 24, Color? color}) =>
      icon('credit-card', size: size, color: color);

  static Widget cube({double size = 24, Color? color}) =>
      icon('cube', size: size, color: color);

  static Widget star({double size = 24, Color? color}) =>
      icon('star', size: size, color: color);

  static Widget pencil({double size = 24, Color? color}) =>
      icon('pencil', size: size, color: color);

  static Widget chevronRight({double size = 24, Color? color}) =>
      icon('chevron-right', size: size, color: color);
}
