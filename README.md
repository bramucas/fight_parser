# Fight Parser

## Contexto

Fighter parser es un analizador léxico sintáctico diseñado para aceptar la gramática de combos de un luchador del videojuego "Tekken 7". Las "frases" de la gramática no son expresables directamente en texto así que ha sido necesario implementar un programa que reconozca los eventos generados por un controlador (para videojuegos) y codificarlos a texto; por lo que la entrada para el analizador ha sido directamente diseñada para la práctica.

El programa que se ocupa de la codificación es los eventos es "js". Js lee directamente de los eventos que genera el controlador y genera una "traducción" a texto. No se traducen la totalidad de los eventos generados sino solamente los necesarios para implementar los movimientos que se usan en el juego (por ejemplo: el mando cuenta con varios joysticks pero solo es necesario uno de ellos para jugar).

Por otro lado, el analizador (fighter_parser) recibe la salida de "js" y realiza un análisis léxico y sintáctico sobre la misma. Cómo salida, fighter parser comprueba qué combos se han ejecutado correctamente, en cuánto tiempo, porcentajes de aciertos, errores y récords de tiempo.

Todo este proceso puede hacerse de forma interactiva empleando una tubería:

```bash
	./js | ./fighter_parser
```

O de forma no interactiva volcando primero la salida de js contra un fichero y posteriormente usando el fichero cómo entrada del analizador:

```bash
	./js > fichero.txt
	./fighter_parser < fichero.txt
```

## Compilación y ejecución del programa

Para compilar el programa basta con hacer uso del makefile. Los comandos que existen son:

* "make compile": compila el analizador y genera el ejecutable "fighter_parser".
* "make js": genera el ejecutable "js".
* "make run": llama al programa y le pasa como entrada el fichero "jsevents.txt" que contiene la salida de js para una sesión.
* "make clean": elimina todos los ficheros y ejecutables que se generan al compilar.
* "make all"/"make": "make clean", "make js", "make compile" y "make run" (en ese orden).

Pasos a seguir para ejecutar el programa:

* Modo no interactivo:
	1. Conecta el controlador.
	2. ```./js > fichero.txt```
	3. Ejecuta algunos combos con el mando, se grabarán en fichero.
	4. ```./fighter_parser < fichero.txt```

* Modo interactivo:
	1. Conecta el controlador.
	2. ```./js | ./fighter_parser```
	3. Ejecuta combos con el mando. Cuando quieras terminar pulsa el botón 'start' el mando.


## Gramática

Los inputs que se aprovechan del mando para la gramática son:

* El joystick izquierdo.
* Los cuatro botones principales (normalmente llamados A B X e Y).

El mando genera los siguientes eventos:

* Cuando el jugador pulsa un botón.
* Cuando el jugador deja de pulsar un botón.
* Cada vez que el eje del joystick se mueve envía un par de 'coordenadas'.

Por estas restricciones los tokens de la gramática son los siguientes:

* A B X Y: 	Cuando se pulsa alguno de los botones.
* LA LB LX LY:	Cuando se deja de pulsar un botón ('leave A', 'leave B', etc...)
* UP UP_RIGHT RIGHT DOWN_RIGHT DOWN DOWN_LEFT LEFT UP_LEFT: Cuando el joystick cambia de una dirección (o ninguna) a otra.
* NA: (No Action) cuando el jugador no realiza ninguna acción durante cierto tiempo.

Con estos tokens se construyen las reglas más básicas de la gramática:

* Pulsar un botón y a continuación dejar de pulsarlo (se repite con los cuatro botones):
```bison
	a:
		A LA
	;
```
* Pulsar dos botones al mismo tiempo (para cada combinación de dos botones):
```bison	
	ab_prev:
		A B
	|	B A
	;

	ab:
		ab_prev LA LB
	|	ab_prev LB LA
	;
```
*(la distribución de estas reglas es obligada por la resolución de algunos conflictos de reducción/reducción. Esto se comentará en el apartado de problemas durante el desarrollo)*

* Indicar una dirección con el joystick. Solo se devuelve el token cuando se cambia de una dirección (o ninguna) a otra (se repite con las ocho direcciónes):
```bison
	up:
		UP
	;
```


