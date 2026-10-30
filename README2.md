# Evolution — el servidor de WhatsApp por QR

> Proyecto aparte, como `ws_ela` (decisión del usuario, 2026-10-14): **no va dentro de Ela ni de ws_ela**. Se deploya por Forge.
> Node 22 · MySQL. Sin Laravel y sin Docker.

## Qué es

**Evolution API v2** (<https://github.com/EvolutionAPI/evolution-api>) es un servidor de código abierto, en Node, que hace de
«WhatsApp Web» para otros sistemas. El cliente escanea un QR con su celular y queda un número vinculado: lo que le escriben
llega por webhook y lo que se le manda sale por HTTP. Su interfaz es el **manager** (`/manager`): los números vinculados, su estado
y el QR.

Un solo Evolution sirve a **cualquier cantidad de proyectos**. Cada uno se conecta con la URL y la clave, y nombra sus instancias con
su propio prefijo. Cómo se conecta un proyecto: [conectar-un-proyecto.md](conectar-un-proyecto.md).

## Decisiones

| Decisión | Motivo |
|---|---|
| **Un solo proyecto: este repo ES Evolution** (2026-10-16): el código oficial más nuestros `docs/` y `deploy/`. Sin Laravel, sin panel propio; la interfaz es el manager. | El usuario pidió lo más simple. Antes había un Laravel acá y Evolution en otra carpeta, y no se entendía qué era cada cosa. |
| **No se toca el código de Evolution.** Lo nuestro: `docs/`, `deploy/`, `README.md`, `CLAUDE.md`, `AGENTS.md`, `.env.example`. | Así se actualiza entero con `deploy/actualizar-evolution.sh <tag>`, sin mezclar cambios. |
| Se sacaron del código oficial: Docker, los workflows de GitHub, husky/commitlint y el submódulo del manager. | No se usan. Los workflows correrían en nuestro GitHub y commitlint bloquearía los commits en español. El manager ya viene compilado en `manager/`. |
| **Sin Docker** (2026-10-16): en Forge corre como **daemon** y en local con Node desde Herd. Base MySQL y caché en memoria, sin Redis. | El ecosistema del usuario es Herd y Forge. Evolution v2 soporta MySQL, y con un solo proceso no hace falta Redis. |
| **El sitio de Forge va sin «zero downtime».** | Las sesiones viven en la base **y** en `instances/`. Con releases, cada deploy arrancaría con un `instances/` vacío. |
| **Versión en uso: Evolution `2.3.7`** (2026-10-16). Nunca la rama principal. | Es el v2 estable más nuevo: `2.4.0` sigue en RC. En los chats `@lid` ya reemplaza `remoteJid` por `remoteJidAlt` antes de mandar el webhook (`whatsapp.baileys.service.ts` L1478). Sólo desvincula con 401, 402, 403 y 406, igual que lo que espera Ela. |
| **El manager lleva nuestra marca y arranca en español** (`deploy/marca-manager.sh`, 2026-10-16): logo y favicon propios (`deploy/marca/`), título «Evolution · WhatsApp por QR». | El manager de 2.3.7 carga el logo y el favicon de `evolution-api.com`, que dan 404: se veían rotos. Es el único cambio sobre el código oficial; `actualizar-evolution.sh` lo vuelve a aplicar. |
| La clave global es **una sola para todos los proyectos**. | Quien la tiene maneja todas las instancias, y crear una instancia la exige. Se acepta porque hoy los proyectos son todos nuestros. A un proyecto de un tercero se le da **sólo el token de su instancia** (ver [conectar-un-proyecto.md](conectar-un-proyecto.md)). |
| No se importa el historial viejo del celular (`DATABASE_SAVE_DATA_HISTORIC=false`). | Nadie lo lee y llena la base. |

## Local (Herd)

Una sola vez:

```bash
cp .env.example .env                              # SERVER_URL=https://evolution.test, una clave y la base
herd proxy evolution http://127.0.0.1:8080 --secure   # https://evolution.test → Evolution
```

La base `evolution_api` se crea antes en la MySQL de Herd (utf8mb4). En el `.env`:
`DATABASE_CONNECTION_URI=mysql://root:<clave>@127.0.0.1:3306/evolution_api`.

Cada vez que cambia el código (o la primera vez): `bash deploy/instalar.sh`. Para usarlo, **`deploy\iniciar-local.cmd`**
(doble clic o desde la terminal). Queda corriendo en esa ventana; se apaga con Ctrl+C o cerrándola.

Se entra por <https://evolution.test/manager> con la URL (`https://evolution.test`) y la clave del `.env`.

⚠️ **`evolution.test` no figura en la lista de sitios de Herd, y no tiene que figurar**: es un *proxy* (`herd proxies`), no un
sitio PHP. Si Herd muestra su 404 («couldn't find a PHP file»), es que perdió el proxy. Pasó el 2026-10-16: se le activó HTTPS al sitio
desde Herd y lo regeneró como PHP. Se arregla volviendo a correr `herd proxy evolution http://127.0.0.1:8080 --secure`. Si en cambio
da 502, el proxy está bien y lo que falta es arrancar Evolution.

**Webhooks a otro proyecto local, sin túnel:** los `*.test` de Herd tienen certificado propio y Node lo rechaza
(`UNABLE_TO_VERIFY_LEAF_SIGNATURE`). `iniciar-local.cmd` arranca con `NODE_EXTRA_CA_CERTS` apuntando al certificado de Herd, así
Evolution le entrega los mensajes a `https://ela_gestion_laravel.test` directo (probado 2026-10-16: 200 `{"recibido":true}`). Con
`npm run start:prod` a secas, no llegan. La alternativa es el túnel de Herd: `expose share https://ela_gestion_laravel.test` y esa URL en
`WHATSAPP_QR_WEBHOOK_URL` de Ela.

**Probar con Ela local:** en el `.env` de Ela, `EVOLUTION_URL=https://evolution.test`, `EVOLUTION_APIKEY` (la clave de acá) y
`WHATSAPP_QR_PREFIJO=ela-local-`. Después, el guion de `ela_gestion_laravel/docs/pruebas/whatsapp.md` → «LA PRUEBA QUE IMPORTA».

## Dónde quedó (2026-10-22)

**Producción: anda.** `https://evolution.lugariaprop.com` responde con el JSON de Evolution 2.3.7, el manager entra con la clave
global y un pedido sin clave da 401. Servidor `ela-hostinger-vps` (IP `76.13.225.245`, MySQL 8.4), sitio **Other**, base
`evolution` con el usuario `evo-lugaria` (ya en `caching_sha2_password`). Las dos credenciales que habían quedado escritas en un
chat (la `AUTHENTICATION_API_KEY` y la clave de `evo-lugaria`) se cambiaron el 2026-10-22: las genera el servidor
(`openssl rand`) y no se escriben en ningún lado fuera del `.env` del sitio.

**Lo que falta, y lo hace quien tiene el acceso (Forge, el `.env` de Ela, los celulares):**

- **Conectar Ela de producción** (paso 8 de abajo) con `EVOLUTION_URL=https://evolution.lugariaprop.com`, la clave nueva y
  `WHATSAPP_QR_PREFIJO=ela-`.
- **La prueba con dos celulares** (paso 9).

## Producción en Forge (falta)

1. **Servidor:** cualquiera de Forge con Node 22. Puede ser el de ws_ela si le sobra RAM: ~300-500 MB, más ~50 MB por número
   vinculado. Que el firewall deje sólo 22, 80 y 443 (lo de Forge por defecto): **8080 no se abre**.
2. **Base:** en Servidor → Database, crear `evolution_api` y un usuario con su clave.
3. **DNS:** el subdominio (ej. `wa.elagestion.com.ar`) apunta al servidor.
4. **Sitio** con ese dominio, repo `evolution` y rama `main`. En «Advanced settings», **sin zero downtime**. Además:
   - Certificado Let's Encrypt.
   - nginx: el bloque de `deploy/nginx-forge.conf`.
   - Deploy script: `deploy/forge-deploy.sh`.
5. **`.env`** (Sitio → Environment, o por SSH): copiar `.env.example` y completar:
   - `SERVER_URL` con `https`;
   - una clave **nueva** (`openssl rand -hex 32`, no la local);
   - el `DATABASE_CONNECTION_URI` del paso 2.
6. **Daemon:** Servidor → Daemons, con estos datos:
   - comando: `node /home/forge/<sitio>/dist/main`;
   - directorio: `/home/forge/<sitio>`;
   - usuario: `forge`.
7. **Deploy.** Queda bien si `curl -H "apikey: …" https://wa.elagestion.com.ar/instance/fetchInstances` da 200, y con otra clave
   da 401.
8. **Conectar Ela** con las tres variables de [conectar-un-proyecto.md](conectar-un-proyecto.md#ela-gestión). En Admin → Acciones
   necesarias, la ficha `whatsapp.qr_sin_evolution` deja de pedirlo.
9. **Probar de punta a punta** con `ela_gestion_laravel/docs/pruebas/whatsapp.md` (Q1-Q24) y dos celulares. Después, reiniciar el
   daemon y comprobar que el número sigue vinculado.
10. **Anotar acá** lo que la guía decía y el servidor contestó distinto.

## Lo aprendido contra el servidor real (local, 2026-10-16)

Se probó la secuencia del componente de Ela contra Evolution 2.3.7 con MySQL y sin Docker:

- `create` → 201 con `qrcode.base64`.
- `webhook/set` anidado → 201; plano → 400 («instance requires property "webhook"»).
- `connectionState` → 404 si no existe y `connecting` si espera el QR. `connect` → `base64`.
- `fetchInstances?instanceName=` → lista con `name` y `ownerJid` (`null` hasta vincular).
- `sendText` sin vincular → 500 «Connection Closed».

Lo que la guía decía distinto:

- **`logout` sobre una instancia que espera el QR da 200 `SUCCESS`, no 400.** Ela tolera los dos.
- Las fechas de la base mezclan zonas (`createdAt` en hora local y `updatedAt` en UTC). Es cosmético: Ela no las lee.

Falta probarlo con un celular: el sobre real de `messages.upsert` y `connection.update`, y que un reinicio no desvincule.

Y en Forge:

- **Los usuarios de MySQL que crea Forge en `ela-hostinger-vps` quedan con `sha256_password`**, y Prisma no los soporta
  (`Unknown authentication plugin`). Hay que pasarlos a `caching_sha2_password` con `sudo mysql`.
- `SERVER_TYPE` va en `http`: con `https`, Evolution busca sus propios certificados y no arranca (el https lo pone nginx).
- El repo nuevo no se clona con la llave del servidor: el sitio necesita **deploy key**.
- Un sitio **Other** de Forge no tiene bloque PHP en el nginx: sólo se reemplaza su `location /`.
- El `"manager": "http://…"` del JSON de la raíz sale de `SERVER_TYPE=http` (que tiene que quedar así: el https lo pone nginx);
  no quiere decir que `SERVER_URL` esté mal. En producción `SERVER_URL` ya es `https://evolution.lugariaprop.com` (2026-10-22).
- **En Forge, el bloque de `deploy/nginx-forge.conf` no va en el archivo que muestra el editor de nginx del sitio**: ése sólo
  incluye `forge-conf/<id del sitio>/site.conf`, que es donde quedaron los `location`. Para tocarlos: `sudo` sobre
  `/etc/nginx/forge-conf/<id>/site.conf`, `sudo nginx -t` y `sudo service nginx reload` (2026-10-22).
- **La raíz no se redirige al manager** (2026-10-22): el manager valida la «URL del Servidor» pidiendo `/` y esperando el JSON de
  Evolution. Con el `return 302 /manager/` que tenía `deploy/nginx-forge.conf`, el login decía «Servidor inválido». Se sacó.

## Operación

| Para | Cómo |
|---|---|
| Ver los logs | Servidor → Daemons → Log |
| Reiniciar sin desvincular | Servidor → Daemons → Restart |
| Cambiar la configuración | editar el `.env` del sitio y reiniciar el daemon |
| Cambiar de versión | `bash deploy/actualizar-evolution.sh <tag>`, `bash deploy/instalar.sh`, probar en local, anotarlo en «Decisiones», commitear y deployar |

⚠️ **Nunca borrar `instances/` ni la base `evolution_api`**: se desvinculan todos los números.

## Dónde está el resto

| Qué | Dónde |
|---|---|
| Contrato del componente de Ela (cuerpos, webhook, trampas) | `ela_gestion_laravel/packages/whatsapp-qr/README.md` |
| Guía original del servidor (con Docker; insumo de este repo) | `ela_gestion_laravel/docs/integraciones/evolution.md` |
| El proyecto hermano que sirve de modelo (Forge, deploy) | `ws_ela` |
