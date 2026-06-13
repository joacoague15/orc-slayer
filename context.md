Orc Slayer es un juego top-down action de una sola vida donde matas orcos en combo infinito hasta derrotar a un jefe final. Un golpe = muerte = reinicio completo. No hay meta-progresión. Es pura expresión de habilidad.
Hook: "Un golpe. Un jefe. Una chance."

2. REGLAS NO NEGOCIABLES
Estas reglas nunca se cambian. Si una IA sugiere modificarlas, rechazar la sugerencia:

| # | Regla                                                        | Razón de diseño                                                                  |
| - | ------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| 1 | **Un golpe = muerte instantánea**                            | Core pillar. Crea tensión constante. Sin HP, sin regeneración.                   |
| 2 | **Los enemigos también mueren de un golpe**                  | Simetría. El jugador y los enemigos son igual de frágiles.                       |
| 3 | **No hay meta-progresión**                                   | Cada run es autosuficiente. El único "progreso" es tu skill.                     |
| 4 | **El juego termina al matar al jefe**                        | Loop cerrado. Victoria definida, no infinita.                                    |
| 5 | **El personaje atraviesa enemigos** (no hay colisión sólida) | Design choice. Permite dash agresivo y posicionamiento ofensivo.                 |
| 6 | **El dash tiene i-frames totales**                           | Permite jugar agresivo. Es la herramienta de escape OFENSIVA, no solo defensiva. |
| 7 | **El combo se resetea por TIEMPO**         | Como recibir daño = muerte, no tiene sentido resetear por daño.                  |
| 8 | **No hay tope de combo**                                     | Skill ceiling infinito. Leaderboard driven.                                      |

3. MECÁNICAS DEL JUGADOR
3.1 Movimiento
Input: WASD
Sin fricción: Parada instantánea cuando sueltas la tecla. Responde al 100%.
Atraviesa enemigos: No hay colisión física con orcos ni proyectiles (excepto daño).
Velocidad actual del jugador: 390 px/s.
3.2 Ataque (Click izquierdo)
Forma: Arco curvo frente al jugador
Mata todo lo que toca de un golpe
El ataque puede mantenerse apretado; no hace falta presionar click repetidamente.
Velocidad actual de animaciones de ataque: 60% del valor anterior.
3.2.1 Controles táctiles (celular / web táctil)
Se activan SOLO si el dispositivo es táctil (DisplayServer.is_touchscreen_available()); en desktop todo sigue siendo teclado + mouse, sin cambios.
Esquema twin-stick (capa CanvasLayer aparte, full-res, sobre el render low-res):
- Stick izquierdo (mitad inferior izq.): movimiento. Origen dinámico (la base aparece donde tocás).
- Stick derecho (mitad inferior der.): apuntado; al deflectarlo dispara el ataque (auto-fire estilo Archero).
- Botón DASH (esquina inferior der.): dash (dirección = última de movimiento).
Multitouch real: cada dedo se arbitra por índice en touch_controls.gd; el botón de dash tiene prioridad sobre el stick de apuntado que lo solapa.
Requiere emulate_mouse_from_touch=false para que los toques no se conviertan en clicks y disparen "attack" por accidente.

3.3 Dash
Input: Shift (o botón DASH en táctil)
Dirección: Última dirección de movimiento.
I-frames: Invulnerable durante TODO el dash
Atraviesa TODO: Enemigos, proyectiles, zonas de daño
Cooldown: empieza cuando termina el dash)
Velocidad actual del dash: 1270.75 px/s.
Duración actual del dash: 0.16s.
Distancia actual del dash: 203.32 px.
Durante el dash, absolutamente nada puede matar al jugador. Cualquier daño debe pasar por player.die(), y player.die() debe ignorarse si el jugador está dasheando o invulnerable.
Feedback visual:
3-4 copias fantasma del jugador que se desvanecen
Screen shake
Flash/brillo cuando dash está listo de nuevo
3.4 Combo y Puntuación
Combo: +1 por cada orco matado consecutivamente
Reset: Si pasan 3.5 segundos sin matar un orco, el combo vuelve a 0
Sin tope: Puede seguir subiendo infinitamente
Audio: El pitch de los SFX de kill sube con el combo (máx +4 semitonos)

4. ENEMIGOS: CONDUCTAS ESPECÍFICAS
Cada enemigo tiene una "pregunta" que le hace al jugador. El jugador debe responder con un estilo de juego diferente. Esta es la clave del diseño.

