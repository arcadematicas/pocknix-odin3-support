/*
 * oled-refresher — refresco de píxeles para el panel OLED de la AYN Odin 3.
 *
 * POR QUÉ EXISTE
 *   Los paneles OLED sufren retención de imagen (burn-in) si muestran contenido estático
 *   mucho tiempo. Este programa llena la pantalla con ruido aleatorio en bloques de
 *   CELL_PX × CELL_PX durante N segundos, lo que ejercita todos los subpíxeles por igual
 *   y ayuda a "descargar" la retención. Se lanza desde oled-care-daemon.py (o desde el
 *   botón "Run Pixel Refresher" del QAM) cuando la consola lleva rato en modo juego.
 *
 * HISTORIA
 *   La versión original se compiló a mano EN la Odin (C + SDL2) y nunca se subió el fuente
 *   al repositorio: al reinstalar con una imagen nueva el binario desapareció y el daemon
 *   empezó a registrar "Refresher finished with code 127" (comando no encontrado). Este es
 *   el fuente reconstruido (16/09/2026) a partir del comportamiento documentado.
 *
 * USO
 *   oled-refresher [duración_segundos] [cell_px]
 *   Por defecto 9 s y bloques de 3 px. Sale antes si se pulsa una tecla o un botón.
 *
 * RENDER
 *   No se dibuja píxel a píxel: se genera un ruido pequeño (pantalla/CELL_PX) en una
 *   textura en streaming y se escala con filtrado NEAREST. Así el coste es mínimo incluso
 *   a pantalla completa, que es lo que importa porque corre DENTRO de la sesión de juego.
 *
 * SDL_VIDEODRIVER lo elige quien lo llama: x11 contra el Xwayland de gamescope en modo
 * juego, wayland en el escritorio (ver oled-care-daemon.py).
 */

#include <SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define DEFAULT_DURATION 9
#define DEFAULT_CELL_PX  3
#define TARGET_FPS       30

/* Ruido barato y rápido: xorshift32. No hace falta calidad criptográfica, solo que los
 * bloques cambien de color en cada frame. */
static Uint32 rng_state = 0x9e3779b9u;

static inline Uint32 rng_next(void)
{
    Uint32 x = rng_state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    return rng_state = x;
}

int main(int argc, char *argv[])
{
    int duration = (argc > 1) ? atoi(argv[1]) : DEFAULT_DURATION;
    int cell_px  = (argc > 2) ? atoi(argv[2]) : DEFAULT_CELL_PX;

    if (duration <= 0) duration = DEFAULT_DURATION;
    if (cell_px  <= 0) cell_px  = DEFAULT_CELL_PX;

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER) != 0) {
        fprintf(stderr, "oled-refresher: SDL_Init: %s\n", SDL_GetError());
        return 1;
    }

    /* FULLSCREEN_DESKTOP respeta la resolución del escritorio (en la Odin llega rotada por
     * gamescope), así que no hay que adivinar si son 1080x1920 o 1920x1080. */
    SDL_Window *win = SDL_CreateWindow("oled-refresher",
                                       SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                       0, 0, SDL_WINDOW_FULLSCREEN_DESKTOP);
    if (!win) {
        fprintf(stderr, "oled-refresher: CreateWindow: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Renderer *ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    if (!ren) ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_SOFTWARE);
    if (!ren) {
        fprintf(stderr, "oled-refresher: CreateRenderer: %s\n", SDL_GetError());
        SDL_DestroyWindow(win);
        SDL_Quit();
        return 1;
    }

    /* El "lienzo" es la pantalla dividida por CELL_PX: se rellena de ruido y se escala. */
    int out_w = 0, out_h = 0;
    SDL_GetRendererOutputSize(ren, &out_w, &out_h);
    if (out_w <= 0 || out_h <= 0) { out_w = 1080; out_h = 1920; }

    int noise_w = out_w / cell_px; if (noise_w < 1) noise_w = 1;
    int noise_h = out_h / cell_px; if (noise_h < 1) noise_h = 1;

    SDL_Texture *tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888,
                                         SDL_TEXTUREACCESS_STREAMING, noise_w, noise_h);
    if (!tex) {
        fprintf(stderr, "oled-refresher: CreateTexture: %s\n", SDL_GetError());
        SDL_DestroyRenderer(ren);
        SDL_DestroyWindow(win);
        SDL_Quit();
        return 1;
    }
    SDL_SetTextureScaleMode(tex, SDL_ScaleModeNearest);

    Uint32 *pixels = malloc((size_t)noise_w * (size_t)noise_h * sizeof(Uint32));
    if (!pixels) {
        fprintf(stderr, "oled-refresher: sin memoria\n");
        SDL_DestroyTexture(tex);
        SDL_DestroyRenderer(ren);
        SDL_DestroyWindow(win);
        SDL_Quit();
        return 1;
    }

    /* Un mando abierto = pulsar cualquier botón cancela. */
    SDL_GameController *pad = NULL;
    for (int i = 0; i < SDL_NumJoysticks(); i++) {
        if (SDL_IsGameController(i)) { pad = SDL_GameControllerOpen(i); break; }
    }

    rng_state ^= (Uint32)time(NULL);

    const Uint32 start = SDL_GetTicks();
    const Uint32 limit = (Uint32)duration * 1000u;
    const Uint32 frame_ms = 1000u / TARGET_FPS;
    int running = 1;

    printf("oled-refresher: %ds, bloques de %dpx, ruido %dx%d escalado a %dx%d\n",
           duration, cell_px, noise_w, noise_h, out_w, out_h);
    fflush(stdout);

    while (running) {
        Uint32 frame_start = SDL_GetTicks();

        SDL_Event ev;
        while (SDL_PollEvent(&ev)) {
            switch (ev.type) {
                case SDL_QUIT:
                case SDL_KEYDOWN:
                case SDL_MOUSEBUTTONDOWN:
                case SDL_JOYBUTTONDOWN:
                case SDL_CONTROLLERBUTTONDOWN:
                    running = 0;
                    break;
                default:
                    break;
            }
        }

        /* Ruido opaco. Se limita el brillo a un rango medio-alto: el objetivo es ejercitar
         * los subpíxeles, no deslumbrar en una habitación a oscuras. */
        for (int i = 0; i < noise_w * noise_h; i++) {
            Uint32 r = (rng_next() & 0x7f) + 0x60;   /* 0x60..0xdf */
            Uint32 g = (rng_next() & 0x7f) + 0x60;
            Uint32 b = (rng_next() & 0x7f) + 0x60;
            pixels[i] = 0xff000000u | (r << 16) | (g << 8) | b;
        }

        SDL_UpdateTexture(tex, NULL, pixels, noise_w * (int)sizeof(Uint32));
        SDL_RenderClear(ren);
        SDL_RenderCopy(ren, tex, NULL, NULL);
        SDL_RenderPresent(ren);

        if (SDL_GetTicks() - start >= limit) running = 0;

        Uint32 spent = SDL_GetTicks() - frame_start;
        if (spent < frame_ms) SDL_Delay(frame_ms - spent);
    }

    if (pad) SDL_GameControllerClose(pad);
    free(pixels);
    SDL_DestroyTexture(tex);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}
