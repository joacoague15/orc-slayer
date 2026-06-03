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
3.2 Ataque (Click izquierdo)
Forma: Arco curvo frente al jugador
Mata todo lo que toca de un golpe
3.3 Dash
Input: Shift
Dirección: Última dirección de movimiento.
I-frames: Invulnerable durante TODO el dash
Atraviesa TODO: Enemigos, proyectiles, zonas de daño
Cooldown: empieza cuando termina el dash)
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
Velocidad de acecho: 195 px/s.
Velocidad de ataque: 806 px/s.
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
Pregunta al jugador: "¿Podés leer mis fases y atacar solo en las ventanas correctas?"
Conducta:
Tamaño: muy grande
Velocidad: normal
Salud: 1 (muere de un golpe, como todo)
Fases cíclicas (8 segundos totales):
Table
Fase	Duración	Color	Vulnerable	Comportamiento
APPROACH	2.0s	Naranja	✅ SÍ	Se mueve hacia el jugador. Arma brilla naranja.
SPIN ATTACK	1.5s	Rojo	❌ NO	Se detiene. Gira arma 360° (radio 150px). Aura roja.
RECOVER	1.0s	Verde	✅ SÍ	Aturdido. Respira pesado. Velocidad reducida.
LEAP	1.5s	Rojo	❌ NO	Salta a posición del jugador. Sombra en el suelo 0.5s antes. Shockwave al caer (radio 100px).
TAUNT	2.0s	Púrpura	✅ SÍ (riesgoso)	Gruñe. Invoca 2 Grunts en los bordes.
Ciclo: APPROACH → SPIN → RECOVER → LEAP → TAUNT → (repetir)
Counterplay:
APPROACH: Atacar si podés alcanzarlo. Pero no arriesgues quedarte cerca cuando termine (viene SPIN).
SPIN: Alejarse o dash perpendicular. El spin tiene radio fijo (150px). Si estás a 160px, estás seguro.
RECOVER: MEJOR VENTANA. 1.0s para acercarte y atacar. Es la fase más segura.
LEAP: Cuando aparece la sombra, dash perpendicular a la sombra. No dashés hacia la sombra.
TAUNT: Podés atacar al jefe, pero los 2 Grunts nuevos complican el espacio. Priorizar limpiar grunts primero.

Rol en juego: Test final de todo lo aprendido. Combina elementos de todos los enemigos:
Approach = Grunt (persecución directa)
Spin = Berserker (zona de daño a evitar)
Leap = Arquero (proyectil área que hay que esquivar agresivamente)
Taunt = Mago (múltiples amenazas simultáneas)

5. SISTEMA DE OLEADAS Y SPAWN
5.1 Estructura general
El juego usa un sistema cerrado de 7 waves.
Las waves 1 a 6 son pre-boss.
La wave 7 es la wave del Warlord.
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
scout = orc_scout_scene (variante legacy válida)
brute = orc_brute_scene (variante legacy válida)
archer = orc_archer_scene
mage = orc_mage_scene
berserker = orc_berserker_scene

| Wave | Kills para avanzar | Max enemigos vivos | Spawn interval | Grunt | Scout | Brute | Archer | Mage | Berserker | Objetivo de diseño |
| - | -: | -: | -: | -: | -: | -: | -: | -: | -: | - |
| 1 | 24 | 16 | 1.20s | 1.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | Enseñar persecución básica y combo con orc y archer. |
| 2 | 50 | 32 | 1.05s | 0.70 | 0.20 | 0.00 | 0.10 | 0.00 | 0.00 | Introducir presión lateral leve con Archer. |
| 3 | 70 | 24 | 0.90s | 0.52 | 0.16 | 0.00 | 0.20 | 0.12 | 0.00 | Introducir Mage y movimiento constante. |
| 4 | 100 | 34 | 0.78s | 0.42 | 0.12 | 0.08 | 0.22 | 0.12 | 0.04 | Introducir Berserker sin saturar. |
| 5 | 100 | 48 | 0.66s | 0.32 | 0.10 | 0.10 | 0.24 | 0.16 | 0.08 | Mezclar amenazas de distancia y cazador. |
| 6 | 160 | 64 | 0.54s | 0.24 | 0.08 | 0.12 | 0.25 | 0.18 | 0.13 | Test pre-boss: presión alta sin jefe. |
| 7 | Boss | Boss + summons | Boss sequence | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | Limpiar arena y ejecutar transición al Warlord o BOSS PENDING. |

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
Grunt 0.42 = 42%
Scout 0.12 = 12%
Brute 0.08 = 8%
Archer 0.22 = 22%
Mage 0.12 = 12%
Berserker 0.04 = 4%

Ejemplo con TEST SPAWNS:
Si en Wave 4 Berserker está x3.0, su peso efectivo pasa de 0.04 a 0.12.
La suma total pasa a 1.08.
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
✅ El boss tiene 1 fase con 5 sub-fases cíclicas (no múltiples fases de vida)
✅ La música es por tiempo

10. PREGUNTAS FRECUENTES YA RESPONDIDAS
P: ¿El dash puede usarse para atacar?
R: No, el dash no tiene hitbox. Es puramente movimiento + invulnerabilidad. El ataque es solo con click/espacio.
P: ¿Qué pasa si el jugador dasha contra un proyectil?
R: El proyectil lo atraviesa sin daño (i-frames). Pero el dash no destruye el proyectil.
P: ¿Los enemigos se dañan entre ellos?
R: No. El arco de ataque del jugador solo daña enemigos. Las flechas del arquero solo dañan al jugador.
P: ¿El boss puede morir durante cualquier fase?
R: Sí, pero solo si es vulnerable (fases naranja/verde/púrpura). Durante fases rojas, el hitbox del jugador no le hace daño.
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
R: No. El boss limpia todos los orcos existentes y pausa el spawn. Solo el boss + los 2 grunts que invoca en fase TAUNT.
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
[ ] Game over mejorado (stats, tips, slow-mo)
[ ] HUD mejorado (dash indicator, boss phase)
[ ] Sistema de audio
[ ] Música de boss
[ ] Efectos de pantalla (screen shake, hit stop, chromatic)

cosas a pulir:
[] Mas animaciones en las muertes de los orcos
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
[] Personaje con sprites pulidos

CUANDO SE GANA
Sistema de oleadas 
Boss final
