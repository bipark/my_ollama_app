import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class AppTitle extends StatelessWidget {
  final double? fontSize;
  final Color? textColor;

  const AppTitle({
    super.key,
    this.fontSize = 17,
    this.textColor = Colors.indigo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 10),
        Image.asset("assets/images/appstore.png", width: 30, height: 30),
        SizedBox(width: 6),
        Text(tr("l_myollama"),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
            )),
      ],
    );
  }
}
