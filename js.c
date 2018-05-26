#include <fcntl.h>
#include <stdio.h>
#include <linux/joystick.h>
#include <string.h>
#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/time.h>

/**
 * Reads a joystick event from the joystick device.
 *
 * Returns 0 on success. Otherwise -1 is returned.
 */
int read_event(int fd, struct js_event *event)
{
    ssize_t bytes;

    bytes = read(fd, event, sizeof(*event));

    if (bytes == sizeof(*event))
        return 0;

    /* Error, could not read full event. */
    return -1;
}

/**
 * Current state of an axis.
 */
struct axis_state {
    short x, y;
};

/**
 * Keeps track of the current axis state.
 *
 * NOTE: This function assumes that axes are numbered starting from 0, and that
 * the X axis is an even number, and the Y axis is an odd number. However, this
 * is usually a safe assumption.
 *
 * Returns the axis that the event indicated.
 */
size_t get_axis_state(struct js_event *event, struct axis_state axes[3])
{
    size_t axis = event->number / 2;

    if (axis < 3)
    {
        if (event->number % 2 == 0)
            axes[axis].x = event->value;
        else
            axes[axis].y = event->value;
    }

    return axis;
}

char * appendStrings(char* str1, char* str2)
{
    char * new_str ;

    if((new_str = malloc(strlen(str1)+strlen(str2)+1)) != NULL){
        new_str[0] = '\0';   // ensures the memory is an empty string
        strcat(new_str,str1);
        strcat(new_str,str2);
    } else {
        printf("malloc failed!\n");
        // exit?    
    }
    return new_str;
}


struct buffer {
    char *data;
    pthread_mutex_t buff_mutex;   // Se declara el mutex junto a los datos que va a proteger
};


double getMiliseconds()
{
	struct timeval *t = malloc( sizeof(struct timeval) );

	gettimeofday(t, NULL);

	return (double) t->tv_sec + (double) (t->tv_usec/1000000.0);

}

void* bucle(void* ptr){
    struct buffer *buffer = ptr;
    int i;

    while(1)
    {
        pthread_mutex_lock(&buffer -> buff_mutex);

        if (!strlen(buffer->data))
        {
            char* string = "nothing\n";
            printf("%s",string);
            for(i=0;i<100000-strlen(string);i++)
                printf("\n");
        }
        else 
        {
            printf("%s\n", buffer->data);
            for(i=0;i<4097-strlen(buffer->data);i++)
                printf("\n");
            free(buffer->data);
            buffer->data = "";
        }

        pthread_mutex_unlock(&buffer -> buff_mutex);

        usleep(300000);
    }
    exit(0);
}

int main(int argc, char *argv[])
{
    const char *device;
    int js;
    struct js_event event;
    struct axis_state axes[3] = {0};
    size_t axis;
    long unsigned int thread_id;
    char tempBuff[4096];
    char b;

    struct buffer buffer;
    buffer.data = "";


    pthread_mutex_init(&buffer.buff_mutex,NULL);

    if ( 0 != pthread_create(&thread_id, NULL,bucle, &buffer)) 
    {
        printf("Failing creating thread\n");
        exit(1);
    }

    if (argc > 1)
        device = argv[1];
    else
        device = "/dev/input/js0";

    js = open(device, O_RDONLY);

    if (js == -1)
        perror("Could not open joystick");

    /* This loop will exit if the controller is unplugged. */
    while (read_event(js, &event) == 0)
    {
        switch (event.type)
        {
            case JS_EVENT_BUTTON:
                switch (event.number)
                {
                    case 0:
                        b = 'A';
                        break;
                    case 1:
                        b = 'B';
                        break;
                    case 2:
                        b = 'X';
                        break;
                    case 3:
                        b = 'Y';
                        break;
                    case 7:
                    	b = 'S';
                    	break;

                }

                pthread_mutex_lock(&buffer.buff_mutex);
                snprintf(tempBuff, 4095,"T%lf Button %c %s\n", getMiliseconds(), b, event.value ? "pressed" : "released");
                buffer.data = appendStrings(buffer.data, tempBuff);
                pthread_mutex_unlock(&buffer.buff_mutex);
                break;
            case JS_EVENT_AXIS:
                axis = get_axis_state(&event, axes);
                if (axis < 3 && axis == 0)
                {
                    pthread_mutex_lock(&buffer.buff_mutex);
                    snprintf(tempBuff, 4095, "T%lf Axis %zu at (%6d, %6d)\n", getMiliseconds(), axis, axes[axis].x, axes[axis].y);                    
                    buffer.data = appendStrings(buffer.data, tempBuff);
                    pthread_mutex_unlock(&buffer.buff_mutex);
                }
            default:
                /* Ignore init events. */
                break;
        }
    }

    close(js);
    return 0;
}