Con estas reglas más básicas es posible construir las relgas que aceptan los combos del luchador. Y una vez hecho eso, para poder dar soporte al funcionamiento interactivo es necesario considerar lo siguiente:
```bison
	ss:
		s
	|	ss s
	;

	s:
		NA		{ *reiniciar contador tiempo* }
	|	combo	{ *añadir un acierto al combo, registrar el mejor tiempo y reiniciar el contador de tiempo* }
	| 	error	{ *registrar el error y reiniciar el contador de tiempo* }
	|	Never_used	{ *se corresponde con pares de botones que no se usan en la gramática. Se tratan como errores* }	
	|	startButton	{ *terminar la sesión e imprimir resultados* }
	;

	combo:
		combo1
	|	combo2
	.	.	.
	|	comboN
	;
```

## Diseño y funcionamiento

### Js

Por defecto, leerá los eventos de "/dev/input/js0" (dónde estarán los evento del primer mando conectado a la máquina), pero es posible indicarle otro dispositivo por línea de comandos. El programa divide la responsabilidad de la tarea en dos procesos: uno de ellos es el encargado de leer los eventos que se generan, transformarlos a texto y guardarlos en un buffer; el otro proceso vuelca cada cierto tiempo el contenido del buffer en la salida estándar. 

En caso de que el buffer esté vacío cuando el proceso lo comprueba se envía el texto "nothing" a la salida estándar. Este texto se corresponde con el token NA (No Action).

