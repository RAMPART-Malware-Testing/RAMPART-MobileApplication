import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../widgets/analysis_components.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AnalysisColors.background, AnalysisColors.surface],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _buildHeroSection(),
                    const SizedBox(height: 24),
                    _buildStepsSection(),
                    const SizedBox(height: 24),
                    _buildToolsSection(),
                    const SizedBox(height: 24),
                    _buildRiskLevelsSection(),
                    const SizedBox(height: 24),
                    _buildWarningsSection(),
                    const SizedBox(height: 24),
                    _buildContactSection(),
                    const SizedBox(height: 16),
                    _buildFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          const Expanded(
            child: Text(
              'ช่วยเหลือและวิธีการใช้งาน',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ยินดีต้อนรับสู่ RAMPART',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AnalysisColors.cyan,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ระบบวิเคราะห์มัลแวร์อัตโนมัติที่ใช้เทคโนโลยี AI และเครื่องมือมาตรฐานระดับสากลเพื่อตรวจสอบไฟล์ของคุณอย่างครบถ้วนและแม่นยำ',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 14,
              height: 1.5,
              color: AnalysisColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnalysisSectionTitle('ขั้นตอนการใช้งาน'),
        const SizedBox(height: 12),
        AnalysisCard(
          child: Column(
            children: [
              _buildStepRow(
                1,
                'สมัครสมาชิก',
                'ลงทะเบียนด้วยอีเมลและรหัสผ่าน',
              ),
              const Divider(height: 24, color: AnalysisColors.border),
              _buildStepRow(
                2,
                'อัปโหลดไฟล์',
                'เลือกไฟล์ที่ต้องการวิเคราะห์จากเครื่องของคุณ',
              ),
              const Divider(height: 24, color: AnalysisColors.border),
              _buildStepRow(
                3,
                'รอระบบวิเคราะห์',
                'ระบบจะใช้เวลาประมาณ 5-15 นาทีในการวิเคราะห์',
              ),
              const Divider(height: 24, color: AnalysisColors.border),
              _buildStepRow(
                4,
                'อ่านรายงาน',
                'ดูผลการวิเคราะห์พร้อมคำแนะนำจาก AI',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepRow(int number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AnalysisColors.cyan.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: AnalysisColors.cyan.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AnalysisColors.cyan,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AnalysisColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 12,
                  color: AnalysisColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnalysisSectionTitle('เครื่องมือที่ใช้วิเคราะห์'),
        const SizedBox(height: 12),
        _buildToolCard(
          'virustotal',
          'VirusTotal',
          'ตรวจสอบไฟล์กับฐานข้อมูลแอนติไวรัสหลายสิบ engine พร้อมผลรายละเอียดต่อ engine',
        ),
        const SizedBox(height: 10),
        _buildToolCard(
          'mobsf',
          'MobSF',
          'วิเคราะห์โครงสร้างและความปลอดภัยของแอป Android แบบ static analysis',
        ),
        const SizedBox(height: 10),
        _buildToolCard(
          'cape',
          'CAPE Sandbox',
          'รันไฟล์ใน sandbox จริงเพื่อบันทึกพฤติกรรม เครือข่าย และ signature ที่ตรวจพบ',
        ),
        const SizedBox(height: 10),
        _buildToolCard(
          'rampart_ai',
          'RampartAI',
          'โมเดล Machine Learning ของทีมที่ทำนายว่าไฟล์เป็น malware หรือ benign',
        ),
        const SizedBox(height: 10),
        _buildToolCard(
          'gemini',
          'Gemini AI',
          'สรุปผลและให้คำแนะนำเป็นภาษาไทยจากผลของทุกเครื่องมือข้างต้น',
        ),
      ],
    );
  }

  Widget _buildToolCard(String tool, String name, String description) {
    final asset = analysisToolAsset(tool);
    final dpr = 2.0;

    return AnalysisCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AnalysisColors.cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: asset == null
                ? Icon(
                    analysisToolIcon(tool),
                    size: 26,
                    color: AnalysisColors.cyan,
                  )
                : Image.asset(
                    asset,
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                    cacheWidth: (26 * dpr).round(),
                    cacheHeight: (26 * dpr).round(),
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      analysisToolIcon(tool),
                      size: 26,
                      color: AnalysisColors.cyan,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AnalysisColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 12,
                    height: 1.4,
                    color: AnalysisColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskLevelsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnalysisSectionTitle('ระดับความเสี่ยง'),
        const SizedBox(height: 12),
        AnalysisCard(
          child: Column(
            children: [
              _buildRiskLevelRow(90, '80-100'),
              const Divider(height: 20, color: AnalysisColors.border),
              _buildRiskLevelRow(70, '60-79'),
              const Divider(height: 20, color: AnalysisColors.border),
              _buildRiskLevelRow(45, '30-59'),
              const Divider(height: 20, color: AnalysisColors.border),
              _buildRiskLevelRow(10, '0-29'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRiskLevelRow(num score, String range) {
    final tier = AnalysisScoreTier.fromScore(score);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: tier.barColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tier.label,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tier.textColor,
            ),
          ),
        ),
        Text(
          range,
          style: const TextStyle(
            fontFamily: 'Kanit',
            fontSize: 12,
            color: AnalysisColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWarningsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnalysisSectionTitle('ข้อควรระวัง'),
        const SizedBox(height: 12),
        AnalysisCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWarningItem(
                'ผลการวิเคราะห์เป็นข้อมูลประกอบการตัดสินใจเท่านั้น ไม่ใช่ข้อสรุปทางกฎหมายหรือการรับประกันความปลอดภัย',
              ),
              const SizedBox(height: 12),
              _buildWarningItem(
                'ไฟล์ที่อัปโหลดจะถูกส่งไปยังเซิร์ฟเวอร์และเครื่องมือภายนอกเพื่อการวิเคราะห์',
              ),
              const SizedBox(height: 12),
              _buildWarningItem(
                'รายงานที่ตั้งเป็นสาธารณะจะมองเห็นได้โดยผู้ใช้คนอื่น',
              ),
              const SizedBox(height: 12),
              _buildWarningItem(
                'อย่าอัปโหลดไฟล์ที่มีข้อมูลส่วนบุคคลหรือความลับทางธุรกิจหากไม่จำเป็น',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarningItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AnalysisColors.running,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              height: 1.5,
              color: AnalysisColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnalysisSectionTitle('ติดต่อทีมงาน'),
        const SizedBox(height: 12),
        AnalysisCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AnalysisColors.cyan.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: AnalysisColors.cyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: SelectableText(
                  'rampartmalwareanalysis@gmail.com',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 13,
                    color: AnalysisColors.cyan,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Text(
        'RAMPART · ระบบวิเคราะห์มัลแวร์อัตโนมัติ',
        style: TextStyle(
          fontFamily: 'Kanit',
          fontSize: 11,
          color: AnalysisColors.textMuted,
        ),
      ),
    );
  }
}
