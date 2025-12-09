// ignore_for_file: use_key_in_widget_constructors, must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/auth/login/bloc/login_event.dart';
import 'package:medcar_frontend/src/presentation/widgets/default_button.dart';
import 'package:medcar_frontend/src/presentation/widgets/default_text_field.dart';

class LoginContent extends StatelessWidget {

  LoginBloc bloc;
  LoginContent(this.bloc);
  

  @override
  Widget build(BuildContext context) {
    return Form(
      key: bloc.state.formKey,
      child: Stack(
        children: [
          //****1 container pantalla compelta opcions de login y registro
          //container de fondo con gradiente
          Container(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
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
            padding: EdgeInsets.only(left: 12),
      
            //****configuracion de los textos
            child: Column(
              crossAxisAlignment: CrossAxisAlignment
                  .start, // HORIZONTAL --para centrar horizontal
              mainAxisAlignment:
                  MainAxisAlignment.center, // VERTICAL --para centrar vertical
              children: [
                _textLoginRotated(),
                SizedBox(height: 100),
                _textRegisterRotated(context),
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
              ],
            ),
          ),
      
          //**** 2 container del formulario de login
          Container(
            height: MediaQuery.of(context).size.height,
            margin: EdgeInsets.only(left: 60, bottom: 35),
            decoration: BoxDecoration(
              //color: Colors.white,
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: const [
                  Color.fromARGB(255, 255, 255, 255),
                  Color.fromARGB(255, 154, 154, 154),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(35),
                bottomLeft: Radius.circular(35),
              ),
            ),
      
            //******conteenido del fomrulario
            //contenido del formulario
            child: Container(
              margin: const EdgeInsets.only(left: 25, right: 25),
              child:SingleChildScrollView(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 5),
                  _imageMedcar(),
                  _text('Introduce tu correo electronico', 28),
                  _text('Te enviaremos un código para verificar tu correo', 18),
      
                  //***campo email
                  DefaultTextField(
                    onChanged: (text) {
                      bloc.add(EmailChanged(email: text));
                    },
                    text: 'Correo Electronico',
                    icon: Icons.email_outlined,
                  ),
      
                  //****campo pasword */
                  DefaultTextField(
                    onChanged: (text) {
                      bloc.add(PasswordChanged(password: text));
                    },
                    obscureText: true,
                    text: 'Contraseña',
                    icon: Icons.lock_outlined,
                    margin: EdgeInsets.only(top: 15, left: 20, right: 20),
                  ),
      
                  SizedBox(height: 40),
      
                  DefaultButton(
                    text: 'Iniciar Sesión',
                    //color: Color(0xAA4b4949),
                    color: Color(0xFF6041a2),
                    textColor: Colors.white,
      
                    onPressed: () {
                      // Acción al presionar el botón
                      context.read<LoginBloc>().add(FormSubmit());
                    },
                  ),
      
                  SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                  _separatorOr(),
                  SizedBox(height: 10),
                  _textDontHaveAccount(context),
                  SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _text(String text, double size) {
    return Container(
      alignment: Alignment.center, // Alinea el texto en el centro
      //margin: EdgeInsets.all(8.0), // Añade un margen de 20 puntos alrededor del texto
      padding: EdgeInsets.all(
        10.0,
      ), // Añade un padding de 10 puntos alrededor del  texto
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: size,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _imageMedcar() {
    return Container(
      padding: EdgeInsets.all(0),
      margin: EdgeInsets.all(0),
      alignment: Alignment.center,
      child: Image.asset(
        'assets/img/medcar_logo_color.png',
        width: 400, // ajustar el ancho segun sea necesario pixeles
        height: 300, // ajustar el alto segun sea necesario pixeles
      ),
    );
  }

  Widget _textDontHaveAccount(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'No tienes cuenta?',
          style: TextStyle(color: Colors.grey[900], fontSize: 16),
        ),
        SizedBox(width: 7),
        GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, 'register');
          },
          child: Text(
            'Registrate',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
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
        Text('O', style: TextStyle(color: Colors.black, fontSize: 17)),
        Container(
          width: 25,
          height: 1,
          color: Colors.black,
          margin: EdgeInsets.only(left: 5),
        ),
      ],
    );
  }

  Widget _textRegisterRotated(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, 'register');
      },
      child: RotatedBox(
        quarterTurns: 1,
        child: Text(
          'Registro',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }

  Widget _textLoginRotated() {
    return RotatedBox(
      quarterTurns: 1,
      child: Text(
        'Login',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
