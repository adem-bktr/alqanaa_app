import 'package:flutter/material.dart';
import '../services/printer_service.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  List<dynamic> devices = [];
  bool isLoading = false;
  bool isConnecting = false;
  String? connectingTo;

  // ══════════════════════════════════
  //  Responsive
  // ══════════════════════════════════
  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    setState(() => isLoading = true);
    try {
      final found = await PrinterService.getAvailableDevices();
      if (mounted) {
        setState(() {
          devices = found;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _connect(dynamic device) async {
    final address = PrinterService.getDeviceAddress(device);
    final name = PrinterService.getDeviceName(device);

    setState(() {
      isConnecting = true;
      connectingTo = address;
    });

    final success = await PrinterService.connect(device);

    if (!mounted) return;

    setState(() {
      isConnecting = false;
      connectingTo = null;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم الاتصال بـ $name'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '❌ فشل الاتصال — تأكد من تشغيل البلوتوث والطابعة'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testPrint() async {
    final success = await PrinterService.printTest();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text(success ? '✅ طباعة تجريبية ناجحة' : '❌ فشلت الطباعة'),
        backgroundColor:
        success ? const Color(0xFF2E7D32) : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
    setState(() {});
  }

  Future<void> _disconnect() async {
    await PrinterService.disconnect();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم قطع الاتصال بالطابعة'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ══════════════════════════════════
  //  BUILD
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
    isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (isDesktop) {
      return _buildDesktopLayout(isDark, cardColor, textColor);
    }
    return _buildMobileLayout(isDark, cardColor, textColor);
  }

  // ══════════════════════════════════
  //  Desktop Layout
  // ══════════════════════════════════
  Widget _buildDesktopLayout(
      bool isDark, Color cardColor, Color textColor) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          title: const Text(
            'الطابعة الحرارية',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _scanDevices,
              tooltip: 'بحث مجدد',
            ),
          ],
        ),
        body: Row(
          children: [
            // ── العمود الأيسر: قائمة الأجهزة ──
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _buildStatusBanner(),
                  _buildDevicesHeader(textColor),
                  Expanded(
                    child: isLoading
                        ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF2E7D32)),
                    )
                        : devices.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildDevicesList(
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),
                  ),
                ],
              ),
            ),
            // ── العمود الأيمن: التعليمات ──
            Container(
              width: 320,
              height: double.infinity,
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(
                    color:
                    Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // حالة الطابعة
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PrinterService.isConnected
                            ? const Color(0xFF2E7D32)
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                PrinterService.isConnected
                                    ? Icons.print_rounded
                                    : Icons.print_disabled_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                PrinterService.isConnected
                                    ? 'متصل'
                                    : 'غير متصل',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          if (PrinterService.isConnected &&
                              PrinterService.connectedDeviceName !=
                                  null) ...[
                            const SizedBox(height: 6),
                            Text(
                              PrinterService.connectedDeviceName!,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                          if (PrinterService.isConnected) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _testPrint,
                                    icon: const Icon(Icons.print,
                                        color: Color(0xFF2E7D32),
                                        size: 16),
                                    label: const Text('اختبار',
                                        style: TextStyle(
                                            color: Color(0xFF2E7D32),
                                            fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _disconnect,
                                    icon: const Icon(Icons.link_off,
                                        color: Colors.red, size: 16),
                                    label: const Text('قطع',
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // التعليمات
                    _buildInstructionsContent(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  Mobile Layout
  // ══════════════════════════════════
  Widget _buildMobileLayout(
      bool isDark, Color cardColor, Color textColor) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          title: const Text(
            'الطابعة الحرارية',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _scanDevices,
              tooltip: 'بحث مجدد',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildStatusBanner(),
            _buildDevicesHeader(textColor),
            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF2E7D32)),
              )
                  : devices.isEmpty
                  ? _buildEmptyState(isDark)
                  : _buildDevicesList(
                isDark: isDark,
                cardColor: cardColor,
                textColor: textColor,
              ),
            ),
            _buildInstructions(isDark),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  Shared Widgets
  // ══════════════════════════════════
  Widget _buildStatusBanner() {
    final connected = PrinterService.isConnected;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: connected ? const Color(0xFF2E7D32) : Colors.orange,
      child: Row(
        children: [
          Icon(
            connected
                ? Icons.print_rounded
                : Icons.print_disabled_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected
                      ? 'متصل بـ ${PrinterService.connectedDeviceName ?? ''}'
                      : 'لا يوجد اتصال',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  connected
                      ? 'الطابعة جاهزة للطباعة'
                      : 'اختر طابعة من القائمة أدناه',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (connected)
            Row(
              children: [
                TextButton(
                  onPressed: _testPrint,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'اختبار',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.link_off, color: Colors.white),
                  tooltip: 'قطع الاتصال',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDevicesHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            PrinterService.isDesktop ? Icons.usb_rounded : Icons.bluetooth_rounded,
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 8),
          Text(
            PrinterService.isDesktop ? 'طابعات النظام والـ USB' : 'أجهزة البلوتوث المقترنة',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const Spacer(),
          Text(
            PrinterService.isDesktop ? 'جاهز' : '${devices.length} جهاز',
            style: const TextStyle(
                color: Color(0xFF2E7D32), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    if (PrinterService.isDesktop) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.usb_rounded, size: 80, color: Color(0xFF2E7D32)),
            const SizedBox(height: 16),
            const Text(
              'طابعة الـ USB والوندوز جاهزة تلقائياً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'على الحاسوب، يتم إرسال الفواتير مباشرة إلى الطابعة الحرارية المعرفة في النظام.\nاضغط على زر "اختبار" للتأكد من سلامة الاتصال.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _testPrint,
              icon: const Icon(Icons.print, color: Colors.white),
              label: const Text('طباعة صفحة اختبار تجريبية', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            )
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled_rounded,
              size: 80,
              color: isDark
                  ? Colors.grey.shade700
                  : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد أجهزة مقترنة',
              style: TextStyle(
                  fontSize: 16,
                  color:
                  isDark ? Colors.grey.shade500 : Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'تأكد من اقتران الطابعة بالهاتف أولاً من إعدادات البلوتوث',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? Colors.grey.shade600
                    : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _scanDevices,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('بحث مجدد',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesList({
    required bool isDark,
    required Color cardColor,
    required Color textColor,
  }) {
    return RefreshIndicator(
      color: const Color(0xFF2E7D32),
      onRefresh: _scanDevices,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          final deviceName = PrinterService.getDeviceName(device);
          final deviceAddress =
          PrinterService.getDeviceAddress(device);
          final isThisConnected = PrinterService.isConnected &&
              PrinterService.connectedDeviceAddress == deviceAddress;
          final isThisConnecting =
              isConnecting && connectingTo == deviceAddress;

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + index * 80),
            curve: Curves.easeOutCubic,
            builder: (_, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: isThisConnected
                    ? Border.all(
                    color: const Color(0xFF2E7D32), width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isThisConnected
                        ? const Color(0xFF2E7D32)
                        .withValues(alpha: 0.1)
                        : isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.print_rounded,
                    color: isThisConnected
                        ? const Color(0xFF2E7D32)
                        : Colors.grey,
                    size: 28,
                  ),
                ),
                title: Text(
                  deviceName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isThisConnected
                        ? const Color(0xFF2E7D32)
                        : textColor,
                  ),
                ),
                subtitle: Text(
                  deviceAddress,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey,
                  ),
                ),
                trailing: _buildTrailing(
                  isThisConnecting: isThisConnecting,
                  isThisConnected: isThisConnected,
                  device: device,
                ),
                onTap:
                isThisConnected ? null : () => _connect(device),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrailing({
    required bool isThisConnecting,
    required bool isThisConnected,
    required dynamic device,
  }) {
    if (isThisConnecting) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
            color: Color(0xFF2E7D32), strokeWidth: 2),
      );
    }

    if (isThisConnected) {
      return Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
              const Color(0xFF2E7D32).withValues(alpha: 0.3)),
        ),
        child: const Text(
          'متصل',
          style: TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.bold,
              fontSize: 12),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => _connect(device),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('اتصال',
          style: TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  Widget _buildInstructions(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2A1E)
            : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
      ),
      child: _buildInstructionsContent(isDark),
    );
  }

  Widget _buildInstructionsContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.info_outline,
                color: Color(0xFF2E7D32), size: 18),
            SizedBox(width: 8),
            Text(
              'كيف تقترن بالطابعة؟',
              style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _step('1', 'شغّل البلوتوث في الهاتف'),
        _step('2', 'شغّل الطابعة الحرارية'),
        _step('3', 'اذهب لإعدادات البلوتوث في الهاتف'),
        _step('4',
            'اقترن بالطابعة، غالباً اسمها POS أو Printer'),
        _step('5', 'ارجع هنا واضغط اتصال'),
      ],
    );
  }

  Widget _step(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
                color: Color(0xFF2E7D32), shape: BoxShape.circle),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}