4.1 Orco Grunt (Básico)
Pregunta al jugador: "¿Querés jugar ofensivo o defensivo?"
Conducta:
Corre directo al jugador persiguiendolo
Velocidad: más lento que el jugador
No tiene ataque a distancia
Wind-up de ataque: 0.08s. Si llega al jugador, casi no hay ventana de reacción: es matarlo antes de que llegue o morir.
Escena usada: solo `orc.tscn`.
Variación runtime permitida: tamaño y velocidad levemente variables por instancia.
Las escenas legacy `orc_2.tscn`, `orc_3.tscn`, `orc_4.tscn`, `orc_brute.tscn` y `orc_scout.tscn` fueron removidas.
Muere al tocar el arco de ataque del jugador
Muere de un golpe
Counterplay:
Ofensivo: Correr hacia él y atacar primero
Defensivo: Dejar que se acerque, atacar en el último segundo
Dash: Atravesarlo por el medio con i-frames
Rol en el juego: Relleno de combo. Permite al jugador elegir su estilo. Sirve para mantener el combo vivo entre enemigos más peligrosos.

4.2 Orco Arquero
Pregunta al jugador: "¿Querés cerrar distancia rápido o morir?"
Conducta:
Velocidad: lento, se mueve poco
Ejemplo de su comportamiento de movimiento:
Si el jugador está a más de su rango → se acerca hasta estar en rango
Si el jugador está a menos de su rango maximo → dispara, no intenta acercarse mas
Ataque:
0.5s de wind-up (telegrafeo visual: línea roja apunta al jugador
Dispara flecha que viaja medianamente rapido
La flecha dura 10 segundos y luego desaparece
Cooldown entre disparos: 3 segundos
Counterplay:
AGRESIVO OBLIGATORIO: No podés mantener distancia. Tenés que correr directo a él.
Si llegás antes de que dispare, lo matás gratis.
Si dashás hacia él durante el wind-up, atravesás la flecha con i-frames y lo matás.
Rol en el juego: Fuerza al jugador a jugar agresivo. Crea tensión cuando hay múltiples arqueros en lados opuestos.

4.3 Orco Berserker
Pregunta al jugador: "¿Podés soportar la presión de un cazador que te encierra?"
Conducta:
Acecha al jugador mirándolo siempre.
Se mueve alrededor del jugador, rodeándolo, manteniendo distancia media.
Mientras acecha, intenta sostenerse entre 150 px y 240 px del jugador.
Tiempo de acecho antes de atacar: aleatorio e impredecible entre 3.0s y 10.0s.
Cuando decide atacar, se lanza contra el jugador y lo persigue sin detenerse.
Durante el ataque, no bloquea dirección: ajusta su trayectoria constantemente hacia el jugador.
Velocidad de acecho: 253.5 px/s.
Velocidad de ataque: 1047.8 px/s.
Radio de golpe durante ataque: 34 px.
Muere de un golpe como todo enemigo.
Counterplay:
No dejar que te cierre el espacio mientras te rodea.
Leer el cambio a rojo: cuando entra en ataque, ya no va a parar.
Dash: usar i-frames para cruzarlo o reposicionarse cuando se lanza.
Ofensivo: matarlo durante el acecho o durante su persecución si lográs entrar en rango sin tocarlo.
Rol en el juego: Crea presión psicológica y control de espacio. No pide esperar una ventana fija: obliga a reaccionar a un cazador impredecible que pasa de acechar a perseguir de forma brutal.

4.4 Orco Mago
Pregunta al jugador: "¿Podés mantenerte en movimiento constante y leer los ángulos?"
Conducta:
Velocidad: muy lento, casi estático
Rango óptimo: media distancia del jugador
Comportamiento de movimiento: Similar al arquero (mantiene rango)
Ataque (Ráfaga de 3 proyectiles):
0.8s de telegrafeo (brillo púrpura en el bastón)
Proyectil 1: Disparo recto al jugador
Proyectil 2: Disparo 15° a la izquierda del jugador
Proyectil 3: Disparo 15° a la derecha del jugador
Intervalo entre proyectiles: 0.3 segundos
Cooldown total: 3.0 segundos
Proyectil (Arcane Bolt):
Recorre 200 px en línea recta
Luego se divide en 2 proyectiles a 45° del original
Los proyectiles divididos recorren mas distancia
Total: 3 proyectiles que se convierten en 6, cubriendo un abanico amplio
Dejan residuo púrpura en el suelo (0.5s, decorativo)
Counterplay:
POSICIONAL OBLIGATORIO: Nunca quedarse quieto. Si te quedás quieto, el abanico te atrapa.
Movimiento perpendicular: Después de que dispara, moverse perpendicular a la dirección del mago. Los proyectiles divididos viajan en ángulo, no en curva.
Dash: Dash a través de los huecos entre los proyectiles divididos. Requiere timing preciso.
Agresivo alternativo: Si estás muy cerca, sus proyectiles no tienen tiempo de dividirse. Pero es arriesgado.
Rol en el juego: Fuerza movimiento constante. A diferencia del arquero (que pide agresividad) o el berserker (que pide paciencia), el mago pide fluidez. No podés plantarte ni en un lugar ni en un estilo.


4.5 Orco Warlord (Jefe Final)
Pregunta al jugador: "¿Podés esquivar dentro de mi área de ataque y aguantar hasta que me agote?"
Conducta:
Tamaño: muy grande
Aspecto: ESPECTRAL, un espíritu orco: tinte etéreo verde-cian con rim glow y ondulación (shader), motas de alma flotando, ecos/afterimages al moverse y bruma espectral en cada pisada.
Marcha sincronizada: la animación de pasos avanza por DISTANCIA recorrida (no por tiempo) → no patina al desplazarse.
Velocidad de persecución: 326.4 px/s (+70% sobre el prototipo de 192; más lento que el jugador, pero presiona)
Salud: 1 (muere de un golpe, como todo), pero SOLO mientras está estuneado.
Invulnerable por defecto: bloquea cualquier golpe con el escudo (chispas + knockback al jugador).
Puntería en dos capas: la cabeza gira rápido con límite; el cuerpo rota lento → punto ciego a la espalda.

Dos ataques + agotamiento:
1. CLEAVE (arco frontal):
Alcance: 230 px (-40%). Se gatilla a 202 px del jugador.
Ataque rápido: wind-up 0.38s (telegraph: abanico rojo con borde pulsante + RELLENO de carga lineal que llega al borde justo cuando cae el golpe + tinte rojo), swing 0.15s, recover 0.35s.
La dirección se compromete al iniciar el wind-up: leer el abanico y salir del cono, o atravesarlo con dash (i-frames).
2. PISOTÓN:
Frecuente: cada 3-5.5 segundos.
Telegraph de 0.5s: el boss se alza + círculo rojo de advertencia con anillo CONTRACTOR que se cierra hacia el centro (cuando llega, cae el pisotón).
Impacto: flash central, dos ondas de polvo no letales, escombros radiales, polvareda y shake fuerte antes del muro letal.
Libera UNA onda expansiva LETAL que avanza a 430 px/s (expansión lineal) hasta cubrir TODA la ronda.
Visual de peligro inconfundible: frente grueso ROJO (mismo lenguaje que los telegraphs) con núcleo blanco, grosor pulsante y brasas crepitando a lo largo de todo el anillo.
Es más rápida que el jugador corriendo (390 px/s): no se le puede huir, hay que atravesarla con dash (i-frames).
AGOTAMIENTO (stun):
Después de 5-10 ataques (aleatorio; cuentan cleaves y pisotones), el boss queda ESTUNEADO 1.5 segundos al terminar su último ataque.
Feedback: flash blanco + onda dorada + tinte dorado pulsante + maza caída + disco-timer dorado que se achica con la ventana.
Es el ÚNICO momento en que el jugador puede matarlo (de un golpe).
Si la ventana se cierra sin matarlo, el contador arranca de nuevo (5-10 ataques).
Counterplay:
CLEAVE: leer el abanico rojo y reaccionar rápido (0.38s): salir del cono por el costado o atravesarlo con dash. Quedarse parado dentro del área = muerte.
PISOTÓN: no correr hacia el borde (la onda es más rápida que vos y cubre toda la ronda): dashear a través del frente con i-frames.
STUN: contar los ataques para anticipar la ventana. Cuando colapsa, correr hacia él y atacar antes de que el disco-timer se cierre.

Rol en juego: Test final de todo lo aprendido. Combina elementos de todos los enemigos:
Cleave = Grunt + Berserker (amenaza melee brutal que pide lectura y sangre fría)
Pisotón = Mago (zonas de peligro que fuerzan movimiento y timing de dash)
Agotamiento = Arquero (agresividad obligatoria: si no cerrás distancia a tiempo, perdés la chance)

5. SISTEMA DE OLEADAS Y SPAWN
5.1 Estructura general
El juego usa un sistema cerrado de 7 waves.
Las waves 1 a 6 son pre-boss.
La wave 7 es la wave del Warlord.
En la build actual, la run se detiene al completar la wave 6 y muestra "BOSS NO HECHO".
Mientras el Warlord no esté implementado o conectado, la wave 7 entra en estado BOSS PENDING.
Boss pending no es victoria ni game over: detiene el spawner, deja la run viva y muestra un mensaje claro de placeholder.
Cada wave debe ser más complicada que la anterior por una combinación de:
Más enemigos requeridos para avanzar.
Mayor cantidad máxima de enemigos vivos.
Menor intervalo de spawn.
Mayor presencia de enemigos que fuerzan respuestas específicas: Archer, Berserker y Mage.

Las waves avanzan por kills de enemigos, no por tiempo.
El spawner se pausa al completar una wave.
Entre waves hay una pausa corta para respirar y comunicar el avance.
Puntos de spawn: de cualquier lado de la pantalla.
Spawn aleatorio: cualquier dirección, cualquier tipo habilitado según pesos de la wave.
Los pesos son relativos. No tienen que sumar 1.0; el spawner normaliza internamente.
El panel TEST SPAWNS multiplica estos pesos runtime, pero no reemplaza la tabla base de waves.

5.2 Tabla de waves
Enemy keys:
grunt = orc_normal_scene
archer = orc_archer_scene
mage = orc_mage_scene
berserker = orc_berserker_scene

| Wave | Kills para avanzar | Max enemigos vivos | Spawn interval | Grunt | Archer | Mage | Berserker | Objetivo de diseño |
| - | -: | -: | -: | -: | -: | -: | -: | - |
| 1 | 6 | 6 | 1.20s | 0.50 | 0.50 | 0.00 | 0.00 | Enseñar persecución básica y combo con orc y archer. |
| 2 | 30 | 16 | 1.05s | 0.40 | 0.60 | 0.00 | 0.00 | Introducir presión lateral leve con Archer. |
| 3 | 30 | 16 | 0.90s | 0.50 | 0.30 | 0.20 | 0.00 | Introducir Mage y movimiento constante. |
| 4 | 100 | 34 | 0.78s | 0.40 | 0.20 | 0.20 | 0.20 | Introducir Berserker sin saturar. |
| 5 | 100 | 48 | 0.66s | 0.10 | 0.30 | 0.30 | 0.30 | Mezclar amenazas de distancia y cazador. |
| 6 | 160 | 64 | 0.54s | 0.05 | 0.30 | 0.45 | 0.20 | Test pre-boss: presión alta sin jefe. |
| 7 | Boss | Boss + summons | Boss sequence | 0.00 | 0.00 | 0.00 | 0.00 | Limpiar arena y ejecutar transición al Warlord o BOSS PENDING. |

`kills_required` define tambien el total maximo de enemigos que el spawner puede crear en esa wave. `max_orcs` solo limita cuantos enemigos pueden estar vivos al mismo tiempo.

5.3 Distribución de weights
Los valores de la tabla son pesos base por wave.
Para cada spawn, el spawner calcula un peso efectivo por enemigo:
peso_efectivo = peso_base_de_wave * multiplicador_TEST_SPAWNS
Si el toggle TEST SPAWNS de un enemigo está OFF, su peso efectivo es 0.0.
Si el multiplicador TEST SPAWNS está en x0.0, su peso efectivo es 0.0.
Los enemigos con peso efectivo 0.0 no pueden spawnear.

La probabilidad real de cada enemigo se calcula normalizando los pesos efectivos:
probabilidad_enemigo = peso_efectivo_enemigo / suma_de_todos_los_pesos_efectivos_de_la_wave

Ejemplo sin modificadores:
Wave 4 suma 1.00 total:
Grunt 0.62 = 62%
Archer 0.22 = 22%
Mage 0.12 = 12%
Berserker 0.04 = 4%

Ejemplo con TEST SPAWNS:
Si en Wave 4 Berserker está x3.0, su peso efectivo pasa de 0.04 a 0.12.
La suma total pasa a 1.08 porque Grunt 0.62 + Archer 0.22 + Mage 0.12 + Berserker 0.12.
La probabilidad real de Berserker pasa a 0.12 / 1.08 = 11.1%.
El resto de enemigos baja proporcionalmente porque la normalización se recalcula.

Si todos los pesos efectivos quedan en 0.0, el spawner no instancia enemigos hasta que al menos un enemigo vuelva a estar habilitado con peso mayor a 0.0.

5.4 Transición entre waves
Al completar los kills requeridos de una wave:
El spawner deja de crear enemigos.
Los enemigos vivos restantes permanecen en pantalla, salvo en la transición al boss.
Cuando ya no quedan enemigos vivos, comienza la pausa entre waves.
Pausa entre waves: 2.0 segundos.
Se muestra marcador de oleada al comienzo de cada wave.
El combo no se resetea por cambio de wave; solo se resetea por su timer normal de 3.5 segundos.

5.5 Panel TEST SPAWNS
Ubicación: Main menu
Uso: herramienta de test runtime para ajustar la composición del spawner antes de iniciar una run.
Control por enemigo:
Toggle ON/OFF.
Slider de multiplicador de peso entre x0.0 y x3.0.
La configuración se guarda en GameState durante runtime. No se persiste en disco y no es meta-progresión.

5.6 Trigger del Jefe
Condición: completar la wave 6 y limpiar los enemigos restantes.
Estado actual de build: al completar la wave 6 se detiene el spawner y se muestra "BOSS NO HECHO"; no se inicia wave 7.
Secuencia:
Se completa la wave 6.
El spawner se detiene.
Los enemigos restantes se limpian antes de la entrada del boss.
3 segundos de pausa (audio de alerta, pantalla tiembla leve)
Aparece el Warlord en el punto de spawn más lejano del jugador
Música de boss comienza
Si el Warlord no está disponible:
No se instancia ningún jefe.
El spawner queda detenido.
Se muestra "BOSS PENDING" en pantalla.
La run no se marca como victoria.

5.7 Victoria
Al matar al Warlord: pantalla de victoria 
Muestra: Score final, combo máximo, tiempo, orcos matados

6. UI/UX: QUÉ MOSTRAR Y QUÉ NO
6.0 Legibilidad visual
Orden visual obligatorio:
Sangre en suelo: z_index -2.
Corpses/enemigos muertos: z_index -1.
Grunts vivos: z_index 2.
Enemigos especiales vivos: z_index 4.
Boss: z_index 5.
Player: z_index 10.
El jugador nunca debe quedar tapado por corpses ni enemigos muertos.
Los enemigos vivos nunca deben quedar debajo de corpses.

6.1 Durante Gameplay (HUD)
Elementos obligatorios:
Score (arriba-izquierda, tamanio normal)
Combo (arriba-centro): ×24 con barra circular de decaimiento. Color según nivel:
×1-9: Blanco
×10-24: Amarillo
×25-49: Naranja
×50-99: Rojo
×100+: Púrpura
Timer (arriba-izquierda): 02:34 tiempo de run
Dash Indicator (sobre el personaje): el personaje destella. Destello es que esta listo de nuevo.
Marcador de Oleada al principio de cada comienzo de oleada
Solo durante boss:


7. AUDIO: DIRECCIÓN CREATIVA
7.1 Música Actual
Estado: Un solo loop corto para gameplay. Funciona pero es repetitivo.
7.2 Música Objetivo v2.0
Gameplay (oleadas):
Crossfade suave entre capas (0.5s)
La intensidad depende del tiempo, no del combo. Esto premia al jugador que va progresando.
Boss:
Pista dedicada de 2-3 minutos en loop
Stinger (efecto corto) al cambiar de fase
Silencio dramático 0.5s antes de empezar
Game Over:
Versión distorsionada y lenta de la música de gameplay
Heartbeat que se desvanece
Silencio antes de mostrar menú
Victoria:
Fanfarria de 10 segundos (no loop, one-shot)
Fade out a ambient

Si una IA sugiere cambiar alguna de estas, la respuesta es "No, ya está decidido":
✅ El dash tiene i-frames totales y atraviesa todo
✅ No hay barra de vida (ni jugador ni enemigos)
✅ El juego termina al matar al jefe (no es infinito)
✅ No hay meta-progresión (no desbloqueás nada permanente)
✅ Los enemigos son 4 + jefe (no más tipos en v2.0)
✅ El mago usa proyectiles con split angular (no teleport, no escudo)
✅ El berserker acecha rodeando al jugador y luego persigue sin detenerse, ajustando trayectoria constantemente
✅ El arquero usa flechas con tracking leve (no insta-hit, no spread shot)
✅ El boss tiene 2 ataques (cleave, pisotón) y una ÚNICA ventana vulnerable: queda estuneado 1.5s tras encadenar 5-10 ataques (no múltiples fases de vida)
✅ La música es por tiempo

10. PREGUNTAS FRECUENTES YA RESPONDIDAS
P: ¿El dash puede usarse para atacar?
R: No, el dash no tiene hitbox. Es puramente movimiento + invulnerabilidad. El ataque es solo con click/espacio.
P: ¿Qué pasa si el jugador dasha contra un proyectil?
R: El proyectil lo atraviesa sin daño (i-frames). Pero el dash no destruye el proyectil.
P: ¿Los enemigos se dañan entre ellos?
R: No. El arco de ataque del jugador solo daña enemigos. Las flechas del arquero solo dañan al jugador.
P: ¿El boss puede morir durante cualquier fase?
R: No. Solo mientras está estuneado: 1.5s después de encadenar 5-10 ataques (cleaves + pisotones). El resto del tiempo bloquea cualquier golpe con el escudo (chispas + knockback).
P: ¿El combo afecta el daño?
R: No. Todos mueren de un golpe siempre. El combo solo afecta puntuación.
P: ¿Hay power-ups en el suelo?
R: Solamente unas monedas que aumentan el combo y la puntuacion.
P: ¿El juego tiene dificultades?
R: No.
P: ¿Se puede pausar?
R: Sí, Escape/P pausa el juego. Menú de pausa con opciones: Reanudar, Opciones, Abandonar.
P: ¿Qué pasa si mato al jefe con combo alto?
R: El combo se mantiene hasta la pantalla de victoria. El score final incluye el multiplicador.
P: ¿Los orcos spawnean durante el boss?
R: No. El boss limpia todos los orcos existentes y pausa el spawn. Solo el boss (no invoca enemigos).
P: ¿Puedo atacar durante el dash?
R: No. Durante el dash el estado es "DASHING". No se puede atacar ni cambiar dirección.
P: ¿El berserker puede cargar fuera de pantalla?
R: No. El jugador debe ver al berserker que esta cargando
P: ¿El mago puede disparar si el jugador está muy cerca (menos de 50px)?
R: Sí, pero los proyectiles no alcanzan a dividirse. Son solo 3 proyectiles rectos fáciles de esquivar.


11. COSAS HECHAS vs. POR HACER
✅ Hecho (v1.0)
[x] Grunt básico con persecución
[x] Sistema de ataque de personaje jugable con arco curvo
[x] Sistema de combo y puntuación
[x] Menú principal (sólido, no requiere cambios)
[x] Música de gameplay en loop (funcional)
[x] Game over básico (funcional pero flojo)
[x] Fondo generado con IA
[x] Sprites del jugador y grunt (IA, iterados)
[x] Efectos de pantalla (screen shake, hit stop, chromatic)
[x] Leaderboard local
🚧 En progreso / Pendiente (v2.0)
[x] Dash con i-frames
[x] Orco Arquero + flechas con tracking
[x] Orco Berserker + patrón de carga
[x] Orco Mago + proyectiles con split
[x] Orco Warlord (jefe) + 5 fases
[ ] Pantalla de victoria + créditos
[x] Game over mejorado (stats, tips, slow-mo)
[x] HUD mejorado (dash indicator, boss phase)
[x] Sistema de audio
[ ] Música de boss
[x] Efectos de pantalla (post-processing, shaders)

cosas a pulir:
[] Pulir arquero
[] Pulir mago
[] Pulir berserker
[] Pulir jefe

[x] Disenio arquero
[x] Disenio mago
[x] Disenio berserker
[] Disenio jefe

[x] Animaciones arquero
[x] Animaciones mago
[x] Animaciones berserker
[] Animaciones jefe

[] Terreno mejorado
[x] Personaje con sprites pulidos

CUANDO SE GANA
Sistema de oleadas 
Boss final

FRASES DE GAME OVER
Orc: "No one will mourn you here."
Knight: "I didn't come to be mourned."

Troll: "This is where your story ends."
Knight: "You don't get to write it."

Orc: "Kneel, and it will be quick."
Knight: "I kneel to no beast."

Orc: "Your bones will make fine tools."
Knight: "Come and take them."

Troll: "Your armor will rust on your corpse."
Knight: "Not today."

Orc: "The ground is hungry for you."
Knight: "Let it stay hungry."
