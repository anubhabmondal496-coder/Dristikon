import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  final List<String> _denominations = ["10", "20", "50", "100", "200", "500"];
  String _currentResult = "500";
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    VoiceService.instance.speak("Currency reader active. Hold banknote flat in front of camera.");
  }

  void _simulateScan(String note) {
    setState(() {
      _currentResult = note;
      _isScanning = true;
    });

    VoiceService.instance.speak("Banknote identified: $note Rupees.");

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Back button
              Semantics(
                label: "Exit Currency Reader and return to home menu",
                button: true,
                child: Container(
                  height: 68,
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cardBorder,
                        offset: Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      VoiceService.instance.speak("Exiting currency reader.");
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back, size: 28, color: AppTheme.cardBorder),
                    label: const Text(
                      "EXIT TO MENU",
                      style: TextStyle(
                        color: AppTheme.cardBorder,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cardBackground,
                      side: const BorderSide(color: AppTheme.cardBorder, width: 2.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Giant Identified Banknote Card
              Expanded(
                flex: 3,
                child: Semantics(
                  label: "Identified Currency: $_currentResult Rupees. Double tap to hear again.",
                  button: true,
                  child: InkWell(
                    onTap: () {
                      VoiceService.instance.speak("Banknote is $_currentResult Rupees.");
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _isScanning ? AppTheme.accentBlue : AppTheme.cardBorder,
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppTheme.cardBorder,
                            offset: Offset(0, 5),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlueLight,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.cardBorder, width: 2.5),
                            ),
                            child: const Icon(
                              Icons.payments,
                              size: 42,
                              color: AppTheme.cardBorder,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "INDIAN BANKNOTE",
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "₹$_currentResult",
                            style: const TextStyle(
                              color: AppTheme.cardBorder,
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmberLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                            ),
                            child: Text(
                              "$_currentResult RUPEES",
                              style: const TextStyle(
                                color: AppTheme.cardBorder,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Tap card anytime to re-announce value",
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Denomination Selection Grid (Simulate/Test)
              const Text(
                "TEST BANKNOTE DENOMINATIONS:",
                style: TextStyle(
                  color: AppTheme.cardBorder,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _denominations.map((note) {
                  final isSelected = _currentResult == note;
                  return Semantics(
                    label: "Select $note Rupees banknote",
                    button: true,
                    child: Container(
                      width: (MediaQuery.of(context).size.width - 48) / 3,
                      height: 58,
                      decoration: BoxDecoration(
                        boxShadow: isSelected
                            ? [
                                const BoxShadow(
                                  color: AppTheme.cardBorder,
                                  offset: Offset(0, 3),
                                  blurRadius: 0,
                                ),
                              ]
                            : null,
                      ),
                      child: ElevatedButton(
                        onPressed: () => _simulateScan(note),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? AppTheme.accentAmber : AppTheme.cardBackground,
                          side: const BorderSide(
                            color: AppTheme.cardBorder,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.zero,
                          elevation: 0,
                        ),
                        child: Text(
                          "₹$note",
                          style: TextStyle(
                            color: AppTheme.cardBorder,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
