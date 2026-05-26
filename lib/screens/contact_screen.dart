import 'package:flutter/material.dart';

import '../services/contact_api.dart';

/// Contact form: topic + message only. Name / email / phone come from the logged-in account on the server.
class ContactScreen extends StatefulWidget {
  const ContactScreen({
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
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final TextEditingController _message = TextEditingController();

  List<InquiryKindOption> _kinds = <InquiryKindOption>[];
  String? _selectedKind;
  bool _loadingMeta = true;
  String? _metaError;
  bool _submitting = false;
  bool get _isHindi => widget.languageCode.trim().toLowerCase() == 'hi';
  String _tr(String en, String hi) => _isHindi ? hi : en;

  bool get _loggedIn => widget.accessToken.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _metaError = null;
    });
    try {
      final List<InquiryKindOption> list = await fetchContactMeta(
        apiBaseUrl: widget.apiBaseUrl,
        apiAccessKey: widget.apiAccessKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _kinds = list;
        _selectedKind = list.isNotEmpty ? list.first.value : null;
        _loadingMeta = false;
      });
    } on ContactApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _metaError = e.message;
        _loadingMeta = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _metaError = _tr('Could not load form options.', 'फॉर्म विकल्प लोड नहीं हुए।');
        _loadingMeta = false;
      });
    }
  }

  Future<void> _showSubmissionSuccessDialog() async {
    if (!mounted) {
      return;
    }
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF065F46) : const Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 40,
              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
            ),
          ),
          title: Text(
            _tr('We received your message', 'हमें आपका संदेश मिल गया'),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _tr(
                    'Thank you for reaching out. Our support team will review what you sent and get back to you using the email and phone on your profile.',
                    'संपर्क करने के लिए धन्यवाद। हमारी सपोर्ट टीम आपके संदेश की समीक्षा करेगी और प्रोफाइल के ईमेल/फोन पर आपसे संपर्क करेगी।',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _tr(
                    "You'll usually hear from us within 1-2 business days.",
                    'आमतौर पर 1-2 कार्यदिवस में हमारी तरफ से जवाब मिल जाएगा।',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(_tr('Sounds good', 'ठीक है'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _submit() async {
    if (!_loggedIn) {
      return;
    }
    if (_selectedKind == null || _selectedKind!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('Choose a topic first.', 'पहले एक टॉपिक चुनें।'))),
      );
      return;
    }
    if (_message.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('Message must be at least 10 characters.', 'संदेश कम से कम 10 अक्षरों का होना चाहिए।'))),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await submitContact(
        apiBaseUrl: widget.apiBaseUrl,
        apiAccessKey: widget.apiAccessKey,
        accessToken: widget.accessToken,
        inquiryKind: _selectedKind!,
        message: _message.text,
      );
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      _message.clear();
      await _showSubmissionSuccessDialog();
    } on ContactApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('Network error. Try again.', 'नेटवर्क त्रुटि। फिर कोशिश करें।'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fieldFill = isDark ? const Color(0xFF1F2937) : Colors.white;
    final Color border = isDark ? const Color(0x335B6B88) : const Color(0x26059669);

    if (!_loggedIn) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFFFFFFF),
        appBar: AppBar(
          title: Text(_tr('Contact us', 'हमसे संपर्क करें'), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 56,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              const SizedBox(height: 20),
              Text(
                _tr('Log in to contact us', 'हमसे संपर्क करने के लिए लॉगिन करें'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF102A56),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _tr(
                  'We use your profile name, email and phone automatically - no need to type them here.',
                  'हम आपके प्रोफाइल का नाम, ईमेल और फोन अपने-आप इस्तेमाल करते हैं - यहां टाइप करने की जरूरत नहीं है।',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: Text(_tr('Contact us', 'हमसे संपर्क करें'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : _metaError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_metaError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadMeta,
                          child: Text(_tr('Retry', 'फिर कोशिश करें')),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _tr(
                            "We'll attach your account name, email and phone from your profile to this message.",
                            'हम इस संदेश के साथ आपकी प्रोफाइल का नाम, ईमेल और फोन अपने-आप जोड़ देंगे।',
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use — controlled selection after meta loads.
                          value: _selectedKind,
                          decoration: _fieldDecoration(_tr('Topic', 'विषय'), border, fieldFill, isDark),
                          items: _kinds
                              .map(
                                (InquiryKindOption o) => DropdownMenuItem<String>(
                                  value: o.value,
                                  child: Text(o.label, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (String? v) => setState(() => _selectedKind = v),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _message,
                          minLines: 5,
                          maxLines: 12,
                          style: TextStyle(
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _fieldDecoration(_tr('Message', 'संदेश'), border, fieldFill, isDark).copyWith(
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: const Color(0xFF059669),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_tr('Send message', 'संदेश भेजें'), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                ),
    );
  }

  InputDecoration _fieldDecoration(
    String label,
    Color border,
    Color fill,
    bool isDark,
  ) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFF059669), width: 1.5),
      ),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
    );
  }
}
