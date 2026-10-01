import 'package:flutter/material.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/accounts/accounts_tab.dart';

/// Top-level screen for viewing and managing accounts, delegating to AccountsTab.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: const Text('Accounts'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AccountsTab(
        animationSessionKey: DateTime.now().millisecondsSinceEpoch.toString(),
        showEntranceAnimations: false,
      ),
    );
  }
}
