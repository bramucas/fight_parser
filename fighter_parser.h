#include "y.tab.h"

int coord[2];
int pointer;

int lastDirection;
int currentDirection;


int processDirection();
int handleAxisCoord(int coord);


/* Dictionary */

typedef struct {
    char *key;
    int value;
    double bestTime;
} KVPair;

typedef struct Dictionary_t {
    KVPair *head;
    struct Dictionary_t *tail;
} Dictionary;

Dictionary* dict_new();
void dict_add(Dictionary *dictionary, const char *key, int value, double time);
Dictionary* dict_has(Dictionary *dictionary, const char *key);
int dict_get(Dictionary *dictionary, const char *key);
void dict_remove(Dictionary *dictionary, const char *key);
void dict_free(Dictionary *dictionary);

/* Util */

char *strReplace(char *search , char *replace , char const *subject);
char * replaceTokenNames(char* subject);
char *copyString(char* original);