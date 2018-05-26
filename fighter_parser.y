%{
#include <stdlib.h>
#include <signal.h>
#include <stdio.h>
#include <pthread.h>
#include <sys/time.h>
#include <assert.h>
#include "fighter_parser.h"

#define BUFF_SIZE 2000

typedef struct {
    char *comboName;
    double time;
} ComboInfo;

unsigned int yyline;
int yylex();
char* yytext;
int yyparse();

char buff[BUFF_SIZE];

/* Parser variables */
int currentDirection;			// Shows, at any time, which direction the axis is aiming at. 
Dictionary *hits = NULL;		// Pair name-value -> combo-successes.
pthread_mutex_t dict_mutex;		// This mutex is used to avoid concurrence problems between threads.
int fails;						// Errors counter.

long unsigned int thread_id;	// Used just to create threads.

/* Time variables */
double startTime, endTime;
int startTimeTaken;

/* YYerror handler */
void yyerror (char const *message) 
{
	char* failInfo;

	failInfo = strReplace("syntax error, ", "", message);
	failInfo = replaceTokenNames(failInfo);
	
	fprintf (stderr, "Fail! %s.\n", failInfo);
	fails++;
}

/* Calculate and print the results of the practice session */
void intHandler(int dummy) {
    Dictionary *index;
    int totalSuccesses = 0;

    printf("\n-------------- Combos --------------\n");
	pthread_mutex_lock(&dict_mutex);
	index = hits;
	if (index->head != NULL){
		while (index != NULL){
	    	printf("*%s :\n - Successes: %d\n - Best time: %2.3lf seconds!\n\n", index->head->key, index->head->value, index->head->bestTime);
	    	totalSuccesses+=index->head->value;
	    	index = index->tail;
		}
	} else {
		printf("Nothing...\n");
	}
	pthread_mutex_unlock(&dict_mutex);

    printf("\n-------------- Metrics --------------\n");
    printf("Total combos\t: %d\t%2.2f%%\n", totalSuccesses,
    	totalSuccesses != 0 || fails != 0 ? (float) totalSuccesses * 100 /(float) (totalSuccesses+fails) : 0.0f);
    
    printf("Fails\t\t: %d\t%2.2f%%\n", fails,
    	totalSuccesses != 0 || fails != 0 ? (float) fails * 100 /(float) (totalSuccesses+fails) : 0.0f);

    exit(0);
}


ComboInfo *newComboInfo(char* comboName, double timestamp){
	ComboInfo *comboInfo = (ComboInfo*)malloc(sizeof(ComboInfo));
    assert(comboInfo != NULL);
    comboInfo->comboName = comboName;
   	comboInfo->time = timestamp;
    return comboInfo;
}

/* Plus one to the successes of a combo 
	- char* key: name of the combo and key of it value in the 'hits' dictionary */
void * addOneSuccess(void *ptr){
	int times;
	ComboInfo *comboInfo = ptr;

	pthread_mutex_lock(&dict_mutex);
	times = dict_get(hits,comboInfo->comboName);
	times++; 
	dict_add(hits, comboInfo->comboName, times, comboInfo->time);
	pthread_mutex_unlock(&dict_mutex);
	
	printf("%s! (%2.3lf seconds)\n", comboInfo->comboName, comboInfo->time);
}

void comboStartTime(){
	if (startTimeTaken == 0){
		startTime = yylval.time;
		startTimeTaken = 1;
		return;
	}
}

%}

%union {
	char  	*strval;
	double	time;
}

%define parse.error verbose

%token A
%token B
%token X
%token Y
%token S

%token LA
%token LB
%token LX
%token LY
%token LS

%token UP
%token UP_RIGHT
%token RIGHT
%token DOWN_RIGHT
%token DOWN
%token DOWN_LEFT
%token LEFT
%token UP_LEFT

%token NA

%type <strval> combo

%type <strval> Left_right Left_right_combos Pk_combo Valkyrie_lance Haze Haze_combos 
%type <strval> To_right_combos 
%type <strval> Pendulum_kick To_down_right_combos 
%type <strval> To_down_combos 
%type <strval> To_down_left_combos 
%type <strval> Missing_talon Skull_Rave Skull_Rave_right_b Illusion To_left_combos
%type <strval> Deathbringer Deathbringer_low To_up_combos
%type <strval> Chakram Better_chakram To_up_right_combos
%type <strval> Shadow_sprint Fatal_elbow Poison_needle Shadow_sprint_combos
%type <strval> Ten_hit_combo

%%

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

combo:
	Left_right_combos
