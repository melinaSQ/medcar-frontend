// ignore_for_file: file_names

class BlocFormItem {

  final String value;
  final String? error;

  //constructor
  const BlocFormItem({
    this.value = '',
    this.error
  });

  //metodo para cambiar el estado de la clase
  BlocFormItem copyWith({
    String? value,
    String? error
  }) {
    return BlocFormItem(
      value: value ?? this.value,
      error: error ?? this.error
    );
  }

}