import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcar_frontend/dependency_injection.dart';
import 'package:medcar_frontend/src/data/services/socket_service.dart';
import 'package:medcar_frontend/src/domain/repositories/auth_repository.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_bloc.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_event.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/bloc/client_home_state.dart';
import 'package:medcar_frontend/src/presentation/pages/client/home/client_home_content.dart';
import 'package:medcar_frontend/src/utils/service_request_status.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  StreamSubscription<RequestUpdate>? _canceledSub;
  StreamSubscription<RequestUpdate>? _statusSub;

  @override
  void initState() {
    super.initState();
    context.read<ClientHomeBloc>().add(ClientHomeInitEvent());
    _bindRealtimeUpdates();
  }

  Future<void> _bindRealtimeUpdates() async {
    final session = await sl<AuthRepository>().getUserSession();
    if (!mounted || session == null) return;
    sl<SocketService>().connect(session.accessToken);

    await _canceledSub?.cancel();
    await _statusSub?.cancel();

    final socket = sl<SocketService>();
    _canceledSub = socket.onRequestCanceled.listen(_clearHomeActiveIfSameRequest);
    _statusSub = socket.statusUpdateStream.listen((update) {
      final normalized = normalizeServiceRequestStatus(
        update.requestDetails['status']?.toString(),
        hasAssignedShift: update.requestDetails['shift'] != null,
      );
      if (!isTerminalClientActiveStatus(normalized)) return;
      _clearHomeActiveIfSameRequest(update);
    });
  }

  void _clearHomeActiveIfSameRequest(RequestUpdate update) {
    if (!mounted) return;
    final bloc = context.read<ClientHomeBloc>();
    final activeId = parseServiceRequestId(bloc.state.activeServiceRequest?['id']);
    final evtId = parseServiceRequestId(update.requestDetails['id']);
    if (activeId != null && evtId == activeId) {
      bloc.add(ClientHomeClearActiveRequestEvent());
    }
  }

  @override
  void dispose() {
    _canceledSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClientHomeBloc, ClientHomeState>(
      listenWhen: (prev, curr) =>
          (curr.errorMessage != null && curr.errorMessage!.isNotEmpty) ||
          curr.status == ClientHomeStatus.loggedOut,
      listener: (context, state) {
        if (state.status == ClientHomeStatus.loggedOut) {
          Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
          return;
        }
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
          context.read<ClientHomeBloc>().add(ClientHomeClearErrorEvent());
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

