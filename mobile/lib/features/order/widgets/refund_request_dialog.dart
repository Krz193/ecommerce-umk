import 'package:flutter/material.dart';

class RefundRequestDialogResult {
  final String requestType;
  final String reason;

  const RefundRequestDialogResult({
    required this.requestType,
    required this.reason,
  });
}

class RefundRequestDialog extends StatefulWidget {
  const RefundRequestDialog({super.key});

  @override
  State<RefundRequestDialog> createState() => _RefundRequestDialogState();
}

class _RefundRequestDialogState extends State<RefundRequestDialog> {
  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();
  String requestType = 'refund';

  @override
  void dispose() {
    reasonController.dispose();

    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      RefundRequestDialogResult(
        requestType: requestType,
        reason: reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancellation / Refund Request'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: requestType,
              decoration: const InputDecoration(labelText: 'Request Type'),
              items: const [
                DropdownMenuItem(value: 'refund', child: Text('Refund')),
                DropdownMenuItem(
                  value: 'cancellation',
                  child: Text('Cancellation'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  requestType = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Explain why this order needs handling',
              ),
              minLines: 3,
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Reason required';
                }

                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: submit, child: const Text('Submit')),
      ],
    );
  }
}
