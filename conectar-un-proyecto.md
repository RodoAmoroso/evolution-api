# Conectar un proyecto a Evolution

Cualquier proyecto (Ela, ws_ela, otro) habla con el mismo Evolution por HTTP. El modelo de referencia es el componente
`ela_gestion_laravel/packages/whatsapp-qr`, que ya hace todo lo de abajo: si el proyecto nuevo es Laravel, conviene copiarlo
(`packages/<x>` con `path` interno) antes que reescribirlo.

## Lo que necesita cada proyecto

| Variable | Valor |
|---|---|
| `EVOLUTION_URL` | La URL del sitio, **sin barra final** (`https://wa.elagestion.com.ar`; en local `https://evolution.test`) |
| `EVOLUTION_APIKEY` | La `AUTHENTICATION_API_KEY` del `.env` de este proyecto en el servidor. Viaja en el header `apikey` de cada pedido. |
| Un **prefijo** de instancias | Propio del proyecto **y del entorno**: `ela-`, `ela-local-`, `wsela-`. Sólo `[A-Za-z0-9_-]`. |

⚠️ **El prefijo es lo único que separa a un proyecto de otro.** Si dos proyectos (o local y producción) usan el mismo prefijo y el
mismo id, vincular en uno le cierra la sesión al otro. Y la clave es una sola: cualquier proyecto puede tocar las instancias de los
demás. Por eso se piden instancias **sólo por nombre propio**, nunca se itera `fetchInstances` sin filtro.

## Instancia = un número

Una instancia es **un número de WhatsApp vinculado** (una sesión de «Dispositivos vinculados»), no una web. Tiene **un** webhook:
la URL adonde Evolution manda lo que le escriben a ese número.

- Varias webs, cada una con su número: una instancia por número, cada una con el webhook de su web. Ela lo hace sola: una por
  cliente (`ela-cliente-5-ab12cd`).
- Varias webs con el mismo número: una sola instancia. Todas pueden enviar por ella, pero lo que entra va a un solo webhook.
- El canal es siempre **Baileys** (el QR). «WhatsApp Cloud API» es la API oficial de Meta, que ya la maneja ws_ela. «Evolution» es
  un canal genérico para conectar fuentes propias. Ninguno de los dos se usa acá.

**Token por instancia** (`auth.guard.ts`): cada instancia tiene su propio `token` (viene como `hash` al crearla y en
`fetchInstances`). En el header `apikey` sirve **sólo para las rutas de esa instancia** (`/message/sendText/{instancia}`, etc.). Crear
instancias exige la clave global. A un proyecto que no es nuestro se le crea la instancia y se le da sólo ese token.

## Endpoints que se usan

Todos llevan `apikey: <EVOLUTION_APIKEY>` y `Accept: application/json`. Un 401 significa clave equivocada.

| Para | Pedido | Cuerpo | Se lee |
|---|---|---|---|
| Estado | `GET /instance/connectionState/{instancia}` | — | `instance.state`: `open`, `connecting` o `close`. 404 = no existe. |
| Crear | `POST /instance/create` | `{"instanceName":"…","integration":"WHATSAPP-BAILEYS","qrcode":true,"groupsIgnore":true}` | `qrcode.base64` (`data:image/png;base64,…`) |
| Webhook | `POST /webhook/set/{instancia}` | ver abajo: **va anidado en `webhook`** | — |
| QR nuevo | `GET /instance/connect/{instancia}` | — | `base64`, `pairingCode`, `code`, `count`; o `instance.state=open` si ya está conectada |
| Número vinculado | `GET /instance/fetchInstances?instanceName={instancia}` | — | el ítem con `name === instancia` → dígitos de `ownerJid` |
| Desvincular | `DELETE /instance/logout/{instancia}` | — | 400 si no estaba conectada; 404 si no existe |
| Enviar texto | `POST /message/sendText/{instancia}` | `{"number":"5491122334455","text":"…"}` (sólo dígitos) | `key.id` |

El orden al vincular: `connectionState` → (404) `create` → **siempre** `webhook/set` → si no vino un QR válido, `connect`. El QR rota
cada ~20 s y se corta después de 30 intentos (`QRCODE_LIMIT`): la pantalla lo pide de nuevo con `connect` mientras espera.

### El webhook

```json
{
  "webhook": {
    "enabled": true,
    "url": "https://proyecto.com/webhooks/whatsapp-qr",
    "headers": { "X-Webhook-Token": "<hmac propio de la instancia>" },
    "byEvents": false,
    "base64": false,
    "events": ["MESSAGES_UPSERT", "CONNECTION_UPDATE"]
  }
}
```

Plano (como dice la doc web) da **400**. El campo `apikey` que viene en el cuerpo de cada webhook es el token de la instancia y **no
autentica nada**: la autenticación es el header propio (`X-Webhook-Token`), comparado con `hash_equals`. El webhook responde siempre
200, aunque el token no valide, para no revelar nada.

Lo que llega (`event` puede venir `messages.upsert` o `MESSAGES_UPSERT`: normalizar):

- **`messages.upsert`**: `data.key.{remoteJid, fromMe, id}`, `data.pushName`, el texto en `data.message.conversation` o
  `data.message.extendedTextMessage.text` (o `imageMessage.caption`). Se descartan `fromMe`, grupos (`@g.us`), `status@broadcast` y
  canales. Si el `remoteJid` termina en `@lid`, el número real está en `remoteJidAlt` (la v2.3.7 ya lo reemplaza sola). El teléfono son
  los dígitos antes del `@` y sin el `:dispositivo`. **Deduplicar por `key.id`**: Evolution reintenta si el webhook no da 2xx.
- **`connection.update`**: `data.state` y `data.statusReason`. `open` = vinculado (el número en `data.wuid`). `close` con 401, 402,
  403 o 406 = el cliente desvinculó: hay que volver a mostrar el QR. **Cualquier otro motivo se ignora (515 no es un logout: es el
  reinicio de Baileys después de escanear)**, porque Evolution reconecta solo.

## Trampas

- `logout` es asíncrono: devuelve éxito y la sesión sigue `open` unos segundos.
- Si cambia el dominio del proyecto, su `APP_KEY` o el túnel, los webhooks van a la URL vieja (o dejan de validar) hasta volver a
  llamar `webhook/set`. Eso no pide escanear de nuevo.
- En local, Evolution se arranca con `deploy\iniciar-local.cmd` para que los webhooks lleguen a los `*.test` de Herd (confía en su
  certificado). Si no, el túnel de Herd: `expose share`.
- Meta puede banear un número que usa Evolution: no es la API oficial. Para volumen, la API de Meta (ws_ela).

## Ela Gestión

En el `.env` de `ela_gestion_laravel`:

```dotenv
EVOLUTION_URL=https://wa.elagestion.com.ar
EVOLUTION_APIKEY=<AUTHENTICATION_API_KEY del servidor>
WHATSAPP_QR_PREFIJO=ela-            # local: ela-local-   ·   tests: ela-test- (ya está en phpunit.xml)
# WHATSAPP_QR_WEBHOOK_URL=https://<tunel>/webhooks/whatsapp-qr   # sólo en local
```

Admin → Acciones necesarias, ficha `whatsapp.qr_sin_evolution`, deja de pedirlo.
