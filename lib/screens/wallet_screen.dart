import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    required this.apiBaseUrl,
    required this.apiAccessKey,
    required this.accessToken,
    this.languageCode = 'en',
  });

  final String apiBaseUrl;
  final String apiAccessKey;
  final String accessToken;
  final String languageCode;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _loading = true;
  bool _applyingReferral = false;
  bool _hasRedeemedReferral = false;
  String? _loadError;
  int _walletBalanceCredits = 0;
  String _myReferralCode = '';
  final List<Map<String, dynamic>> _walletTransactions = [];
  final TextEditingController _applyReferralController =
      TextEditingController();
  final TextEditingController _withdrawAmountController = TextEditingController(
    text: '100',
  );
  final TextEditingController _withdrawUpiController = TextEditingController();
  final TextEditingController _withdrawNoteController = TextEditingController();
  bool get _isHindi => widget.languageCode.toLowerCase().startsWith('hi');
  String _tr(String en, String hi) => _isHindi ? hi : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _applyReferralController.dispose();
    _withdrawAmountController.dispose();
    _withdrawUpiController.dispose();
    _withdrawNoteController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final Uri walletUri = Uri.parse('${widget.apiBaseUrl}/api/v1/wallet/me');
      final http.Response walletRes = await http.get(
        walletUri,
        headers: <String, String>{
          'X-API-Key': widget.apiAccessKey,
          'Authorization': 'Bearer ${widget.accessToken}',
        },
      );
      if (!mounted) return;
      if (walletRes.statusCode != 200) {
        setState(() {
          _loading = false;
          _loadError = _tr(
            'Wallet load failed (${walletRes.statusCode}).',
            'वॉलेट लोड नहीं हुआ (${walletRes.statusCode})।',
          );
        });
        return;
      }
      final dynamic walletDecoded = jsonDecode(walletRes.body);
      if (walletDecoded is! Map<String, dynamic>) {
        setState(() {
          _loading = false;
          _loadError = _tr(
            'Invalid wallet response.',
            'वॉलेट का जवाब अमान्य है।',
          );
        });
        return;
      }
      final dynamic walletRaw = walletDecoded['wallet'];
      final dynamic txRaw = walletDecoded['recent_transactions'];
      final int balance =
          (walletRaw is Map<String, dynamic> &&
              walletRaw['balance_credits'] is int)
          ? walletRaw['balance_credits'] as int
          : int.tryParse(
                  '${(walletRaw is Map<String, dynamic>) ? walletRaw['balance_credits'] : 0}',
                ) ??
                0;
      final List<Map<String, dynamic>> txList = <Map<String, dynamic>>[];
      if (txRaw is List<dynamic>) {
        for (final dynamic item in txRaw) {
          if (item is Map<String, dynamic>) {
            txList.add(item);
          }
        }
      }

      final Uri referralMeUri = Uri.parse(
        '${widget.apiBaseUrl}/api/v1/referral/me',
      );
      final http.Response referralRes = await http.get(
        referralMeUri,
        headers: <String, String>{
          'X-API-Key': widget.apiAccessKey,
          'Authorization': 'Bearer ${widget.accessToken}',
        },
      );
      String nextCode = _myReferralCode;
      if (referralRes.statusCode == 200) {
        final dynamic referralDecoded = jsonDecode(referralRes.body);
        if (referralDecoded is Map<String, dynamic>) {
          final String code = ('${referralDecoded['referral_code'] ?? ''}')
              .trim()
              .toUpperCase();
          if (code.isNotEmpty) {
            nextCode = code;
          }
        }
      }

      setState(() {
        _walletBalanceCredits = balance;
        _myReferralCode = nextCode;
        _walletTransactions
          ..clear()
          ..addAll(txList);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _tr(
          'Network error loading wallet.',
          'वॉलेट लोड करते समय नेटवर्क त्रुटि हुई।',
        );
      });
    }
  }

  Future<void> _applyReferralCode() async {
    final String code = _applyReferralController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('Please enter referral code.', 'कृपया रेफरल कोड दर्ज करें।'),
          ),
        ),
      );
      return;
    }
    setState(() => _applyingReferral = true);
    try {
      final Uri uri = Uri.parse('${widget.apiBaseUrl}/api/v1/referral/apply');
      final http.Response res = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'X-API-Key': widget.apiAccessKey,
          'Authorization': 'Bearer ${widget.accessToken}',
        },
        body: jsonEncode(<String, dynamic>{'referral_code': code}),
      );
      if (!mounted) return;
      final Map<String, dynamic> decoded = (res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{});
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _applyReferralController.clear();
        _hasRedeemedReferral = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                'Referral code applied successfully.',
                'रेफरल कोड सफलतापूर्वक लागू हो गया।',
              ),
            ),
          ),
        );
        await _refresh();
        return;
      }
      final String msg =
          ('${decoded['detail'] ?? _tr('Could not apply referral code.', 'रेफरल कोड लागू नहीं हो सका।')}')
              .trim();
      if (msg.toLowerCase().contains('already used')) {
        _hasRedeemedReferral = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                'One user can apply only one referral code.',
                'एक यूज़र केवल एक ही रेफरल कोड लागू कर सकता है।',
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Network error while applying referral code.',
              'रेफरल कोड लागू करते समय नेटवर्क त्रुटि हुई।',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _applyingReferral = false);
      }
    }
  }

  String _formatCurrency(int amount) => '₹$amount';

  String _transactionTitle(String source) {
    final String clean = source.trim();
    if (clean.isEmpty) return _tr('Transaction', 'लेन-देन');
    if (clean == 'referral_reward')
      return _tr('Referral Reward', 'रेफरल रिवॉर्ड');
    if (clean == 'withdrawal_request')
      return _tr('Payout Request', 'पेआउट अनुरोध');
    return clean.replaceAll('_', ' ');
  }

  String _responseErrorMessage(http.Response response, String fallback) {
    try {
      final dynamic decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : null;
      if (decoded is Map<String, dynamic>) {
        final String detail =
            ('${decoded['detail'] ?? decoded['message'] ?? ''}').trim();
        if (detail.isNotEmpty) return detail;
      }
    } catch (_) {
      // Keep the caller-facing fallback if the backend response is not JSON.
    }
    return fallback;
  }

  Future<http.Response> _postPayoutRequest({
    required int amount,
    required String upiId,
    required String note,
  }) async {
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
      'X-API-Key': widget.apiAccessKey,
      'Authorization': 'Bearer ${widget.accessToken}',
    };
    final String trimmedNote = note.trim();
    final Map<String, dynamic> withdrawalBody = <String, dynamic>{
      'amount': amount,
      'upi_id': upiId,
      'note': trimmedNote,
    };

    http.Response response = await http.post(
      Uri.parse('${widget.apiBaseUrl}/api/v1/wallet/withdrawals'),
      headers: headers,
      body: jsonEncode(withdrawalBody),
    );
    if (response.statusCode != 404) return response;

    response = await http.post(
      Uri.parse('${widget.apiBaseUrl}/api/v1/wallet/withdraw'),
      headers: headers,
      body: jsonEncode(withdrawalBody),
    );
    if (response.statusCode != 404) return response;

    // Backward compatibility for servers that have not deployed payout routes yet.
    return http.post(
      Uri.parse('${widget.apiBaseUrl}/api/v1/wallet/debit'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'amount': amount,
        'source': 'withdrawal_request',
        'reason': 'Payout request to UPI $upiId',
        'reference_id': 'upi:$upiId',
        'metadata': <String, dynamic>{
          'upi_id': upiId,
          'status': 'pending',
          if (trimmedNote.isNotEmpty) 'note': trimmedNote,
          'fallback': true,
        },
      }),
    );
  }

  String _referralSourceInfo(Map<String, dynamic> row) {
    final dynamic metaRaw = row['metadata'];
    if (metaRaw is! Map<String, dynamic>) return '';
    final dynamic referredRaw = metaRaw['referred_user'];
    if (referredRaw is! Map<String, dynamic>) return '';
    final String name = ('${referredRaw['full_name'] ?? ''}').trim();
    final String phone = ('${referredRaw['phone_number'] ?? ''}').trim();
    if (name.isNotEmpty && phone.isNotEmpty) {
      return _tr('From: $name | $phone', 'से: $name | $phone');
    }
    if (name.isNotEmpty) return _tr('From: $name', 'से: $name');
    if (phone.isNotEmpty) return _tr('From: $phone', 'से: $phone');
    return '';
  }

  Future<void> _onWithdrawTap() async {
    if (_walletBalanceCredits < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Minimum ₹100 required to withdraw.',
              'निकासी के लिए कम से कम ₹100 चाहिए।',
            ),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    _withdrawAmountController.text = '100';
    _withdrawUpiController.clear();
    _withdrawNoteController.clear();
    final bool? created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool submitting = false;
        String? errorText;
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) {
                Future<void> submit() async {
                  final int amount =
                      int.tryParse(_withdrawAmountController.text.trim()) ?? 0;
                  final String upiId = _withdrawUpiController.text.trim();
                  if (amount < 100) {
                    setDialogState(
                      () => errorText = _tr(
                        'Minimum payout is ₹100.',
                        'न्यूनतम पेआउट ₹100 है।',
                      ),
                    );
                    return;
                  }
                  if (amount > _walletBalanceCredits) {
                    setDialogState(
                      () => errorText = _tr(
                        'Amount is higher than wallet balance.',
                        'राशि वॉलेट बैलेंस से अधिक है।',
                      ),
                    );
                    return;
                  }
                  if (!RegExp(
                    r'^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z0-9.\-_]{2,}$',
                  ).hasMatch(upiId)) {
                    setDialogState(
                      () => errorText = _tr(
                        'Please enter a valid UPI ID.',
                        'कृपया सही UPI ID दर्ज करें।',
                      ),
                    );
                    return;
                  }
                  setDialogState(() {
                    submitting = true;
                    errorText = null;
                  });
                  bool success = false;
                  try {
                    final http.Response response = await _postPayoutRequest(
                      amount: amount,
                      upiId: upiId,
                      note: _withdrawNoteController.text.trim(),
                    );
                    if (response.statusCode >= 200 &&
                        response.statusCode < 300) {
                      success = true;
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                      return;
                    }
                    setDialogState(() {
                      errorText = _responseErrorMessage(
                        response,
                        _tr(
                          'Could not create payout request.',
                          'पेआउट अनुरोध नहीं बन सका।',
                        ),
                      );
                    });
                  } catch (_) {
                    setDialogState(() {
                      errorText = _tr(
                        'Network error while creating payout request.',
                        'पेआउट अनुरोध बनाते समय नेटवर्क त्रुटि हुई।',
                      );
                    });
                  } finally {
                    if (!success) {
                      setDialogState(() => submitting = false);
                    }
                  }
                }

                return AlertDialog(
                  title: Text(_tr('Request payout', 'पेआउट अनुरोध')),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr(
                            'Balance: ${_formatCurrency(_walletBalanceCredits)}',
                            'बैलेंस: ${_formatCurrency(_walletBalanceCredits)}',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _withdrawAmountController,
                          keyboardType: TextInputType.number,
                          enabled: !submitting,
                          decoration: InputDecoration(
                            labelText: _tr('Amount', 'राशि'),
                            prefixText: '₹ ',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _withdrawUpiController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !submitting,
                          decoration: InputDecoration(
                            labelText: _tr('UPI ID', 'UPI ID'),
                            hintText: 'name@upi',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _withdrawNoteController,
                          maxLength: 255,
                          enabled: !submitting,
                          decoration: InputDecoration(
                            labelText: _tr('Note (optional)', 'नोट (वैकल्पिक)'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: submitting
                          ? null
                          : () => Navigator.of(dialogContext).pop(false),
                      child: Text(_tr('Cancel', 'रद्द करें')),
                    ),
                    FilledButton(
                      onPressed: submitting ? null : submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0B1F3A),
                        foregroundColor: Colors.white,
                      ),
                      child: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_tr('Submit', 'जमा करें')),
                    ),
                  ],
                );
              },
        );
      },
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('Payout request created.', 'पेआउट अनुरोध बन गया।')),
        ),
      );
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF1F2937), Color(0xFF111827)]
                    : const [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
              ),
              border: Border.all(
                color: isDark
                    ? const Color(0x335B6B88)
                    : const Color(0x1F000000),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF0B1F3A),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _tr('Wallet', 'वॉलेट'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF0B1F3A),
                        ),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: _loading ? null : _onWithdrawTap,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                      ),
                      child: Text(
                        _tr('Withdraw', 'निकालें'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF0B1F3A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (_loadError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _loadError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFFFF8E8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: Color(0xFF0B1F3A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _tr(
                            'Credits: ${_formatCurrency(_walletBalanceCredits)}',
                            'क्रेडिट्स: ${_formatCurrency(_walletBalanceCredits)}',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF0B1F3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    _myReferralCode.isEmpty
                        ? _tr(
                            'Referral code: loading...',
                            'रेफरल कोड: लोड हो रहा है...',
                          )
                        : _tr(
                            'Your code: $_myReferralCode',
                            'आपका कोड: $_myReferralCode',
                          ),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFBFDBFE)
                          : const Color(0xFF0B1F3A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _applyReferralController,
                          textCapitalization: TextCapitalization.characters,
                          enabled: !_applyingReferral && !_hasRedeemedReferral,
                          decoration: InputDecoration(
                            hintText: _hasRedeemedReferral
                                ? _tr(
                                    'Referral already applied',
                                    'रेफरल पहले से लागू है',
                                  )
                                : _tr(
                                    'Apply referral code',
                                    'रेफरल कोड लागू करें',
                                  ),
                            isDense: true,
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0x33475569)
                                    : const Color(0x1F000000),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0x33475569)
                                    : const Color(0x1F000000),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF0B1F3A),
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: (_applyingReferral || _hasRedeemedReferral)
                            ? null
                            : _applyReferralCode,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0B1F3A),
                          foregroundColor: Colors.white,
                        ),
                        child: _applyingReferral
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF172033),
                                ),
                              )
                            : Text(_tr('Apply', 'लागू करें')),
                      ),
                    ],
                  ),
                  if (_hasRedeemedReferral)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _tr(
                          'One user can apply only one referral code.',
                          'एक यूज़र केवल एक ही रेफरल कोड लागू कर सकता है।',
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF5B6B84),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _tr('Recent wallet transactions', 'हाल के वॉलेट लेन-देन'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFFE2E8F0)
                          : const Color(0xFF0B1F3A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_walletTransactions.isEmpty)
                    Text(
                      _tr(
                        'No wallet transactions yet.',
                        'अभी तक कोई वॉलेट लेन-देन नहीं है।',
                      ),
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF5B6B84),
                      ),
                    )
                  else
                    ..._walletTransactions.take(8).map((
                      Map<String, dynamic> row,
                    ) {
                      final String type = ('${row['entry_type'] ?? ''}')
                          .toLowerCase();
                      final bool isCredit = type == 'credit';
                      final int amount = row['amount'] is int
                          ? row['amount'] as int
                          : int.tryParse('${row['amount']}') ?? 0;
                      final String source = ('${row['source'] ?? ''}').trim();
                      final String reason = ('${row['reason'] ?? ''}').trim();
                      final String referralInfo = source == 'referral_reward'
                          ? _referralSourceInfo(row)
                          : '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x33475569)
                                : const Color(0x1F000000),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCredit
                                  ? Icons.add_circle_rounded
                                  : Icons.remove_circle_rounded,
                              color: isCredit
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _transactionTitle(source),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? const Color(0xFFE2E8F0)
                                          : const Color(0xFF0B1F3A),
                                    ),
                                  ),
                                  if (referralInfo.isNotEmpty)
                                    Text(
                                      referralInfo,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF5B6B84),
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (reason.isNotEmpty)
                                    Text(
                                      reason,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF5B6B84),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '${isCredit ? '+' : '-'}${_formatCurrency(amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isCredit
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
