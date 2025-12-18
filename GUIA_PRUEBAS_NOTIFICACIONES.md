# 🔔 Guía de Pruebas - Notificaciones Push MED-CAR

## 📋 Pasos para Probar

### 1️⃣ **Obtener el Token FCM**

1. **Ejecuta la app en tu dispositivo/emulador:**
   ```bash
   flutter run
   ```

2. **Inicia sesión en la app** (esto enviará el token al backend automáticamente)

3. **Revisa los logs de Flutter** - Deberías ver:
   ```
   FCM Token: [tu-token-fcm-aqui]
   Token FCM enviado al backend: [tu-token-fcm-aqui]
   ```

4. **Copia el token FCM** de los logs

---

### 2️⃣ **Probar desde Firebase Console** (Método Rápido)

1. **Ve a Firebase Console:**
   - https://console.firebase.google.com
   - Selecciona tu proyecto MED-CAR

2. **Navega a Cloud Messaging:**
   - En el menú lateral: **Engage** → **Cloud Messaging**

3. **Envía una notificación de prueba:**
   - Click en **"Send your first message"** o **"New campaign"**
   - Selecciona **"Firebase Notification messages"**
   - Ingresa:
     - **Título:** "Prueba de Notificación"
     - **Texto:** "Esta es una notificación de prueba"
   - Click en **"Send test message"**
   - Pega tu **Token FCM** (del paso 1)
   - Click en **"Test"**

4. **Verifica que llegue la notificación** en tu dispositivo

---

### 3️⃣ **Probar desde el Backend** (Método Real)

#### Opción A: Usando Postman/Thunder Client

**Endpoint:** `POST https://fcm.googleapis.com/v1/projects/[TU-PROJECT-ID]/messages:send`

**Headers:**
```
Authorization: Bearer [TU-ACCESS-TOKEN]
Content-Type: application/json
```

**Body (JSON):**
```json
{
  "message": {
    "token": "[TOKEN-FCM-DEL-DISPOSITIVO]",
    "notification": {
      "title": "Nueva Solicitud de Emergencia",
      "body": "Tienes una nueva solicitud de emergencia médica"
    },
    "data": {
      "type": "service_request",
      "role": "company",
      "requestId": "123"
    }
  }
}
```

#### Opción B: Desde tu Backend Node.js/Express

```javascript
const admin = require('firebase-admin');

// Enviar notificación
async function sendNotification(fcmToken, notificationData) {
  const message = {
    token: fcmToken,
    notification: {
      title: notificationData.title,
      body: notificationData.body,
    },
    data: {
      type: notificationData.type,
      role: notificationData.role,
      requestId: notificationData.requestId || '',
      userLat: notificationData.userLat || '',
      userLng: notificationData.userLng || '',
    },
    android: {
      priority: 'high',
    },
    apns: {
      headers: {
        'apns-priority': '10',
      },
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Notificación enviada:', response);
    return response;
  } catch (error) {
    console.error('Error al enviar notificación:', error);
    throw error;
  }
}

// Ejemplo de uso
sendNotification('TOKEN-FCM-AQUI', {
  title: 'Ambulancia Asignada',
  body: 'Tu ambulancia está en camino',
  type: 'ambulance_assigned',
  role: 'client',
  requestId: '123',
  userLat: '-17.3935',
  userLng: '-66.1570',
});
```

---

### 4️⃣ **Escenarios de Prueba**

#### ✅ **Escenario 1: App en Primer Plano**
1. Abre la app y déjala en primer plano
2. Envía una notificación
3. **Resultado esperado:**
   - Debe aparecer una notificación en la barra de notificaciones
   - Debe vibrar y sonar
   - Al tocar, debe navegar según el tipo

#### ✅ **Escenario 2: App en Segundo Plano**
1. Abre la app y luego minimízala (presiona el botón home)
2. Envía una notificación
3. **Resultado esperado:**
   - Debe aparecer en la barra de notificaciones
   - Al tocar, debe abrir la app y navegar

#### ✅ **Escenario 3: App Cerrada**
1. Cierra completamente la app
2. Envía una notificación
3. **Resultado esperado:**
   - Debe aparecer en la barra de notificaciones
   - Al tocar, debe abrir la app y navegar

---

### 5️⃣ **Probar Navegación Automática**

#### Prueba 1: Ambulancia Asignada (Cliente)
```json
{
  "data": {
    "type": "ambulance_assigned",
    "role": "client",
    "requestId": "123",
    "userLat": "-17.3935",
    "userLng": "-66.1570"
  }
}
```
**Resultado esperado:** Debe navegar a la pantalla de tracking

#### Prueba 2: Nueva Solicitud (Empresa)
```json
{
  "data": {
    "type": "service_request",
    "role": "company"
  }
}
```
**Resultado esperado:** Debe navegar a `company/home`

#### Prueba 3: Servicio Completado (Cliente)
```json
{
  "data": {
    "type": "service_completed",
    "role": "client",
    "serviceRequestId": "123",
    "driverName": "Juan Pérez",
    "ambulancePlate": "ABC-123"
  }
}
```
**Resultado esperado:** Debe navegar a la pantalla de calificación

---

### 6️⃣ **Verificar Logs**

Revisa los logs de Flutter para ver:
- ✅ Token FCM obtenido
- ✅ Token enviado al backend
- ✅ Notificación recibida
- ✅ Tipo de notificación
- ✅ Navegación ejecutada

**Ejemplo de logs esperados:**
```
FCM Token: [token]
Token FCM enviado al backend: [token]
=== NOTIFICACIÓN EN PRIMER PLANO ===
Message ID: [id]
Título: [título]
Cuerpo: [cuerpo]
Datos: {type: ambulance_assigned, role: client, ...}
=== NAVEGANDO DESDE NOTIFICACIÓN ===
Tipo: ambulance_assigned
```

---

### 7️⃣ **Solución de Problemas**

#### ❌ **No llegan las notificaciones:**
- Verifica que el token FCM se haya obtenido
- Verifica que los permisos de notificaciones estén concedidos
- Revisa que `google-services.json` esté en `android/app/`
- Verifica la conexión a internet

#### ❌ **No navega al tocar:**
- Verifica que el tipo de notificación esté en `data.type`
- Revisa los logs para ver qué tipo recibió
- Verifica que el NavigatorKey esté configurado

#### ❌ **Token no se envía al backend:**
- Verifica que el login/registro sea exitoso
- Revisa los logs para errores
- Verifica que el endpoint `/users/fcm-token` esté funcionando

---

### 8️⃣ **Comandos Útiles**

```bash
# Ver logs de Flutter
flutter run

# Ver logs específicos de notificaciones
flutter run | grep -i "notification\|fcm\|token"

# Limpiar y reconstruir
flutter clean
flutter pub get
flutter run
```

---

## 📝 Checklist de Pruebas

- [ ] Token FCM se obtiene al iniciar la app
- [ ] Token se envía al backend después del login
- [ ] Notificación llega en primer plano
- [ ] Notificación llega en segundo plano
- [ ] Notificación llega con app cerrada
- [ ] Navegación funciona al tocar notificación
- [ ] Diferentes tipos de notificaciones navegan correctamente
- [ ] Logs muestran información detallada

---

## 🎯 Tipos de Notificaciones para Probar

| Tipo | Rol | Navega a |
|------|-----|----------|
| `service_request` | `company` | `company/home` |
| `ambulance_assigned` | `client` | `client/tracking` |
| `request_status_update` | `client` | `client/tracking` |
| `service_completed` | `client` | `client/rating` |
| `shift_started` | `driver` | `driver/home` |

---

¡Listo para probar! 🚀

