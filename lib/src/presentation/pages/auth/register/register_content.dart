import 'package:flutter/material.dart';
import 'package:medcar_frontend/src/presentation/widgets/default_button.dart';
import 'package:medcar_frontend/src/presentation/widgets/default_text_field_outlined.dart';

class RegisterContent extends StatelessWidget {
  const RegisterContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        //container de fondo con gradiente
        Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          padding: EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF652580), //morado kev
                Color(0xFF5a469c), //morado
                Color(0xFF00A099), //turquesa kev
                //Color(0xFF40e0d0), //turquesa
                //Color(0xFF937ccb), //morado
                //Color(0xFF6041a2), //morado
                //Color.fromARGB(255, 12, 38, 145),
                //Color.fromARGB(255, 34, 156, 249),
              ],
            ),
          ),

          //****configuracion de los textos
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // HORIZONTAL --para centrar horizontal
            mainAxisAlignment: MainAxisAlignment.center, // VERTICAL --para centrar vertical
            children: [
              _textLoginRotated(context),
              SizedBox(height: 100),
              _textRegisterRotated(),
              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            ],
          ),
        ),

        //*****2. container del formulario de registro
        Container(
          margin: EdgeInsets.only(left: 60, bottom: 35),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(35),
                  bottomLeft: Radius.circular(35)),
              //color: const Color.fromARGB(255, 189, 126, 126),

              gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: const [
                    Color.fromARGB(255, 255, 255, 255),
                    Color.fromARGB(255, 154, 154, 154),
                  ]),
            ),

            //******conteenido del fomrulario
            child: Stack(
              children: [
                _imageBackground(context),
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _imageMedcar(),
                      DefaultTextFieldOutlined(
                        text: 'Nombre',
                        icon: Icons.person_outline,
                        margin: EdgeInsets.only(left: 50, right: 50, top: 50),
                        onChanged: (text) {
                          
                        },
                        
                      ),
                      DefaultTextFieldOutlined(
                        text: 'Apellido',
                        icon: Icons.person_2_outlined,
                        margin: EdgeInsets.only(left: 50, right: 50, top: 15),
                        onChanged: (text) {
                          
                        },

                      ),
                      DefaultTextFieldOutlined(
                        text: 'Email',
                        icon: Icons.email_outlined,
                        margin: EdgeInsets.only(left: 50, right: 50, top: 15),
                        onChanged: (text) {
                          
                        },
                        
                      ),
                      DefaultTextFieldOutlined(
                        text: 'Telefono',
                        icon: Icons.phone_outlined,
                        margin: EdgeInsets.only(left: 50, right: 50, top: 15),
                        onChanged: (text) {
                          
                        },
                        
                      ),
                      DefaultTextFieldOutlined(
                        text: 'Password',
                        icon: Icons.lock_outlined,
                        margin: EdgeInsets.only(left: 50, right: 50, top: 15),
                        onChanged: (text) {
                          
                        },
                        
                      ),
                      DefaultTextFieldOutlined(
                        text: 'Confirmar Password',
                        icon: Icons.lock_outlined,
                        margin: EdgeInsets.only(left: 50, right: 50, top: 15),
                        onChanged: (text) {
                          
                        },
                        
                      ),

                      SizedBox(
                        height: 40,
                      ),

                      //****boton de registrase */
                      DefaultButton(
                        onPressed: () {
                          
                        },
                        text: 'Crear usuario',
                        color: Color(0xFF6041a2),
                        textColor: Colors.white,
                        margin: EdgeInsets.only(top: 20, left: 55, right: 55),
                      ),
                      SizedBox(height: 25),
                      _separatorOr(),
                      SizedBox(height: 10),
                      _textIAlreadyHaveAccount(context)
                    ],
                  ),
                ),
              ],
            ),
        ),
      ],
    );
  }


  Widget _textRegisterRotated() {
    return RotatedBox(
      quarterTurns: 1,
      child: Text(
        'Registro',
        style: TextStyle(
            fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _textLoginRotated(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
      },
      child: RotatedBox(
        quarterTurns: 1,
        child: Text(
          'Login',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _imageMedcar() {
    return Container(
      margin: EdgeInsets.only(
        top: 50,
      ),
      alignment: Alignment.center,
      child: Image.asset(
        'assets/img/medcar_logo_color.png',
        width: 400,
        height: 200,
      ),
    );
  }

  Widget _separatorOr() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 25,
          height: 1,
          color: Colors.black,
          margin: EdgeInsets.only(right: 5),
        ),
        Text(
          'O',
          style: TextStyle(color: Colors.black, fontSize: 17),
        ),
        Container(
          width: 25,
          height: 1,
          color: Colors.black,
          margin: EdgeInsets.only(left: 5),
        ),
      ],
    );
  }

  Widget _textIAlreadyHaveAccount(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Ya tienes cuenta?',
          style: TextStyle(color: Colors.grey[900], fontSize: 16),
        ),
        SizedBox(width: 5),
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Text(
            'Inicia sesion',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _imageBackground(BuildContext context) {
    return Container(
      alignment: Alignment.bottomCenter,
      margin: EdgeInsets.only(bottom: 300),
      child: Image.asset(
        'assets/img/celular_con_ambulancia_3d.png',
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.4,
        opacity: AlwaysStoppedAnimation(0.3),
      ),
    );
  }
}