import 'package:flutter/material.dart';

class LegalPoliciesDialog extends StatelessWidget {
  final bool isPrivacy;

  const LegalPoliciesDialog({super.key, required this.isPrivacy});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isPrivacy ? 'سياسة الخصوصية' : 'إخلاء المسؤولية والشروط'),
      content: SingleChildScrollView(
        child: Text(
          isPrivacy
              ? 'تطبيق "أكلة النهاردة" هو تطبيق أوفلاين محلي (Offline-First) بالكامل.\n\n'
                  'نحن لا نقوم بجمع أو تخزين أو إرسال أي بيانات شخصية، أو موقع جغرافي، أو عادات استخدام لأي سيرفر خارجي.\n\n'
                  'جميع بيانات الوجبات والإعدادات يتم حفظها بشكل محلي فقط على جهازك الشخصي، مما يضمن خصوصيتك التامة.'
              : 'التطبيق هو أداة تنظيمية تهدف إلى مساعدتك في اقتراح وتنظيم الوجبات المنزلية اليومية، ولا يقدم أي استشارات طبية أو غذائية متخصصة.\n\n'
                  'يُرجى الانتباه إلى أن فحص مكونات الوجبات والتأكد من خلوها من أي مسببات للحساسية هو مسؤولية المستخدم بالكامل.\n\n'
                  'لا يتحمل مطورو التطبيق أي مسؤولية عن أي أضرار صحية قد تنتج عن استخدام وصفات أو اقتراحات التطبيق.',
          style: const TextStyle(height: 1.5),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('حسناً'),
        ),
      ],
    );
  }
}
