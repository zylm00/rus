import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/animated_rotation_widget.dart';
import 'package:flutter_hbb/common/widgets/custom_password.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_view.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_remote_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_transfer_page.dart';
import 'package:flutter_hbb/desktop/widgets/left_pane.dart';
import 'package:flutter_hbb/desktop/widgets/right_pane.dart';
import 'package:flutter_hbb/generated/l10n.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/models/gobal_model.dart';
import 'package:flutter_hbb/models/theme_model.dart';
import 'package:flutter_hbb/models/app_model.dart';
import 'package:flutter_hbb/tool.dart';

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({Key? key}) : super(key: key);

  @override
  _DesktopHomePageState createState() => _DesktopHomePageState();
}
class _DesktopHomePageState extends State<DesktopHomePage>
    with WidgetsBindingObserver {
  late StreamSubscription _sub;
  Timer? _timer;
  bool _showReconnectButton = false;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _sub = gFFI.serverModel.connectionStateStream.listen((_) {
      setState(() {});
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) {
      setState(() {});
    }
  }

  void handleReconnect() async {
    setState(() {
      _showReconnectButton = false;
    });
    gFFI.serverModel.reconnect();
  }
  @override
  Widget build(BuildContext context) {
    final serverModel = gFFI.serverModel;
    final themeModel = ThemeModel.of(context);
    final connection = serverModel.curConnection;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Row(
        children: [
          // 左侧主面板（ID/密码、本地信息）
          Expanded(
            flex: 4,
            child: Container(
              color: Theme.of(context).colorScheme.background,
              child: buildLeftPane(context),
            ),
          ),

          // 右侧内容页（标签页 / 远控 / 传输）
          Expanded(
            flex: 6,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: buildRightPane(context),
            ),
          ),
        ],
      ),
    );
  }
  Widget buildLeftPane(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Container(
        width: 400,
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        color: Theme.of(context).colorScheme.background,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              translate("Your Desktop"),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),

            SizedBox(height: 20),

            // 🔥----- 你的网络状态小行在这里 ------🔥
            NetStatusWidget(),

            SizedBox(height: 20),

            // 本机 ID
            Consumer<ServerModel>(
              builder: (context, model, child) => AutoSizeText(
                model.serverId.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
              ),
            ),

            SizedBox(height: 10),

            // 本机密码
            Consumer<ServerModel>(
              builder: (context, model, child) => AutoSizeText(
                model.serverPasswd.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
              ),
            ),

            SizedBox(height: 20),

            // 复制按钮
            Consumer<ServerModel>(
              builder: (context, model, child) => ElevatedButton(
                onPressed: () {
                  String copyText = '${model.serverId.text}\n${model.serverPasswd.text}';
                  Clipboard.setData(ClipboardData(text: copyText));
                  showToast(translate("Copied"));
                },
                child: Text(
                  translate("Copy"),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),

            // 插件 UI
            buildPluginEntry(),

          ],
        ),
      ),
    );
  }
  Widget buildRightPane(BuildContext context) {
    final serverModel = gFFI.serverModel;

    return GetBuilder<DesktopTabController>(
      init: DesktopTabController(),
      builder: (controller) {
        return Column(
          children: [
            SizedBox(height: 20),

            // 顶部 Tab 标签栏
            TabBarWidget(
              tabs: [
                translate("Remote Control"),
                translate("File Transfer"),
                translate("History"),
              ],
              currentIndex: controller.tabIndex,
              onTap: (index) => controller.changeTab(index),
            ),

            SizedBox(height: 10),

            // ---- Tab 内容页面 ----
            Expanded(
              child: IndexedStack(
                index: controller.tabIndex,
                children: [
                  // 远程连接页
                  RemoteControlPage(),

                  // 文件传输页
                  FileTransferPage(),

                  // 历史列表
                  ConnectionHistoryPage(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
void setPasswordDialog({VoidCallback? notEmptyCallback}) async {
  final pw = await bind.mainGetPermanentPassword();
  final p0 = TextEditingController(text: pw);
  final p1 = TextEditingController(text: pw);
  var errMsg0 = "";
  var errMsg1 = "";
  final RxString rxPass = pw.trim().obs;

  final rules = [
    DigitValidationRule(),
    UppercaseValidationRule(),
    LowercaseValidationRule(),
    // SpecialCharacterValidationRule(),
    MinCharactersValidationRule(8),
  ];

  final maxLength = bind.mainMaxEncryptLen();

  gFFI.dialogManager.show((setState, close, context) {
    submit() {
      setState(() {
        errMsg0 = "";
        errMsg1 = "";
      });

      final pass = p0.text.trim();

      if (pass.isNotEmpty) {
        final Iterable violations = rules.where((r) => !r.validate(pass));
        if (violations.isNotEmpty) {
          setState(() {
            errMsg0 =
                '${translate('Prompt')}: ${violations.map((r) => r.name).join(', ')}';
          });
          return;
        }
      }

      if (p1.text.trim() != pass) {
        setState(() {
          errMsg1 =
              '${translate('Prompt')}: ${translate("The confirmation is not identical.")}';
        });
        return;
      }

      bind.mainSetPermanentPassword(password: pass);

      if (pass.isNotEmpty) {
        notEmptyCallback?.call();
      }

      close();
    }

    return Dialog(
      child: Container(
        width: 400,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              translate("Set permanent password"),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 20),

            // 输入框 1
            TextField(
              controller: p0,
              maxLength: maxLength,
              decoration: InputDecoration(
                labelText: translate("Password"),
                errorText: errMsg0.isEmpty ? null : errMsg0,
              ),
              onChanged: (value) => rxPass.value = value.trim(),
            ),

            SizedBox(height: 10),

            // 输入框 2（确认）
            TextField(
              controller: p1,
              maxLength: maxLength,
              decoration: InputDecoration(
                labelText: translate("Confirm"),
                errorText: errMsg1.isEmpty ? null : errMsg1,
              ),
            ),

            SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: close,
                  child: Text(translate("Cancel")),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: submit,
                  child: Text(translate("Confirm")),
                ),
              ],
            )
          ],
        ),
      ),
    );
  });
}
