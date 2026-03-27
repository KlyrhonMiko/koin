import 'package:flutter/material.dart';

class IconUtils {
  static final Map<int, IconData> _iconMap = {
    // Categories
    Icons.shopping_cart.codePoint: Icons.shopping_cart,
    Icons.restaurant.codePoint: Icons.restaurant,
    Icons.directions_car.codePoint: Icons.directions_car,
    Icons.attach_money.codePoint: Icons.attach_money,
    Icons.movie.codePoint: Icons.movie,
    Icons.local_hospital.codePoint: Icons.local_hospital,
    Icons.category.codePoint: Icons.category,
    Icons.home.codePoint: Icons.home,
    Icons.work.codePoint: Icons.work,
    Icons.school.codePoint: Icons.school,
    Icons.fitness_center.codePoint: Icons.fitness_center,
    Icons.flight.codePoint: Icons.flight,
    Icons.pets.codePoint: Icons.pets,
    Icons.payments.codePoint: Icons.payments,
    Icons.account_balance.codePoint: Icons.account_balance,
    Icons.savings.codePoint: Icons.savings,
    Icons.electrical_services.codePoint: Icons.electrical_services,
    Icons.water_drop.codePoint: Icons.water_drop,
    Icons.wifi.codePoint: Icons.wifi,
    Icons.phone_android.codePoint: Icons.phone_android,
    Icons.celebration.codePoint: Icons.celebration,
    Icons.card_giftcard.codePoint: Icons.card_giftcard,
    Icons.coffee.codePoint: Icons.coffee,
    Icons.fastfood.codePoint: Icons.fastfood,
    
    // Rounded icons for accounts
    Icons.account_balance_wallet_rounded.codePoint: Icons.account_balance_wallet_rounded,
    Icons.account_balance_rounded.codePoint: Icons.account_balance_rounded,
    Icons.savings_rounded.codePoint: Icons.savings_rounded,
    Icons.payments_rounded.codePoint: Icons.payments_rounded,
    Icons.credit_card_rounded.codePoint: Icons.credit_card_rounded,
    Icons.wallet_rounded.codePoint: Icons.wallet_rounded,
    Icons.money_rounded.codePoint: Icons.money_rounded,
    Icons.currency_exchange_rounded.codePoint: Icons.currency_exchange_rounded,
    Icons.trending_up_rounded.codePoint: Icons.trending_up_rounded,
    Icons.monetization_on_rounded.codePoint: Icons.monetization_on_rounded,
    Icons.paid_rounded.codePoint: Icons.paid_rounded,
    Icons.local_atm_rounded.codePoint: Icons.local_atm_rounded,
    Icons.request_quote_rounded.codePoint: Icons.request_quote_rounded,
    Icons.account_tree_rounded.codePoint: Icons.account_tree_rounded,
    Icons.business_center_rounded.codePoint: Icons.business_center_rounded,
    Icons.storefront_rounded.codePoint: Icons.storefront_rounded,
    Icons.currency_bitcoin_rounded.codePoint: Icons.currency_bitcoin_rounded,
    Icons.currency_pound_rounded.codePoint: Icons.currency_pound_rounded,
    Icons.currency_yen_rounded.codePoint: Icons.currency_yen_rounded,
    Icons.currency_franc_rounded.codePoint: Icons.currency_franc_rounded,
    
    // Other common icons
    Icons.help_outline.codePoint: Icons.help_outline,
    Icons.arrow_upward_rounded.codePoint: Icons.arrow_upward_rounded,
    Icons.arrow_downward_rounded.codePoint: Icons.arrow_downward_rounded,
    Icons.swap_horiz_rounded.codePoint: Icons.swap_horiz_rounded,
    Icons.insights_rounded.codePoint: Icons.insights_rounded,
    Icons.pie_chart_rounded.codePoint: Icons.pie_chart_rounded,
    Icons.account_balance_wallet_outlined.codePoint: Icons.account_balance_wallet_outlined,
    Icons.receipt_long_outlined.codePoint: Icons.receipt_long_outlined,
  };

  static IconData getIcon(int codePoint) {
    return _iconMap[codePoint] ?? Icons.help_outline;
  }
}
