import 'package:flutter/material.dart';

/// Maps backend [InquiryIssue.icon_key] to Material icons.
IconData inquiryIssueIcon(String? key) {
  switch (key) {
    case 'account_balance_wallet':
      return Icons.account_balance_wallet_rounded;
    case 'health_and_safety':
      return Icons.health_and_safety_rounded;
    case 'lock_open':
      return Icons.lock_open_rounded;
    case 'local_shipping':
      return Icons.local_shipping_rounded;
    case 'bug_report':
      return Icons.bug_report_rounded;
    case 'support_agent':
      return Icons.support_agent_rounded;
    case 'electric_bike':
      return Icons.electric_bike_rounded;
    case 'electric_scooter':
      return Icons.electric_scooter_rounded;
    case 'ev_station':
      return Icons.ev_station_rounded;
    case 'person':
      return Icons.person_rounded;
    case 'feedback':
      return Icons.feedback_rounded;
    case 'forward_to_inbox':
      return Icons.forward_to_inbox_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}
