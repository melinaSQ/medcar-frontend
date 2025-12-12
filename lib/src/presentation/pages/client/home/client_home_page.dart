import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_event.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_state.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/client_home_content.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  @override
  void initState() {
    super.initState();
    context.read<ClientHomeBloc>().add(ClientHomeInitEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClientHomeBloc, ClientHomeState>(
      listener: (context, state) {
        if (state.status == ClientHomeStatus.loggedOut) {
          Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
        }
      },
      child: BlocBuilder<ClientHomeBloc, ClientHomeState>(
        builder: (context, state) {
          return ClientHomeContent(state: state);
        },
      ),
    );
  }
}