|	Pk_combo
|	Haze_combos	
|	Valkyrie_lance
|	To_right_combos
|	To_down_right_combos
|	To_down_combos
|	To_down_left_combos
|	To_left_combos
|	To_up_combos
|	To_up_right_combos
|	Shadow_sprint_combos
|	Ten_hit_combo
;


Left_right:
	x y		{$$="Left_right";}
;


Left_right_combos:
	Left_right	%prec NA NA
|	Left_right Haze_combos	{snprintf(buff, BUFF_SIZE-1, "%s -> %s", $1, $2);$$ = copyString(buff);}
;

Pk_combo:
	y a	{$$="PK combo";}
;

Valkyrie_lance:
	a a b	{$$="Valkyrie lance";}
;

Haze:
	ab	{$$="Haze";}
;

Haze_combos:
	Haze	%prec NA NA
|	Haze x	{$$="Kronos_cutter";}
|	Haze y	{$$="Death_from_above";}
|	Haze a	{$$="Aqua_spider";}
|	Haze b	{$$="Blind_ghost";}
|	Haze xy	{$$="Crossing Paths";}
|	Haze up	{$$="White Hole";}
;

To_right_combos:
	right y a	{$$="Tartaros";}
|	right a y 	{$$="Circling winds";}
|	right b		{$$="Lance kick";}
|	right xy	{$$="Alondite";}
;

Pendulum_kick:
	down_right b b	{$$="Pendulum_kick";}

To_down_right_combos:
	down_right x	 {$$="Body blow";}
|	down_right y a	 {$$="Meat hook";}
|	down_right y b 	 {$$="Bolt stunner";}
|	down_right a	 {$$="Shadow snap kick";}
|	Pendulum_kick	 %prec NA NA
|	Pendulum_kick a	 {snprintf(buff, BUFF_SIZE-1, "%s -> Shadow", $1);$$ = copyString(buff);}
|	Pendulum_kick up {snprintf(buff, BUFF_SIZE-1, "%s -> White hole", $1);$$ = copyString(buff);}
;

To_down_combos:
	down a	{$$="Low kick";}
|	down b	{$$="Basilisk Fang";}
;

To_down_left_combos:
	down_left y		%prec NA NA {$$="Assassin's Sting";}
|	down_left y x	{$$="Assassin's Sting 2";}
|	down_left a		{$$="Killer bee";}
|	down_left b		{$$="Shinobi Cyclone";}
;

Missing_talon:
	left y b		{$$="Missing_talon";}
;

Skull:
	left b
;

Skull_Rave:
	Skull left b a	{$$="Skull rave";}
;

Skull_Rave_right_b:
	Skull_Rave right b	{$$=$1;}
;

Illusion:
	left xy	{$$="Illusion";}
;	

To_left_combos:
	left x			 {$$="Elbow strike";}
|	left y y a		 {$$="Unicorn's tail";}
|	left y y xy		 {$$="Deadly Talon";}
|	Missing_talon	 %prec NA NA
|	Missing_talon y	 {snprintf(buff, BUFF_SIZE-1, "%s -> Galatine", $1);$$ = copyString(buff);}
|	Missing_talon up {snprintf(buff, BUFF_SIZE-1, "%s -> White hole", $1);$$ = copyString(buff);}
|	left a			 {$$="Hades heel";}
|	Skull b			 {$$="Skull smasher";}
|	Skull left b	 %prec NA NA {$$="Skull smasher Feint";}
|	Skull_Rave		 %prec NA NA
|	Skull_Rave b y 	 	 {snprintf(buff, BUFF_SIZE-1, "%s -> Nice", $1);$$ = copyString(buff);}
|	Skull_Rave_right_b y {snprintf(buff, BUFF_SIZE-1, "%s -> Frenzy", $1);$$ = copyString(buff);}
|	Skull_Rave_right_b a {snprintf(buff, BUFF_SIZE-1, "%s -> Shadow", $1);$$ = copyString(buff);}
|	Skull_Rave_right_b up {snprintf(buff, BUFF_SIZE-1, "%s -> White Hole", $1);$$ = copyString(buff);}
|	Illusion		 %prec NA NA
|	Illusion y		 {snprintf(buff, BUFF_SIZE-1, "%s -> Strike", $1);$$ = copyString(buff);}
|	Illusion a		 {snprintf(buff, BUFF_SIZE-1, "%s -> Sweep", $1);$$ = copyString(buff);}
;

Deathbringer:
	up a	{$$="Deathbringer";}
;

Deathbringer_low:
	Deathbringer down a {snprintf(buff, BUFF_SIZE-1, "%s low", $1);$$ = copyString(buff);}
