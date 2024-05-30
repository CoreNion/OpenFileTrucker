import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file_trucker/helper/permission.dart';

import '../class/qr_data.dart';
import '../helper/service.dart';
import '../provider/receive_provider.dart';
import '../widget/dialog.dart';
import '../widget/service.dart';
import '../widget/receive_qr.dart';

class ReceivePage extends ConsumerWidget {
  const ReceivePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    String ip = "";

    return SafeArea(
        child: Scaffold(
            body: Container(
      margin: const EdgeInsets.all(10),
      child: Column(
        children: [
          Form(
              key: formKey,
              child: Row(
                children: [
                  Expanded(
                      child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      hintText: 'IPアドレスを入力',
                      icon: Icon(Icons.connect_without_contact),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '値を入力してください';
                      }
                      return null;
                    },
                    onSaved: (newValue) => ip = newValue!,
                  )),
                  IconButton.filled(
                    onPressed: () {
                      if (formKey.currentState != null) {
                        if (formKey.currentState!.validate()) {
                          formKey.currentState!.save();
                          startManualReceive(ip, ref);
                        }
                      }
                    },
                    icon: const Icon(Icons.send),
                  )
                ],
              )),
          const SizedBox(height: 10),
          SizedBox(
              height: 50,
              width: double.infinity,
              child: ElevatedButton.icon(
                  onPressed: () async {
                    final pCheck = await checkCamPermission();
                    switch (pCheck) {
                      case null:
                        EasyDialog.showErrorNoti("カメラへのアクセス権限の取得に失敗しました。", ref);
                        return;
                      case false:
                        EasyDialog.showSmallToast(ref, "権限が必要です",
                            "QRコードを読み取るためには、カメラへのアクセスの許可が必要です。");
                        return;
                    }

                    final res = await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        useSafeArea: true,
                        builder: ((context) => const ScanQRCodePage()));
                    if (res is QRCodeData) {
                      startManualReceive(res.ip, ref);
                    }
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text("QRコードで接続"))),
          const SizedBox(height: 10),
          const Text("付近のデバイス",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Expanded(child: TruckerDevicesList(ServiceType.receive)),
        ],
      ),
    )));
  }
}
