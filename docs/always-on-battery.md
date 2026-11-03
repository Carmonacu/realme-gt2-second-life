# Always-on 24/7 + batería — Realme GT 2 (RMX3311), ColorOS 15, Plan B (Termux)

**Fecha:** 2026-10-31  
**Contexto:** Bootloader **bloqueado**, rol habitual **LLM local** + SSH/Tailscale; sin pruebas de laboratorio de ciclos de carga en este repo — solo **buenas prácticas** alineadas con [phone-tuning.md](phone-tuning.md), [second-life-ecosystem.md](second-life-ecosystem.md) y patrones comunitarios citados allí.  
**Estado Plan B:** [STATUS.md](STATUS.md).

---

## Resumen ejecutivo

| Tema | Conclusión |
|------|------------|
| **¿24/7 enchufado?** | **Parcialmente viable** como mini-servidor si aceptas **desgaste acelerado** de la batería y vigilas **hinchazón** / calor. |
| **ColorOS** | Exenciones Termux/Tailscale + **carga inteligente** / límite **80–90%** cuando exista; ver [phone-tuning.md § A y § Carga 24/7](phone-tuning.md). |
| **Wake-lock** | `termux-wake-lock` (scripts `llm`, `kali`, bootstrap) evita suspensión agresiva; **no** sustituye ventilación ni política de un solo servicio pesado. |
| **Térmica** | SD888 + LLM sostenido: sensores **~38–44 °C** bajo carga (medido en sesión LLM); batería ~**32 °C** en reposo enchufado al 100%. |
| **Cuándo NO** | Verano sin disipación, batería ya hinchada, modo ahorro activo, o intentar **dos** cargas pesadas a la vez — ver [phone-tuning.md § E](phone-tuning.md#e-mantener-el-rol-principal-política-operativa). |
| **Automatizado (opt-in)** | **Limitador 80 % / 45 % con enchufe inteligente** (MQTT + Node-RED) y **guardián térmico** del LLM (~40 °C) — [§ 9](#9-limitador-de-carga-y-guardián-térmico-opt-in). **Sin probar en el teléfono.** |

---

## 1. Enchufado continuo (24/7)

### 1.1 Qué significa en este proyecto

Patrón comunitario (Termux + SSH + Tailscale + servidor ligero): el teléfono actúa como **nodo always-on** en casa, enchufado, con **Termux** en primer plano o con notificación persistente y servicios ligeros en paralelo. Este repo ya opera **llama-server**, **sshd** y **Tailscale** bajo ese modelo; ver matriz en [second-life-ecosystem.md §3](second-life-ecosystem.md).

**No confundir** «always-on» con «todo encendido a la vez»: en **8 GB RAM** solo debe haber **un** servicio **pesado** de CPU/RAM activo (LLM **o** transcode Jellyfin **o** Metasploit masivo). Detalle operativo: [phone-tuning.md § E — Mantener el rol principal](phone-tuning.md#e-mantener-el-rol-principal-política-operativa).

### 1.2 Hardware de carga

- Usar **cargador y cable de calidad** (preferible el original o equivalente certificado **USB-PD** del GT2). Cable flojo = calor en el conector.
- **Evitar** fundas gruesas o móvil bajo cojín/manta mientras corre LLM o escaneos Kali largos.
- Colocar el teléfono en superficie **rígida y ventilada** (no cama acolchada 24/7).
- Si el puerto USB falla intermitente, **deja de usar 24/7** hasta revisar el conector (riesgo de arco/calor local).

### 1.3 Red y acceso remoto

- **Tailscale (app Android)** es el acceso remoto preferido — ya en whitelist Doze; ver [phone-tuning.md § Tailscale](phone-tuning.md).
- No hace falta mantener la pantalla encendida; sí conviene **bloquear Termux en recientes** y notificación de Termux visible cuando corre el servidor.

---

## 2. Degradación de batería e hinchazón

### 2.1 Mecanismo (sin alarmismo, con criterio)

Las baterías Li-ion **envejecen más rápido** con:

- Tiempo prolongado al **100%** y alta temperatura (**tropicalización** del electrodo).
- Ciclos parciales repetidos **caliente** (típico de carga + CPU sostenida).
- Estrés mecánico si la celda **hincha** (gas interno) — **riesgo de seguridad**.

Convertir un GT2 en servidor 24/7 **no es gratis**: es intercambiar **vida útil de batería** por utilidad de laboratorio. Comunidad Termux / «old phone server» ([XDA 2026](https://www.xda-developers.com/old-android-phone-linux-server-handles-more-expected/), [second-life-ecosystem.md §1.3](second-life-ecosystem.md)) asume teléfonos **de segunda vida** o con batería **reemplazable / ya amortizada**.

### 2.2 Señales de parar **de inmediato**

| Señal | Acción |
|-------|--------|
| **Carcasa trasera levantada**, marco torcido, pantalla «empujada» | **Apagar**, dejar de cargar, no usar como servidor; sustituir batería en servicio autorizado. |
| Olor a quemado, calor extremo en mano **sin** carga CPU | Igual — no continuar 24/7. |
| Carga que **sube/baja** de forma errática o reinicios en bucle enchufado | Revisar cable/cargador; si persiste, batería o PMIC — no forzar servidor. |
| **Swollen battery** visible en fotos de desmontaje (no documentado en este dispositivo) | No reutilizar como nodo enchufado permanente. |

### 2.3 Mitigaciones (ColorOS + hábito)

1. **Carga inteligente / optimizada** y, si la ROM lo ofrece, **protección de carga** o tope **80–90%** para uso enchufado largo — rutas de menú en [phone-tuning.md § Carga 24/7](phone-tuning.md).
2. Si **no** hay límite de SOC: enchufe inteligente + **`charge-limiter`** ([§ 9](#9-limitador-de-carga-y-guardián-térmico-opt-in)), o desenchufar a mano unas horas al día.
3. Evitar **modo ahorro de energía** del sistema mientras Termux sirve LLM (puede congelar procesos hijos); ver [rootless-kali.md — ColorOS stability](rootless-kali.md).
4. Monitorizar ocasionalmente con adb (opcional): `dumpsys battery` — nivel, `temperature` ( décimas °C ), estado `status=2` (charging) vs `5` (full).

**Medición puntual en este teléfono (adb, carga USB, sesión documentada en phone-tuning):** nivel **100%**, `temperature` **320** (~**32 °C** celda), sensores térmicos hasta **~44 °C** bajo **carga sostenida** de CPU — no es un test de meses de degradación.

---

## 3. Ajustes ColorOS 15 (batería, Doze, Termux)

La base **verificada por adb** está en [phone-tuning.md § A](phone-tuning.md):

- Termux en **whitelist Doze** (`dumpsys deviceidle whitelist`).
- AppOps: `RUN_ANY_IN_BACKGROUND` **allow**, `WAKE_LOCK` **allow**, `START_FOREGROUND` **allow**.
- **Phantom processes:** cap elevado + monitor desactivado (sesión 2026-10-31) — reversible; mismas órdenes en phone-tuning.
- **Opciones desarrollador:** **Desactivar restricciones de procesos hijo** (crítico para `llama-server` y proot Kali).

### 3.1 UI manual (Realme / ColorOS)

Complemento a lo anterior — revisar tras cada actualización OTA:

| Área | Qué hacer |
|------|-----------|
| **Termux** | Ajustes → Batería → Gestión por app → **autoarranque**, actividad en segundo plano, **sin optimización estricta**; no **congelar** en multitarea. |
| **Tailscale** | Igual; app en whitelist Doze (adb ya aplicado en repo). |
| **Modo ahorro** | **Desactivado** durante servidor LLM o escaneos largos. |
| **Expansión RAM 8 GB** | Aumenta **swap en flash** (~7,5 GiB visibles) — útil para multitarea Android, **malo** para KV cache LLM bajo presión; ver phone-tuning § RAM. |

Referencias OEM agresivos con apps en segundo plano: [dontkillmyapp.com/realme](https://dontkillmyapp.com/realme), guías citadas en [rootless-kali.md](rootless-kali.md).

### 3.2 Termux:Boot y fiabilidad tras reinicio

Para 24/7 **después de reboot**, instala arranque automático con **[termux-boot-services.md](termux-boot-services.md)** (`install-boot-services.sh`: **sshd** vía runit; **LLM al boot** solo con `--enable-llama-smol`). Sin eso, un reinicio deja SSH/LLM **parados** hasta abrir Termux o ejecutar bootstrap manualmente.

Tras OTA ColorOS, re-verifica exenciones de batería para **Termux** y **Termux:Boot** (F-Droid, misma firma que Termux).

---

## 4. `termux-wake-lock` — cuándo y cómo

### 4.1 Qué hace

Mantiene el dispositivo **despierto** a nivel Android (partial wake lock vía servicio Termux), reduciendo suspensión profunda que mata hijos (`llama-server`, `proot`, `nmap` largos).

**Incluido en `termux-tools`** — no requiere Termux:API para el binario básico; ver [termux-llm-guide.md](termux-llm-guide.md).

### 4.2 Uso en este repo

| Momento | Comando / comportamiento |
|---------|---------------------------|
| Arrancar LLM | `llm smol` / `llm smol --remote` → `llm-common.sh` llama **`termux-wake-lock`** si existe |
| SSH bootstrap | `ssh-setup.sh` intenta wake-lock al configurar |
| Kali / escaneos | **`termux-wake-lock`** manual antes de `kali` o jobs largos — [rootless-kali.md](rootless-kali.md) |
| Notificación Termux | Opción **Acquire wakelock** si aparece en la UI |

Liberar al parar trabajo pesado (opcional, ahorra batería si desenchufas):

```bash
termux-wake-unlock
pkill -f llama-server   # si aplica
```

### 4.3 Límites

- Wake-lock **no** evita **signal 9** por phantom procs sin los ajustes de phone-tuning.
- **No** compensa **dos** servicios pesados simultáneos — solo mantiene el proceso vivo bajo Doze moderado.
- Con pantalla apagada muchas horas, ColorOS puede seguir **reclasificando** apps; mantener Termux **bloqueado en recientes** y exenciones de batería.

---

## 5. Expectativas térmicas (SD888, 8 GB)

| Escenario | Orden de magnitud (este dispositivo / docs repo) |
|-----------|--------------------------------------------------|
| Reposo enchufado, LLM parado | Batería ~**32 °C** (medición adb) |
| LLM + inferencia, benchmarks | **~38 °C** ambiente chip — throttling **leve** posible ([phone-tuning.md § B](phone-tuning.md)) |
| Carga CPU sostenida (servidor, escaneo) | Sensores hasta **~44 °C** (misma sesión 24/7 en phone-tuning) |
| Verano / habitación >28 °C | Margen menor — **reducir** carga o apagar rol pesado |

**Recomendación:** si `llama-server` o Kali calienten de forma constante **>45 °C** en sensores o el teléfono es incómodo al tacto, **pausar** el servicio pesado; no es un fallo de Termux, es límite físico del chasis fino del GT2.

---

## 6. Cuándo **NO** usar 24/7 enchufado

| Situación | Por qué |
|-----------|---------|
| Batería **hinchada** o GT2 **único móvil diario** con batería ya débil | Riesgo seguridad / movilidad |
| Sin **carga inteligente** ni posibilidad de limitar SOC, y no quieres aceptar desgaste | Mejor nodo Raspberry/NAS para always-on |
| Quieres **Jellyfin transcode + LLM + Kali msf** a la vez | **8 GB** insuficiente; ver [phone-tuning.md § E](phone-tuning.md#e-mantener-el-rol-principal-política-operativa) |
| **Modo ahorro** o Termux **congelado** sin revisar exenciones | Caídas silenciosas del servidor |
| Entorno **sin ventilación** (armario cerrado, sol directo) | Acelera envejecimiento y riesgo térmico |
| Tras **OTA ColorOS** sin re-verificar whitelist / phantom / hijos | Regresiones típicas OEM |
| Dos cargas pesadas simultáneas | Ver [§ E phone-tuning](phone-tuning.md#e-mantener-el-rol-principal-política-operativa), no solo térmica |

Alternativa documentada si necesitas NetHunter «de verdad» o menos compromiso con la batería: [alternative-devices.md](alternative-devices.md).

---

## 7. Convivencia — «Mantener el rol principal»

Política operativa completa (prioridades, ejemplos do/don't): **[phone-tuning.md § E](phone-tuning.md#e-mantener-el-rol-principal-política-operativa)**.

Resumen alineado con [second-life-ecosystem.md §3.1](second-life-ecosystem.md):

1. **Un** servicio pesado: `llama-server` **o** transcodificación Jellyfin **o** Metasploit masivo / escaneos muy amplios.
2. En paralelo **solo ligeros:** **sshd**, **Tailscale**, **syncthing**, **mosquitto** pequeño.
3. **Kali:** con LLM **parado**; `kali --force` solo si aceptas RAM compartida — guardias en `kali-common.sh`.

Always-on **no** significa «LLM 24/7 **y** pentest 24/7 **y** media server 24/7».

---

## 8. Checklist rápido (servidor enchufado)

- [ ] Cargador/cable fiable; teléfono ventilado, sin funda gruesa en carga alta
- [ ] ColorOS: carga inteligente / límite SOC si disponible ([phone-tuning](phone-tuning.md))
- [ ] Termux + Tailscale: batería sin restricciones; Termux bloqueado en recientes
- [ ] Developer: **Desactivar restricciones de procesos hijo**; phantom cap según phone-tuning
- [ ] Doze whitelist Termux (y Tailscale) — verificado o re-aplicado tras OTA
- [ ] Un solo rol **pesado** activo — [§ E phone-tuning](phone-tuning.md#e-mantener-el-rol-principal-política-operativa)
- [ ] `termux-wake-lock` antes de jobs largos; parar LLM antes de Kali pesado
- [ ] Revisión mensual: hinchazón, calor anómalo, autonomía si usas el móvil fuera de casa
- [ ] (Opcional 24/7) Termux:Boot + `install-boot-services.sh` — [termux-boot-services.md](termux-boot-services.md)
- [ ] (Opcional) `--enable-charge-limiter` + enchufe probado en `dry-run` y luego real; `--enable-thermal-guard` — [§ 9](#9-limitador-de-carga-y-guardián-térmico-opt-in)

---

## 9. Limitador de carga y guardián térmico (opt-in)

**Estado:** implementado en el repo; **no probado en el teléfono** (lógica probada en PC con lecturas simuladas, Node-RED 4 + broker MQTT local y un enchufe Tasmota HTTP/MQTT simulado). No hay límite de carga nativo documentado para el GT2 en ColorOS 15, así que se corta la corriente desde fuera.

### 9.1 Piezas

| Pieza | Ruta | Qué hace |
|-------|------|----------|
| `charge-limiter` | [`scripts/termux/charge-limiter`](../scripts/termux/charge-limiter) + runit `services/charge-limiter` | Cada 60 s lee `termux-battery-status`, decide ON/OFF con histéresis y publica en Mosquitto (retained). Verifica que el estado real (`plugged`) coincide. |
| Flujo Node-RED | [`scripts/termux/node-red/charge-limiter-flow.json`](../scripts/termux/node-red/charge-limiter-flow.json) | Convierte `charger/want` en la orden del enchufe; confirma, publica `plug_state` y alertas; watchdog. |
| `thermal-guard` | [`scripts/termux/thermal-guard`](../scripts/termux/thermal-guard) + runit `services/thermal-guard` | Cada 30 s: si la batería ≥ 40 °C (2 lecturas) mitiga el LLM; ≤ 37 °C restaura; ≥ 45 °C lo para. |
| Config | [`power.conf.example`](../scripts/termux/power.conf.example) → `~/.config/gt2-power/power.conf` | Umbrales, MQTT, notificaciones, acción térmica. |

Requisitos: app **Termux:API** (F-Droid, misma firma que Termux) + `pkg install termux-api jq mosquitto`; Mosquitto + Node-RED de `install-optional-services.sh`. Con el limitador habilitado, **`mode idle` mantiene Mosquitto + Node-RED** (son ligeros) porque sin ellos el enchufe no recibe órdenes.

### 9.2 Lógica de carga (defaults)

| Condición | Enchufe | `reason` |
|-----------|---------|----------|
| batería ≤ 20 % | **ON** siempre | `emergency-low` |
| temp ≥ 42 °C (hasta ≤ 38 °C) | OFF | `temp-high` / `temp-ok` |
| batería ≥ 80 % | OFF | `limit` |
| batería ≤ 45 % | ON | `resume` |
| entre 45 y 80 % | mantiene | `hysteresis` |
| `charge-limiter force on/off` | forzado | `manual` |
| limitador parado (sv down / reboot) | **ON** (`CHARGE_FAILSAFE`) | `limiter-stopped` |

### 9.3 Topics MQTT (prefijo `gt2/power`, todos retained)

| Topic | Quién | Contenido |
|-------|-------|-----------|
| `battery` | móvil | JSON `{percentage, temperature, plugged, status, health, current, ts, source}` |
| `battery/percentage` · `battery/temperature` · `battery/plugged` | móvil | valores sueltos |
| `charger/want` · `charger/reason` | móvil | `ON`/`OFF` + motivo (se publica al cambiar y cada 10 min) |
| `charger/state` | móvil | JSON `{want, reason, mismatch_s, mqtt_ok, ts}` |
| `limiter/status` · `limiter/heartbeat` | móvil | `online`/`offline` · epoch cada 60 s |
| `thermal/state` | móvil | JSON del guardián térmico |
| `charger/plug_state` | Node-RED | `ON` · `OFF` · `ERROR` · `UNCONFIRMED` · `DRYRUN-…` |
| `charger/alert` | Node-RED | JSON `{ts, msg, source}` → el móvil lo convierte en notificación |

### 9.4 Seguridad (nunca estado ambiguo)

- **Verificación extremo a extremo:** si `want=OFF` y el móvil sigue cargando (o `ON` sin corriente) durante 5 min → notificación + reenvío de la orden.
- **MQTT caído:** `termux-notification` «Mosquitto inaccesible — el enchufe NO recibe órdenes» (cada 30 min mientras dure).
- **Node-RED:** errores HTTP/MQTT del enchufe → `plug_state=ERROR` + alerta; sin confirmación en 30 s → `UNCONFIRMED` + alerta; **sin latido 15 min → enchufe ON** (fail-safe) + alerta.
- **Valores raros** en `want` → Node-RED los trata como ON. Parar el limitador publica ON.
- `PLUG_TYPE=dry-run` por defecto: importar el flujo no conmuta nada; el móvil avisará de discrepancia a los 5 min (esperado).

### 9.5 Enchufe (marca desconocida → intercambiable)

En Node-RED, pestaña **GT2 limitador de carga** → propiedades → *Environment*: `PLUG_TYPE` = `dry-run` | `tasmota-mqtt` | `tasmota-http` | `shelly-gen2-http` | `shelly-gen1-http` | `shelly-gen2-mqtt`, `PLUG_HOST` (IP para HTTP) y `PLUG_MQTT_TOPIC` (topic Tasmota o id Shelly). Para otra marca basta editar el `switch` del nodo *Adaptador enchufe* (una URL o un topic). Si el enchufe usa MQTT, debe apuntar al Mosquitto del móvil: el `mosquitto.conf` del repo escucha **solo en 127.0.0.1** → añade un `listener 1883 <IP-LAN>` con usuario/contraseña (y `POWER_MQTT_USER/PASS`) o usa la variante HTTP (más simple).

### 9.6 Guardián térmico

| `THERMAL_ACTION` | Efecto | Restaurar |
|------------------|--------|-----------|
| `throttle` (defecto) | Escribe `~/.cache/llm/threads-override` = 2 y relanza el LLM (servicio `llama-smol` o `mode llm`) | Borra el override y relanza |
| `pause` | `SIGSTOP` a `llama-server` (RAM y modelo intactos; peticiones esperan) | `SIGCONT` |
| `stop` | Para el LLM | `mode llm` si el modo sigue en `llm` (`THERMAL_AUTO_RESTART=1`) |

`throttle` pasa a `pause` si el modelo ya usa ≤ 2 hilos (SmolLM3) o si el LLM se lanzó a mano (`llm …` en primer plano). ≥ 45 °C siempre `stop`. Con estado `hot`/`critical`, `mode llm` se niega (salvo `MODE_IGNORE_THERMAL=1`); `mode idle` reanuda antes de matar (SIGCONT). Al parar el guardián se reanuda el LLM y se borra el override. Notificación: `termux-notification` + hook opcional `~/.config/gt2-power/notify-hook` (ntfy u otro; el repo no trae ntfy configurado).

### 9.7 Activar y probar

```bash
# 0) Termux:API (F-Droid) instalada y abierta una vez; Mosquitto + Node-RED instalados
bash ~/storage/shared/Download/llm-setup/install-optional-services.sh --no-jellyfin --no-udocker   # si faltan
bash ~/storage/shared/Download/llm-setup/install-boot-services.sh --enable-charge-limiter --enable-thermal-guard
termux-battery-status                 # debe devolver JSON
charge-limiter once                   # lectura + decisión + publicación
charge-limiter status                 # topics retenidos gt2/power/#
thermal-guard once && thermal-guard status
# Node-RED (http://127.0.0.1:1880, o túnel SSH -L 1880:127.0.0.1:1880): Menú → Import →
#   ~/storage/shared/Download/llm-setup/node-red/charge-limiter-flow.json → Deploy (dry-run)
charge-limiter force off; sleep 5; charge-limiter status   # plug_state DRYRUN-OFF
charge-limiter force auto
# Enchufe real: PLUG_TYPE/PLUG_HOST en la pestaña → Deploy → force off → ¿deja de cargar?
mode status                           # batería, térmica y servicios runit
```

Prueba térmica sin calentar el móvil: `THERMAL_HIGH_C=30 THERMAL_RESUME_C=29 thermal-guard once` (dos veces) con `mode llm` y un modelo cargado; luego `thermal-guard reset`. Logs: `~/storage/shared/power-guard.log` y `sv`/`svlogd` de cada servicio.

---

## Referencias cruzadas

- [phone-tuning.md](phone-tuning.md) — Doze, phantom, latencia, carga 24/7, rol principal  
- [second-life-ecosystem.md](second-life-ecosystem.md) — matriz viabilidad, comunidad Termux servidor  
- [rootless-kali.md](rootless-kali.md) — wake-lock en escaneos, Kali + LLM  
- [termux-llm-guide.md](termux-llm-guide.md) — servidor remoto, API key, Tailscale  
- [termux-boot-services.md](termux-boot-services.md) — sshd (y LLM opt-in) tras reboot  
- [service-modes-design.md](service-modes-design.md) — perfiles RAM (borrador)  
- [STATUS.md](STATUS.md) — qué está operativo hoy  
