# Enchufe ELIVCO LSPA9 con OpenBeken (limitador de carga)

Objetivo: sustituir el firmware Tuya del enchufe **ELIVCO LSPA9** por **OpenBeken** ([OpenBK7231T_App](https://github.com/openshwprojects/OpenBK7231T_App)) para que lo controle el Mosquitto del móvil sin nube, y usarlo con `charge-limiter` ([always-on-battery.md § 9](always-on-battery.md#9-limitador-de-carga-y-guardián-térmico-opt-in)).

> ⚠️ **Peligro de muerte:** el LSPA9 tiene una **fuente sin transformador** (BP2525 o similar): la placa entera, incluida su «masa», está conectada a la red de 230 V. **Nunca** abras, sueldes, conectes un adaptador USB‑UART ni toques la placa con el enchufe en la pared. El flasheo por UART se hace **desenchufado de la red**, alimentando solo la parte de 3,3 V desde el adaptador. Cierra la carcasa antes de volver a enchufarlo.

---

## 1. Identificar la variante

«LSPA9» es un nombre genérico: hay placas distintas con el mismo exterior. Lo que importa es el **chip Wi‑Fi** y el **chip de medida**.

| Variante | Módulo / chip | Medida | Cómo flashear | Fuente |
|----------|---------------|--------|---------------|--------|
| A | **CB2S (BK7231N)** | **BL0942** (UART) | cloudcutter (si el firmware es vulnerable) o UART | [elektroda 3887748](https://www.elektroda.com/news/news3887748.html) |
| B | **CB2S (BK7231N)** | **BL0937** (pulsos CF/CF1/SEL) | cloudcutter o UART | [elektroda 3979012](https://www.elektroda.com/news/news3979012.html) |
| C | placa **BSD342-2110**, módulo «WL2S» = **LN882H** | **BL0937** | **solo UART** (cloudcutter no tiene perfiles LN882H) | [elektroda 4036567](https://www.elektroda.com/news/news4036567.html) |

Cómo saberlo **sin abrirlo**:

1. App **Tuya / Smart Life** → el enchufe → ✏️ (arriba a la derecha) → **Información del dispositivo** / *Device Information*: apunta la **versión de firmware** (p. ej. `1.1.8`) y, si aparece, el **módulo**/ID de producto.
2. App → **Actualización de firmware**: **no actualices** si piensas usar cloudcutter (las versiones nuevas de Tuya suelen estar parcheadas).
3. Con firmware `1.1.6` o `1.1.8` en un módulo BK7231N, es muy probable que sirva cloudcutter (perfiles «LSPA9 Plug v1.1.6/v1.1.8», ver § 2).

Para confirmarlo **abriéndolo** (desenchufado): las dos mitades van ligeramente pegadas; presión uniforme en los laterales (en un tornillo de banco con cartón) hasta que cede ([elektroda 4036567](https://www.elektroda.com/news/news4036567.html)). Mira la serigrafía: **CB2S** (módulo pequeño con antena en pista) → A/B; **WL2S** sobre placa **BSD342-2110** → C. El chip de medida (BL0942 vs BL0937) está impreso en un SOP pequeño junto al shunt.

---

## 2. Camino A — OTA con tuya-cloudcutter (sin abrir, solo BK7231N)

[tuya-cloudcutter](https://github.com/tuya-cloudcutter/tuya-cloudcutter) explota una vulnerabilidad del firmware Tuya en chips Beken para instalar otro firmware **por Wi‑Fi**.

- **Perfiles LSPA9 existentes** (comprobado en el repo [tuya-cloudcutter.github.io](https://github.com/tuya-cloudcutter/tuya-cloudcutter.github.io), 2026-11-03):
  - `tuya-generic-lspa9-plug-v1.1.8` → perfil `oem-bk7231n-plug-1.1.8-sdk-2.3.1-40.00`
  - `tuya-generic-lspa9-plug-v1.1.6` → perfil `oem-bk7231n-plug-1.1.6-sdk-2.3.1-40.00`
  - `tuya-generic-lspa9-plug-v1.0.3` → perfil `oem-bk7231s-dltj-1.0.3-sdk-2.0.0-30.06` (BK7231T/S antiguo)
  - Buscador de dispositivos y perfiles: **https://tuya-cloudcutter.github.io/**
- **No hay perfil para LN882H** (variante C) → usa el camino B.
- **Requisitos** ([README](https://github.com/tuya-cloudcutter/tuya-cloudcutter#requirements) / [INSTRUCTIONS](https://github.com/tuya-cloudcutter/tuya-cloudcutter/blob/main/INSTRUCTIONS.md)): **Linux nativo** (no WSL; una VM solo con *passthrough* del adaptador) con **Docker** e `iw`, `sudo`, y un **adaptador Wi‑Fi aparte con modo AP** (se mueve entero al contenedor y desaparece del host durante la ejecución → la conexión a Internet mejor por cable). Una Raspberry Pi sirve. No se puede desde el móvil.
- Pasos (resumen; sigue INSTRUCTIONS.md):
  ```bash
  git clone https://github.com/tuya-cloudcutter/tuya-cloudcutter && cd tuya-cloudcutter
  sudo ./install-requirements.sh                       # docker + iw si faltan
  # El repo ya trae firmwares de terceros en custom-firmware/ (solo formatos UG/UF2). Si quieres
  # una versión concreta: el .bin «UG» de BK7231N de las releases de OpenBeken → custom-firmware/
  sudo ./tuya-cloudcutter.sh -w wlan1                  # menú: flashear firmware → perfil LSPA9 v1.1.x
  ```
  Cuando lo pida, pon el enchufe en **modo AP** (pulsación larga del botón hasta parpadeo lento; si no, apaga/enciende 6 veces). El script crea su AP `cloudcutterflash`; puede pedir otro ciclo de alimentación. Al terminar aparece la red abierta de OpenBeken (`OpenBK7231N_…`).
- Tuya parcheó su SDK en **febrero de 2022**: firmware compilado después no es explotable ([lista de firmware parcheado](https://github.com/tuya-cloudcutter/tuya-cloudcutter/wiki/Known-Patched-Firmware)).
- Si el script dice que el firmware está parcheado/no vulnerable → camino B.

## 3. Camino B — UART (abriendo el enchufe)

**Siempre desenchufado de la red.** Adaptador USB‑UART **a 3,3 V** (nunca 5 V en TX/RX). Herramientas:

- **BK7231N (CB2S):** [BK7231 GUI Flash Tool](https://github.com/openshwprojects/BK7231GUIFlashTool) (Windows) o `ltchiptool`. Conecta 3V3, GND, **TX1/RX1** del CB2S (cruzados con el adaptador) y CEN; el reset se hace poniendo **CEN a GND un instante** cuando la herramienta espera. Haz primero **backup** (Read) del firmware original. En la variante BL0942 el chip de medida comparte la UART, pero según la guía no hace falta desoldarlo ([3887748](https://www.elektroda.com/news/news3887748.html)). Si hay problemas, alimenta el módulo directamente con 3,3 V y desconecta la entrada del LDO.
- **LN882H (BSD342-2110):** BK7231 GUI Flash Tool (soporta LN882H), `ltchiptool` (tiene soporte `ln882h`) o `LN882H_CMD_Tool` de Lightning Semi. Según [4036567](https://www.elektroda.com/news/news4036567.html): bastan **3V3, RX0, TX0** (pads de UART0 en la placa principal; la UART1 de la parte trasera del módulo solo saca el log de arranque) y se puede usar como GND el **pin de potencia opuesto al módulo**: eso demuestra que la masa de la placa está unida a la red → **jamás** con el enchufe conectado. Para entrar en modo flasheo, **A9 a GND unos segundos justo tras dar alimentación** (si el LED empieza a parpadear normal, has llegado tarde: repite). Funcionó a **115200** baudios, no a 200000. Binario: `OpenLN882H_*.bin` de las [releases](https://github.com/openshwprojects/OpenBK7231T_App/releases). En ese hilo, versiones 1.17.513+ daban reinicios en algunas placas y 1.17.521/1.17.530 iban bien: si falla, prueba otra versión.

## 4. Configuración inicial de OpenBeken

1. Tras flashear aparece una **Wi‑Fi abierta** (`OpenBK7231N_…` / `OpenLN882H_…`). Conéctate y abre **http://192.168.4.1** ([docs/initialSetup.md](https://github.com/openshwprojects/OpenBK7231T_App/blob/main/docs/initialSetup.md)).
2. **Config → «Configure WiFi & Web»:** SSID y contraseña de casa (2,4 GHz) → guardar → reinicia. Busca la IP en el router y crea una **reserva DHCP** (IP fija) para el enchufe **y para el móvil** (el enchufe se conectará a la IP del móvil).
3. **Plantilla de pines** (Config → «Configure Module», o *Open Web Application* → importar plantilla). Elige la de tu variante; **verifica tu placa**, hay LSPA9 con mapas distintos ([lista de plantillas](https://openbekeniot.github.io/webapp/devicesList.html)):

   | Variante | Pines (rol;canal) | Extra |
   |----------|-------------------|-------|
   | B · BK7231N + BL0937 ([3979012](https://www.elektroda.com/news/news3979012.html)) | P6 `BL0937CF1;0` · P7 `BL0937CF;0` · P8 `WifiLED_n;0` · P11 `Btn;1` · P24 `BL0937SEL;0` · P26 `Rel;1` | — (la lista de plantillas tiene otra «ELIVCO LSPA9 BL0937» con el botón en P10) |
   | A · BK7231N + BL0942 ([3887748](https://www.elektroda.com/news/news3887748.html)) | P6 `Btn;1` · P8 `WifiLED_n;1` · P26 `Rel;1` (plantilla «ELIVCO LSPA9 BL0942 version») | Comando de arranque: `startDriver BL0942` (si no mide, prueba `startDriver BL0942 9600`) |
   | C · LN882H + BL0937 ([4036567](https://www.elektroda.com/news/news4036567.html)) | A0 `LED_n;0` · A3 `Btn;0` · A7 `BL0937CF1;0` · A10 `WifiLED_n;1` · A11 `Rel;0` · A12 `BL0937CF;0` · A19 `BL0937SEL;0` | El relé va en el **canal 0** → `PLUG_CHANNEL=0` |

   El **canal del relé** (número tras `Rel;`) es el que usa MQTT: **1** en las plantillas BK7231N, **0** en la LN882H.
4. **Config → «Configure Startup»:** estado inicial del canal del relé = **1 (ON)** o **-1 (recordar último)**. Para un móvil-servidor es más seguro **ON**: si el enchufe se reinicia, el móvil sigue cargando y `charge-limiter` lo volverá a apagar en ≤ 60 s.
5. **Config → «Configure MQTT»:**
   - **Host:** IP LAN (Wi‑Fi) del móvil, p. ej. `192.168.x.y` (reserva DHCP) · **Port:** `1883`
   - **Client Topic (Base Topic):** `lspa9` (= `PLUG_TOPIC`)
   - **User / Password:** los del listener LAN de Mosquitto (abajo)
   - El enchufe **no puede usar Tailscale** (no es un nodo de la tailnet): tiene que llegar al móvil por la Wi‑Fi de casa. Tailscale sirve para que *tú* veas Mosquitto/Node-RED desde fuera.
6. Opcional: **Config → «Configure General/Flags»** → «[MQTT] Broadcast self state every N seconds» (flag 2) para que publique potencia, IP, etc. periódicamente; «[MQTT] Retain power channels» (flag 21) si quieres el estado del relé retenido en el broker.

### Mosquitto del móvil escuchando en la Wi-Fi

El `mosquitto.conf` del repo (servicio runit `mosquitto`) escucha **solo en 127.0.0.1**. Añade un listener en la IP Wi‑Fi del móvil **con contraseña** (el limitador sigue usando 127.0.0.1 sin contraseña). En Termux (`~/.mosquitto/mosquitto.conf`, o `$PREFIX/etc/mosquitto/mosquitto.conf` si existe):

```conf
per_listener_settings true

listener 1883 127.0.0.1
allow_anonymous true

# IP Wi‑Fi del móvil (reserva DHCP en el router). bind_interface necesita root en este kernel → IP fija.
listener 1883 192.168.x.y
allow_anonymous false
password_file /data/data/com.termux/files/home/.mosquitto/passwd

persistence true
persistence_location /data/data/com.termux/files/home/.mosquitto/data/
```

```bash
mosquitto_passwd -c ~/.mosquitto/passwd lspa9     # contraseña que pondrás en el enchufe
sv restart mosquitto && sv status mosquitto
```

## 5. Calibración de la medida de energía

Sin calibrar, las lecturas son **muy erróneas** ([3887748](https://www.elektroda.com/news/news3887748.html)). Necesitas una carga **resistiva** conocida (bombilla incandescente, hervidor, calefactor; cos φ = 1) y un medidor fiable (o el voltaje medido con multímetro).

1. Enchufa la carga a través del LSPA9 con el relé **ON** y espera a que la lectura se estabilice.
2. En la consola web de OpenBeken (Web Application → Logs/Console, o `cmnd/lspa9/<comando>` por MQTT):
   ```
   VoltageSet 230.5
   CurrentSet 0.261
   PowerSet 60.1
   ```
   (con los valores **reales** medidos). Desde la 1.17.102 la calibración se guarda sola en flash ([commands.md](https://github.com/openshwprojects/OpenBK7231T_App/blob/main/docs/commands.md)).
3. Comprueba con otra carga. Opcional: `VCPPublishThreshold 0.5 0.02 1` (publicar solo cambios de ≥ 0,5 V / 20 mA / 1 W) en el comando de arranque.
4. Una carga de móvil (~5–25 W) está en la parte baja del rango: la medida será orientativa.

## 6. Topics MQTT de OpenBeken (verificados en el código/docs, 2026-11-03)

Fuente: [docs/mqttTopics.md](https://github.com/openshwprojects/OpenBK7231T_App/blob/main/docs/mqttTopics.md), [docs/faq.md](https://github.com/openshwprojects/OpenBK7231T_App/blob/main/docs/faq.md) y `src/mqtt/new_mqtt.c`, `src/driver/drv_bl_shared.c`, `src/cmnds/cmd_tasmota.c`.

| Topic | Dirección | Payload |
|-------|-----------|---------|
| `lspa9/<canal>/set` | → enchufe | `1` / `0` (fija el canal; con relé = ON/OFF) |
| `lspa9/<canal>/get` | ← enchufe | `1` / `0` al cambiar el canal (también al pulsar el botón) |
| `lspa9/<canal>/get` vacío | → enchufe | pide que publique el valor actual en el mismo topic |
| `cmnd/lspa9/POWER` | → enchufe | `ON` / `OFF` / `TOGGLE` / `1` / `0` estilo Tasmota; actúa sobre el **primer canal con relé** (vale para indexación 0 o 1) |
| `cmnd/lspa9/<comando>` | → enchufe | cualquier comando de OpenBeken (`VoltageSet 230`…) |
| `lspa9/power/get` · `voltage/get` · `current/get` | ← enchufe | W · V · A (BL0937/BL0942), al cambiar más que el umbral y en el envío periódico |
| `lspa9/energycounter/get` … | ← enchufe | Wh acumulados, hoy, última hora… |
| `lspa9/connected` | ← enchufe | `online` al conectar |
| `tele/lspa9/STATE`, `tele/lspa9/SENSOR`, `stat/lspa9/RESULT` | ← enchufe | JSON estilo Tasmota **solo** con el flag 30 «Enable Tasmota TELE etc publishes» |

**No confirmado:** que el «get» vacío funcione para `power` (la doc lo documenta para canales y variables tipo `led_dimmer`); si no responde, `charge-limiter plug power` espera al siguiente envío periódico. Tampoco está documentado que OpenBeken publique `stat/lspa9/POWER` como Tasmota, por eso el repo usa `lspa9/<canal>/get` para confirmar el estado.

## 7. Conectarlo al limitador de carga

Dos opciones (usa **una**):

**a) Directo desde `charge-limiter` (sin Node-RED)** — `~/.config/gt2-power/power.conf`:

```bash
PLUG_BACKEND=openbeken
PLUG_TOPIC=lspa9
PLUG_CHANNEL=1        # LN882H (variante C): 0
PLUG_OBK_CMD=channel  # o «power» → cmnd/lspa9/POWER ON|OFF
```

`sv restart charge-limiter`. El limitador publica `lspa9/<canal>/set`, confirma con `lspa9/<canal>/get` y publica `gt2/power/charger/plug_state` (ON/OFF/UNCONFIRMED/ERROR) y `gt2/power/charger/plug_power` (W). Al parar el limitador manda `CHARGE_FAILSAFE` (ON). Si usas esta opción, no despliegues el flujo de Node-RED (o déjalo en `dry-run`); el watchdog de 15 min de Node-RED solo existe en la opción b.

**b) Node-RED** — importa [`scripts/termux/node-red/charge-limiter-flow.json`](../scripts/termux/node-red/charge-limiter-flow.json); en la pestaña → *Environment*: `PLUG_TYPE=openbeken-mqtt`, `PLUG_MQTT_TOPIC=lspa9`, `PLUG_CHANNEL=1` (o `0`). Deja `PLUG_BACKEND=nodered` en `power.conf`.

## 8. Probar desde Termux

```bash
# Todo lo que publica el enchufe (Ctrl+C para salir)
mosquitto_sub -h 127.0.0.1 -t 'lspa9/#' -v
# Relé OFF / ON (canal 1; LN882H → lspa9/0/set)
mosquitto_pub -h 127.0.0.1 -t lspa9/1/set -m 0
mosquitto_pub -h 127.0.0.1 -t lspa9/1/set -m 1
# Estilo Tasmota
mosquitto_pub -h 127.0.0.1 -t cmnd/lspa9/POWER -m OFF
# Pedir el estado actual del canal
mosquitto_pub -h 127.0.0.1 -t lspa9/1/get -n
# Con el repo:
charge-limiter plug state      # ON|OFF
charge-limiter plug power      # W
charge-limiter plug off        # prueba (el limitador puede revertirlo en el siguiente ciclo)
charge-limiter force off; charge-limiter status; charge-limiter force auto
```

Desde fuera de casa, por Tailscale: `ssh` al móvil y los mismos comandos (el enchufe sigue hablando con el móvil por la LAN).

## Fuentes

- Guía CB2S + BL0942 (LSPA9): https://www.elektroda.com/news/news3887748.html
- LSPA9 BSD342-2110 con LN882H + BL0937 (plantilla, flasheo UART): https://www.elektroda.com/news/news4036567.html
- LSPA9 BK7231N/CB2S + BL0937 (plantilla): https://www.elektroda.com/news/news3979012.html
- OpenBeken: https://github.com/openshwprojects/OpenBK7231T_App — `docs/mqttTopics.md`, `docs/commands.md`, `docs/flags.md`, `docs/faq.md`, `docs/initialSetup.md`
- Plantillas OpenBeken: https://openbekeniot.github.io/webapp/devicesList.html
- tuya-cloudcutter: https://github.com/tuya-cloudcutter/tuya-cloudcutter · perfiles: https://tuya-cloudcutter.github.io/
- BK7231 GUI Flash Tool: https://github.com/openshwprojects/BK7231GUIFlashTool · ltchiptool: https://github.com/libretiny-eu/ltchiptool
