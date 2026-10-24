import 'package:flutter/material.dart';

class DeliveryInfoResult {
  final String courierCompany;
  final String expressNo;

  const DeliveryInfoResult({
    required this.courierCompany,
    required this.expressNo,
  });
}

class DeliveryInfoSheet extends StatefulWidget {
  const DeliveryInfoSheet({super.key});

  @override
  State<DeliveryInfoSheet> createState() => _DeliveryInfoSheetState();
}

class _DeliveryInfoSheetState extends State<DeliveryInfoSheet> {
  final TextEditingController _companyController = TextEditingController(
    text: '顺丰',
  );
  final TextEditingController _expressNoController = TextEditingController();

  @override
  void dispose() {
    _companyController.dispose();
    _expressNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 320,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '填写发货信息',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _companyController,
                decoration: const InputDecoration(labelText: '快递公司'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _expressNoController,
                decoration: const InputDecoration(labelText: '快递单号'),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final company = _companyController.text.trim();
                    final expressNo = _expressNoController.text.trim();
                    if (company.isEmpty || expressNo.isEmpty) {
                      return;
                    }
                    Navigator.of(context).pop(
                      DeliveryInfoResult(
                        courierCompany: company,
                        expressNo: expressNo,
                      ),
                    );
                  },
                  child: const Text('确认发货'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
