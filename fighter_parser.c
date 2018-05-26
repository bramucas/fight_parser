#include "fighter_parser.h"
#include <assert.h>
#include <string.h>
#include <stdlib.h>


int coord[2];   // Buffer used to store each pair of coordinates.
int pointer=0;  

int lastDirection=0;    // Store the last direction the axis was aiming at. It is used to determine when a change of direction happens.

int currentDirection;   // Shows the current direction the axis is aiming at.

/* Determine wich direction (based on 8 directions) is the axis aiming at. */
int processDirection(){
	//printf("[%d,%d] - ", coord[0],coord[1]);
	// Arriba
	if ( (coord[0]>-8000 && coord[0]<8000) && (coord[1]<-24000) )
		return 1;

	// Diagonal derecha-arriba
	if ( (coord[0]>8000) && (coord[1]<-8000) )
		return 2;

	// Derecha
	if ( (coord[0]>24000) && (coord[1]>-8000 && coord[1]<8000) )
		return 3;

	// Diagonal derecha-abajo
	if ( (coord[0]>8000) && (coord[1]>8000) )
		return 4;

	// Abajo
	if ( (coord[0]>-8000 && coord[0]<8000) && (coord[1]>24000) )
		return 5;

	// Diagonal izquierda-abajo
	if ( (coord[0]<-8000) && (coord[1]>8000) )
		return 6;

	// Izquierda
	if ( (coord[0]<-24000) && ((coord[1]>-8000 && coord[1]<8000)) )
		return 7;

	// Diagonal izquierda-arriba
	if ( (coord[0]<-8000) && (coord[1]<-8000) )
		return 8;

	// Ninguna dirección
	return 0;
}

int handleAxisCoord(int coordValue){
	if(pointer<2)
	{
		coord[pointer]=coordValue;
		pointer++;
	} 
	if (pointer>=2) 
 	{
 		// Update current direction of the joystick.
 		currentDirection = processDirection();
 		pointer=0;

 		// If direction has changed from the last time, then return a direction token.
 		if (currentDirection != lastDirection)
 		{
 			lastDirection = currentDirection;
 			return currentDirection;
 		}
 	};
 	return 0;
}

/* Dictionary */

Dictionary* dict_new() {
    Dictionary *dictionary = (Dictionary*)malloc(sizeof(Dictionary));
    assert(dictionary != NULL);
    dictionary->head = NULL;
    dictionary->tail = NULL;
    return dictionary;
}

void dict_add(Dictionary *dictionary, const char *key, int value, double time) {
    Dictionary* aux;
    aux = dict_has(dictionary, key);
    if(aux != NULL){
        aux->head->value = value;
        if (aux->head->bestTime > time)
            aux->head->bestTime = time;
        return;
    }
    if (dictionary->head != NULL) {
        while(dictionary->tail != NULL) {
            dictionary = dictionary->tail;
        }
        Dictionary *next = dict_new();
        dictionary->tail = next;
        dictionary = dictionary->tail;
    }
    int key_length = strlen(key) + 1;
    dictionary->head = (KVPair*)malloc(sizeof(KVPair));
    assert(dictionary->head != NULL);
    dictionary->head->key = (char *)malloc(key_length * sizeof(char));
    assert(dictionary->head->key != NULL);
    strcpy(dictionary->head->key, key);
    dictionary->head->value = value;
    dictionary->head->bestTime = time;
}

Dictionary* dict_has(Dictionary *dictionary, const char *key) {
    if (dictionary->head == NULL)
        return NULL;
    while(dictionary != NULL) {
        if(strcmp(dictionary->head->key, key) == 0)
            return dictionary;
        dictionary = dictionary->tail;
    }
    return NULL;
}

int dict_get(Dictionary *dictionary, const char *key) {
    if (dictionary->head == NULL)
        return 0;
    while(dictionary != NULL) {
        if(strcmp(dictionary->head->key, key) == 0)
            return dictionary->head->value;
        dictionary = dictionary->tail;
    }
    return 0;
}

double dict_getBestTime(Dictionary *dictionary, const char *key) {
    if (dictionary->head == NULL)
        return 0;
    while(dictionary != NULL) {
        if(strcmp(dictionary->head->key, key) == 0)
            return dictionary->head->bestTime;
        dictionary = dictionary->tail;
    }
    return 0;
}

void dict_remove(Dictionary *dictionary, const char *key) {
    if (dictionary->head == NULL)
        return;
    Dictionary *previous = NULL;
    while(dictionary != NULL) {
        if(strcmp(dictionary->head->key, key) == 0) {
            if(previous == NULL) {
                free(dictionary->head->key);
                dictionary->head->key = NULL;
                if (dictionary->tail != NULL) {
                    Dictionary *toremove = dictionary->tail;
                    dictionary->head->key = toremove->head->key;
                    dictionary->tail = toremove->tail;
                    free(toremove->head);
                    free(toremove);
                    return;
                }
            }
            else {
                previous->tail = dictionary->tail;
            }
            free(dictionary->head->key);
            free(dictionary->head);
            free(dictionary);
            return;
        }
        previous = dictionary;
        dictionary = dictionary->tail;
    }
}

void dict_free(Dictionary *dictionary) {
    if(dictionary == NULL)
        return;
    free(dictionary->head->key);
    free(dictionary->head);
    Dictionary *tail = dictionary->tail;
    free(dictionary);
    dict_free(tail);
}


/* UTIL */

/*
 * Search and replace a string with another string , in a string
 * */
char *strReplace(char *search , char *replace , char const *subject)
{
    char  *p = NULL , *old = NULL , *new_subject = NULL ;
    int c = 0 , search_size;
     
    search_size = strlen(search);
     
    //Count how many occurences
    for(p = strstr(subject , search) ; p != NULL ; p = strstr(p + search_size , search))
    {
        c++;
    }
     
    //Final size
    c = ( strlen(replace) - search_size )*c + strlen(subject);
     
    //New subject with new size
    new_subject = malloc( c );
     
    //Set it to blank
    strcpy(new_subject , "");
     
    //The start position
    old = (char*)subject;
     
    for(p = strstr(subject , search) ; p != NULL ; p = strstr(p + search_size , search))
    {
        //move ahead and copy some text from original subject , from a certain position
        strncpy(new_subject + strlen(new_subject) , old , p - old);
         
        //move ahead and copy the replacement text
        strcpy(new_subject + strlen(new_subject) , replace);
         
        //The new start position after this search match
        old = p + search_size;
    }
     
    //Copy the part after the last search match
    strcpy(new_subject + strlen(new_subject) , old);
     
    return new_subject;
}

char * replaceTokenNames(char* subject)
{
    char * aux = subject;
    aux = strReplace("NA", "NoAction", subject);
    aux = strReplace("LA", "ReleasedA", aux);
    aux = strReplace("LB", "ReleasedB", aux);
    aux = strReplace("LX", "ReleasedX", aux);
    aux = strReplace("LY", "ReleasedY", aux);
    return aux;
}



char *copyString(char* original){
    char* pointer = malloc(sizeof(char) * (strlen(original) + 1));
    strncpy(pointer, original, strlen(original));

    return pointer;
}