* Cuando el jugador pulsa un botón se genera el texto *"Button # presssed"* (dónde # puede ser A, B, Y o X).
* Cuando el jugador levanta un botón se genera el texto *"Button # released"* (dónde # puede ser A, B, Y o X).
* Cuando el jugador mueve el joystick se genera el texto *"Axis 0 at ( 999999, 999999)"*.

Con todos los textos anteriormente generados se envía una marca de tiempo "T999999". Van precedidos de una 'T' para que sea más fácil distinguirlos de las coordenadas del joystick con el analizador léxico.

### Fighter Parser: Analizador léxico

El reconocimiento de algunos tokens es bastante sencillo, como en el caso de pulsaciones de botones: simplemente se reconoce el token y se envía al analizador sintáctico. Lo reseñable del analizador léxico reside en cómo se reconocen las direcciones del joystick.

#### Direcciones

Se define una regla para el reconocimiento de las coordenadas del joystick; las cuáles son un número de al menos un dígito que puede ser positivo o negativo:

```bison
	Coord	-?[0-9]+
```

La acción cuando se reconoce esta regla se delega en la función 'handleAxisCoord(int coord)'. Esta función mantiene una estructura de array de dos posiciones y un índice. Cómo en la codificación de la señal de Js las coordenadas siempre van en pares, al recibir una coordenada se guarda en la primera posición del array y cuando se recibe la segunda se realiza el cálculo de la dirección del joystick, se devuelve al analizador sintáctico el token necesario (en caso de que se trate de un cambio de dirección) y se vacía el array.

Además esta función mantiene una variable copartida por el analizador léxico y el sintáctico llamada 'currentDirection' que indica en que dirección está apuntando el joystick en cada momento, aunque no se haya devuelto ningún token. De esta forma el analizador sintáctico puede comprobar su valor entre varios tokens de una regla de la gramática si fuese necesario.

#### Tiempos

Cómo con cada token codificado por Js se manda una marca de tiempo, es suficiente con mantener una variable compartida que se actualiza cada vez que se reconoce una marca de tiempo.

```bison
	Time T[0-9]+"."[0-9]+
```

### Fighter Parser: Analizador sintáctico

En base a las reglas más básicas de la gramática, comentadas en en el apartado *Gramática*, se han implementado las reglas de los combos. Existen reglas de combo que, además de ser un combo aceptable en sí mismo, también 'forman parte' o 'dan pie' a otros. Por lo que estos combos, llamémosles de 'primer nivel', se implementan como reglas independientes y son usados luego como parte de otras reglas. Un ejemplo:

```bison
	Pendulum_kick:
		down_right b b	{$$="Pendulum_kick";}

	To_down_right_combos:
		down_right x	 {$$="Body blow";}
				...						
	|	Pendulum_kick	 %prec NA NA
	|	Pendulum_kick a	 {snprintf(buff, BUFF_SIZE-1, "%s -> Shadow", $1);$$ = copyString(buff);}
	|	Pendulum_kick up {snprintf(buff, BUFF_SIZE-1, "%s -> White hole", $1);$$ = copyString(buff);}
	;
```

Cómo se puede observar en el ejemplo, las reglas de combo van arrastrando el nombre del propio combo. Algunas veces el nombre de un combo es fruto de la combinación de los nombres de los combos que contiene dentro de su propia regla.

Para medir los **tiempos de combo** se recoge una marca de tiempo cuando se ejecuta la primera acción de un combo. Esto se logra con la siguiente estrategia:

En las reglas básicas se ejecuta una función que se encarga de recoger la marca de tiempo:

```bison
	up:
		UP	{comboStartTime();}
	;
		...
	a:
		A {comboStartTime();} LA
	;
		...
	ab_prev:
		A {comboStartTime();} B
	|	B {comboStartTime();} A
	;

	ab:
		ab_prev LA LB
	|	ab_prev LB LA
	;

```

Funciona con un flag (startTimeTaken) que impide que cada vez que se pulse un botón se sobreescriba la marca de tiempo incial del combo que se está parseando. Cuando se acepta un combo, o se dispara un error se reinicia este flag para poder recoger la siguiente marca de tiempo correctamente; como se puede ver en el código:

```bison
	ss:
		s
	|	ss s
	;

	s:
		NA		{startTimeTaken = 0;}
	|	combo	{
					endTime = yylval.time;
					ComboInfo* combo = newComboInfo($1, endTime - startTime);
					startTimeTaken = 0;
					pthread_create(&thread_id, NULL, addOneSuccess, combo);
				}
	| 	error	{startTimeTaken = 0;}
	|	Never_used	{fails++; startTimeTaken=0;printf("Never used combination\n");}	
	|	startButton	{printf("\nEnd of the session. Printing results...\n");return 0;}
	;
```

En el código anterior también puede observarse cómo se lleva a cabo el conteo de aciertos de combos. Cuando el parser acepta un combo completo se crea una estructura de datos que contiene el nombre del combo y el tiempo de ejecución del mismo. Posteriormente se invoca un thread que ejecuta la función *addOneSuccess(ComboInfo *combo)* que se encarga de actualizar la información acerca de los combos exitosos. 

Dicha información se almacena en un diccionario, indexado por el nombre del combo, el cual es compartido entre procesos. Para proteger las secciones críticas en concurrencia se utiza un mutex cuando se quiere leer/modificar el diccionario.

**Ejemplo de ejecución y salida**:

```
	Let's practice! Press START button when you have finished.

	Valkyrie lance! (0.400 seconds)
	Fail! unexpected Y, expecting ReleasedX.
	Death_from_above! (0.340 seconds)
	Left_right -> Death_from_above! (0.756 seconds)
	Valkyrie lance! (0.316 seconds)
	Spining chakram! (0.580 seconds)
	Missing_talon -> Galatine! (0.480 seconds)
	Valkyrie lance! (0.324 seconds)
	Fail! unexpected X, expecting ReleasedY.
	Valkyrie lance! (0.364 seconds)
	Missing_talon -> Galatine! (0.556 seconds)
	Left_right -> Kronos_cutter! (0.924 seconds)

	End of the session. Printing results...

	-------------- Combos --------------
	*Valkyrie lance :
	 - Successes: 4
	 - Best time: 0.316 seconds!

	*Death_from_above :
	 - Successes: 1
	 - Best time: 0.340 seconds!

	*Left_right -> Death_from_above :
	 - Successes: 1
	 - Best time: 0.756 seconds!

	*Spining chakram :
	 - Successes: 1
	 - Best time: 0.580 seconds!

	*Missing_talon -> Galatine :
	 - Successes: 2
	 - Best time: 0.480 seconds!

	*Left_right -> Kronos_cutter :
	 - Successes: 1
	 - Best time: 0.924 seconds!


	-------------- Metrics --------------
	Total combos	: 10	83.33%
	Fails		: 2	16.67%

```

## Problemas que han surgido durante el desarrollo

#### Pulsación de varios botones simultáneamente

En un principio no se reconocían los eventos en los que los botones dejaban de pulsarse. Pero fue necesario cuando se quiso tener la capacidad de reconocer la pulsación de más de un botón de forma simultánea como parte de un combo. Como resultado se crearon las reglas de la forma siguiente:

```bison
	ab_prev:
		A {comboStartTime();} B
	|	B {comboStartTime();} A
	;

	ab:
		ab_prev LA LB
	|	ab_prev LB LA
	;
```

#### Conflictos desplazamiento/reducción

Cuando en una misma regla de la gramática, ocurre que para dos variaciones de la relga una de ellas es el comienzo de la otra puede surgir un conflicto *desplazamiento/reducción*. Por ejemplo, partiendo del conjunto de reglas siguientes:

```bison
	Haze:
		ab	{$$="Haze";}
	;

	Haze_combos:
		Haze	%prec NA NA
	|	Haze x	{$$="Kronos_cutter";}
	|	Haze y	{$$="Death_from_above";}
		...
	;
```

Si el analizador recibe la siguiente secuencia: "ab x". Una vez leído 'ab' y viendo que lo próximo en llegar es 'x' el analizador sintáctico no puede determinar si se debe aceptar la regla 'Haze' y la 'x' corresponde con el comienzo de otro combo o si realmente lo que se debe aceptar es la variante *Haze x* de la regla *Haze_combos*.

Existen dos posiblidades para solucionar el problema:

1. Cambiar la variante 'Haze' a 'Haze NA', y así obligar a que para aceptar dicha variante haya una pausa en la entrada.
2. Usar la rutina **%prec** de bison que obliga a que lo siguiente que se reconozca sea 'NA NA'.

Se ha elegido la segunda opción por que se considera que así se respeta más la gramática original, pues realmente el uso del token 'NA' es una imposición de la tecnología, no forma parte de las aciónes que dan forma al combo.


#### Búffer de bison

Por defecto, bison almacena pasa la entrada estándar por un búffer. Esto supuso un problema desde el principio para la implementación del modo interactivo. Causaba que no hubiese respuesta inmediata al interactuar usando el mando, hasta que se llenase el búfer con la salida acumulada de js y en ese momento se procesaba todo lo almacenado hasta el momento en el buffer.

No ha sido posible desactivar el buffer, por lo que se ha parcheado js para que, junto a cada token imprima ciert cantidad de espacios en blanco y de esa forma se llene el buffer con cada acción. Simulando así que el buffer no existe. 

Queda pendiente como trabajo futuro resolver este problema.

#### Protección de datos y concurrencia en modo interactivo

La forma de actualización del diccionario (usando threads) es resultado de solucionar el siguiente problema. En modo interactivo se puede interrumpir el programa en cualquier momento. Existía un error que sucedía cuando se interrumpía el programa mientras éste actualizada la lista enlazada que estructura el diccionario. La estructura de datos quedaba en situación inconsistente y al intentar leer los datos e imprimirlos el programa entraba en un bucle infinito recorriendo la misma posición del dicionario una y otra vez.

Al usar multiprocesamiento y proteger el diccionario con un mutex se logran dos objetivos:

1. Interrumpir el programa principal no implica interrumpir (si aún existe algúno) los threads que estén actualizando en ese momento.
2. Antes de leer del diccionario y imprimir la salida se debe esperar a que el mutex quede libre. Nos aseguramos de que todos los demás procesos han acabado.

  
- - -

[![twitter][1.1]][1]     [![github][2.2]][2]     [![linkedin][3.3]][3] *Contact*

[1]:https://twitter.com/b_munizcastro
[1.1]:https://cdn4.iconfinder.com/data/icons/iconsimple-logotypes/512/twitter-24.png

[2]:https://github.com/bramucas
[2.2]:https://cdn4.iconfinder.com/data/icons/iconsimple-logotypes/512/github-24.png

[3]:https://www.linkedin.com/in/brais-mu%C3%B1iz-castro-93279115a/
[3.3]:https://cdn4.iconfinder.com/data/icons/iconsimple-logotypes/512/linkedin-24.png

