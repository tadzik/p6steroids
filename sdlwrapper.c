#include <SDL.h>
#include <SDL_gfxPrimitives.h>
#include <stdlib.h>

typedef struct {
    SDL_Surface *screen;
    int key_states[SDLK_LAST];
    void (*keypressed_cb)(int);
    int running;
} Game;

int timer_cb(int interval)
{
    SDL_Event event;
    event.type = SDL_USEREVENT;
    SDL_PushEvent(&event);
    return interval;
}

extern Game *
game_init(int width, int height)
{
    SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER);

    Game *game = malloc(sizeof(Game));
    game->screen = SDL_SetVideoMode(width, height, 0, SDL_HWSURFACE | SDL_DOUBLEBUF);
    memset(game->key_states, 0, sizeof(int) * SDLK_LAST);
    game->running = 1;
    game->keypressed_cb = NULL;

    SDL_WM_SetCaption("Perl 6 SDL Game", 0);
    SDL_EnableKeyRepeat(1, SDL_DEFAULT_REPEAT_INTERVAL);
    SDL_AddTimer(16, (SDL_NewTimerCallback)timer_cb, NULL);

    return game;
}

extern void
game_set_keypressed_cb(Game *game, void (*keypressed_cb)(int))
{
    game->keypressed_cb = keypressed_cb;
}

extern SDL_Surface *
game_get_surface(Game *game)
{
    return game->screen;
}

extern void
game_fill_screen(Game *game, int r, int g, int b)
{
    SDL_FillRect(game->screen, NULL, SDL_MapRGB(game->screen->format, r, g, b));
}

extern void
game_draw_filled_ellipse(Game *game, int x, int y, int rx, int ry, int r, int g, int b, int a)
{
    filledEllipseRGBA(game->screen, x, y, rx, ry, r, g, b, a);
}

extern void
game_draw_ellipse(Game *game, int x, int y, int rx, int ry, int r, int g, int b, int a)
{
    ellipseRGBA(game->screen, x, y, rx, ry, r, g, b, a);
}

extern void
game_draw_triangle(Game *game, int x1, int y1, int x2, int y2, int x3, int y3,
                               int r, int g, int b, int a)
{
    trigonRGBA(game->screen, x1, y1, x2, y2, x3, y3, r, g, b, a);
}


extern void
game_flip(Game *game)
{
    SDL_Flip(game->screen);
}

extern int
game_is_pressed(Game *game, int idx)
{
    return game->key_states[idx];
}

extern int
game_is_running(Game *game)
{
    return game->running;
}

//waits until a timer tick appears
extern void
game_wait(Game *game)
{
    SDL_Event event;
    for (;;) {
        SDL_WaitEvent(&event);
        switch (event.type) {
        case SDL_USEREVENT: // timer
            return;
        case SDL_KEYDOWN:
            game->key_states[event.key.keysym.sym] = 1;
            break;
        case SDL_KEYUP:
            if (game->keypressed_cb) game->keypressed_cb(event.key.keysym.sym);
            game->key_states[event.key.keysym.sym] = 0;
            break;
        case SDL_QUIT:
            game->running = 0;
            break;
        }
    }
}

extern void
game_free(Game *game)
{
    free(game);
}
