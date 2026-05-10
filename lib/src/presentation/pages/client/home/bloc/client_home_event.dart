abstract class ClientHomeEvent {}

class ClientHomeInitEvent extends ClientHomeEvent {}

/// Solo refresca la solicitud activa (p. ej. al volver del mapa o del seguimiento).
class ClientHomeRefreshActiveRequestEvent extends ClientHomeEvent {}

/// Limpia la solicitud activa en memoria (p. ej. tras cancelar en seguimiento o vía socket).
class ClientHomeClearActiveRequestEvent extends ClientHomeEvent {}

class ClientHomeCancelActiveRequestEvent extends ClientHomeEvent {}

class ClientHomeClearErrorEvent extends ClientHomeEvent {}

class LogoutEvent extends ClientHomeEvent {}