;

To_up_combos:
	Deathbringer a	{$$="Deathbringer mid";}
|	Deathbringer b	{$$="Deathbringer high";}
|	Deathbringer_low	%prec NA NA
|	Deathbringer_low a	{snprintf(buff, BUFF_SIZE-1, "%s -> Shadow", $1);$$ = copyString(buff);}
|	Deathbringer_low up	{snprintf(buff, BUFF_SIZE-1, "%s -> White hole", $1);$$ = copyString(buff);}
;

Chakram:
	up_right ab	{$$="Chakram";}
;

Better_chakram:
	Chakram right b	{$$="Better chakram";}
;


To_up_right_combos:
	up_right a		{$$="Shadow Scythe";}
|	up_right b b	{$$="Stormbringer";}
|	Chakram			%prec NA NA
|	Chakram b y		{$$="Chakram combo";}
|	Chakram ab		{$$="Spining chakram";}
|	Better_chakram	%prec NA NA
|	Better_chakram y	{$$="Heavy chakram";}
|	Better_chakram a  	{snprintf(buff, BUFF_SIZE-1, "%s -> Shadow", $1);$$ = copyString(buff);}
|	Better_chakram up	{snprintf(buff, BUFF_SIZE-1, "%s -> White hole", $1);$$ = copyString(buff);}
;

Shadow_sprint:
	down down_right right	{$$="Shadow sprint";}
;

Fatal_elbow:
	Shadow_sprint x	{$$="Fatal elbow";}
;

Poison_needle:
	Shadow_sprint a	{$$="Poison needle";}
;

Shadow_sprint_combos:
	Shadow_sprint		%prec NA NA
|	Fatal_elbow			%prec NA NA
|	Fatal_elbow Haze	{snprintf(buff, BUFF_SIZE-1, "%s -> %s", $1, $2);$$ = copyString(buff);}
|	Shadow_sprint y		{$$="Buzzsaw";}
|	Poison_needle		%prec NA NA
|	Poison_needle b		{snprintf(buff, BUFF_SIZE-1, "%s -> Blind ghost", $1);$$ = copyString(buff);}
|	Shadow_sprint b		{$$="Black hole";}
|	Shadow_sprint xy	{$$="Hellhound";}
;

Ten_hit_combo:
	up_left x y y y b y a b y xy	{$$="10 hit combo";}
;

/* Directions */

up:
	UP	{comboStartTime();}
;

up_right:
	UP_RIGHT	{comboStartTime();}
;

right:
	RIGHT	{comboStartTime();}
;

down_right:
	DOWN_RIGHT	{comboStartTime();}
;

down:
	DOWN	{comboStartTime();}
;

down_left:
	DOWN_LEFT	{comboStartTime();}
;

left:
	LEFT	{comboStartTime();}
;

up_left:
	UP_LEFT	{comboStartTime();}
;


/* Press one button */

a:
	A {comboStartTime();} LA
;

b:
	B {comboStartTime();} LB
;

x:
	X {comboStartTime();} LX
;

y:
	Y {comboStartTime();} LY
;


/* Start button */

startButton:
	S
;


/* Press two buttons simultaneously */

ab_prev:
	A {comboStartTime();} B
|	B {comboStartTime();} A
;

ab:
	ab_prev LA LB
|	ab_prev LB LA
;

ax_prev:
	A {comboStartTime();} X
|	X {comboStartTime();} A
;

ax:
	ax_prev LA LX
|	ax_prev LX LA
;

ay_prev:
	A {comboStartTime();} Y
|	Y {comboStartTime();} A
;

ay:
	ay_prev LA LY
|	ay_prev LY LA
;

bx_prev:
	B {comboStartTime();} X
|	X {comboStartTime();} B
;

bx:
	bx_prev LB LX
|	bx_prev LX LB
;

by_prev:
	B {comboStartTime();} Y
|	Y {comboStartTime();} B
;

by:
	by_prev LB LY
|	by_prev LY LB
;

xy_prev:
	X {comboStartTime();} Y
|	Y {comboStartTime();} X
;

xy:
	xy_prev LX LY
|	xy_prev LY LX
;


/* Never used combinations */

Never_used:
	ax
|	ay
|	bx
|	by
;


%%

int main(){
	/* Interrupt handler */
	signal(SIGINT, intHandler);

	/* Initialize variables */
	hits = dict_new();
	fails = 0;
	pthread_mutex_init(&dict_mutex,NULL);
	startTimeTaken = 0;

	/* Message */
	printf("\nLet's practice! Press START button when you have finished.\n\n");

	yyparse();
	intHandler(0);
}