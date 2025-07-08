#define SDL_MAIN_USE_CALLBACKS

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>


extern uint my_startup(int argc, char *argv[]);
extern void my_quit(SDL_AppResult result);
extern uint my_event(SDL_Event *event);
extern uint my_iterate();

SDL_AppResult SDL_AppIterate(void *appstate)
{
    // Call the shared library to handle events.
    return my_iterate();
}

SDL_AppResult SDL_AppEvent(void *appstate, SDL_Event *event)
{
    // Call the shared library to handle events.
    return my_event(event);
}

SDL_AppResult SDL_AppInit(void **appstate, int argc, char *argv[])
{
    // Call the shared library to handle setup.
    return my_startup(argc, argv);
}

void SDL_AppQuit(void *appstate, SDL_AppResult result)
{
    // Call the shared library to hande cleanup.
    my_quit(result);
}
