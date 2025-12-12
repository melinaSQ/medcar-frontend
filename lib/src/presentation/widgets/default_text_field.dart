// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';

// esta clase crea un campo de texto por defecto que se puede reutilizar en toda la app
class DefaultTextField extends StatelessWidget {
  String text;
  String? initialValue;
  Function(String text) onChanged;
  IconData icon;
  EdgeInsetsGeometry margin;
  String? Function(String?)? validator;
  Color backgroundColor;
  TextInputType keyboardType;
  bool obscureText;
  TextEditingController? controller;

  DefaultTextField({
    super.key,
    required this.text,
    required this.icon,
    required this.onChanged,
    this.margin = const EdgeInsets.only(top: 20, left: 20, right: 20),
    this.validator,
    this.backgroundColor = Colors.white,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      margin: margin,
      padding: EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(15),
            bottomRight: Radius.circular(15),
          )),
      child: TextFormField(
        controller: controller,
        onChanged: (text) {
          onChanged(text);
        },
        obscureText: obscureText,
        style: TextStyle(fontSize: 14),
        initialValue: controller == null ? initialValue : null,
        validator: validator,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            label: Text(
              text,
              style: TextStyle(fontSize: 14),
            ),
            border: InputBorder.none,
            prefixIcon: Container(
              margin: EdgeInsets.all(15),
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  Icon(
                    icon,
                    size: 22,
                  ),
                  Container(
                    margin: EdgeInsets.only(right: 2, left: 15),
                    height: 22,
                    width: 1,
                    color: Colors.grey,
                  )
                ],
              ),
            )),
      ),
    );
  }
}
