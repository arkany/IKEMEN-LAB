//
//  LibretroCore.c
//  MacMAME
//
//  Libretro core loader and wrapper implementation
//

#include "LibretroCore.h"
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#pragma mark - Static State

static void *core_handle = NULL;
static bool game_loaded = false;
static int pixel_format = RETRO_PIXEL_FORMAT_XRGB8888;

// System paths
static char system_directory[4096] = "";
static char save_directory[4096] = "";

// Video state
static unsigned video_width = 0;
static unsigned video_height = 0;
static size_t video_pitch = 0;
static double video_fps = 60.0;
static void *framebuffer = NULL;
static size_t framebuffer_size = 0;

// Audio state
static double audio_sample_rate = 44100.0;
static int16_t *audio_buffer = NULL;
static size_t audio_buffer_size = 0;
static size_t audio_frames = 0;
#define MAX_AUDIO_FRAMES 8192

// Input state
#define MAX_PORTS 4
#define MAX_BUTTONS 16
static bool input_state[MAX_PORTS][MAX_BUTTONS];

// Core function pointers
static retro_set_environment_t core_set_environment;
static retro_set_video_refresh_t core_set_video_refresh;
static retro_set_audio_sample_t core_set_audio_sample;
static retro_set_audio_sample_batch_t core_set_audio_sample_batch;
static retro_set_input_poll_t core_set_input_poll;
static retro_set_input_state_t core_set_input_state;
static retro_init_t core_init;
static retro_deinit_t core_deinit;
static retro_api_version_t core_api_version;
static retro_get_system_info_t core_get_system_info;
static retro_get_system_av_info_t core_get_system_av_info;
static retro_set_controller_port_device_t core_set_controller_port_device;
static retro_reset_t core_reset;
static retro_run_t core_run;
static retro_serialize_size_t core_serialize_size;
static retro_serialize_t core_serialize;
static retro_unserialize_t core_unserialize;
static retro_load_game_t core_load_game;
static retro_unload_game_t core_unload_game;
static retro_get_memory_data_t core_get_memory_data;
static retro_get_memory_size_t core_get_memory_size;

// Cached system info
static struct retro_system_info system_info;

#pragma mark - Callback Implementations

static void video_refresh_callback(const void *data, unsigned width, unsigned height, size_t pitch) {
    if (data == NULL) return; // Frame dupe
    
    video_width = width;
    video_height = height;
    video_pitch = pitch;
    
    // Calculate required buffer size
    size_t bytes_per_pixel = (pixel_format == RETRO_PIXEL_FORMAT_XRGB8888) ? 4 : 2;
    size_t required_size = height * pitch;
    
    // Reallocate if needed
    if (required_size > framebuffer_size) {
        free(framebuffer);
        framebuffer = malloc(required_size);
        framebuffer_size = required_size;
    }
    
    // Copy framebuffer
    if (framebuffer) {
        memcpy(framebuffer, data, required_size);
    }
}

static void audio_sample_callback(int16_t left, int16_t right) {
    if (audio_frames < MAX_AUDIO_FRAMES && audio_buffer) {
        audio_buffer[audio_frames * 2] = left;
        audio_buffer[audio_frames * 2 + 1] = right;
        audio_frames++;
    }
}

static size_t audio_sample_batch_callback(const int16_t *data, size_t frames) {
    if (audio_buffer == NULL) return 0;
    
    size_t to_copy = frames;
    if (audio_frames + to_copy > MAX_AUDIO_FRAMES) {
        to_copy = MAX_AUDIO_FRAMES - audio_frames;
    }
    
    if (to_copy > 0) {
        memcpy(&audio_buffer[audio_frames * 2], data, to_copy * 2 * sizeof(int16_t));
        audio_frames += to_copy;
    }
    
    return to_copy;
}

static void input_poll_callback(void) {
    // Input is set externally via libretro_set_button
}

static int16_t input_state_callback(unsigned port, unsigned device, unsigned index, unsigned id) {
    if (port >= MAX_PORTS || device != RETRO_DEVICE_JOYPAD || id >= MAX_BUTTONS) {
        return 0;
    }
    return input_state[port][id] ? 1 : 0;
}

static void log_callback(int level, const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    
    const char *level_str = "INFO";
    switch (level) {
        case 0: level_str = "DEBUG"; break;
        case 1: level_str = "INFO"; break;
        case 2: level_str = "WARN"; break;
        case 3: level_str = "ERROR"; break;
    }
    
    printf("[Libretro %s] ", level_str);
    vprintf(fmt, args);
    va_end(args);
}

static bool environment_callback(unsigned cmd, void *data) {
    switch (cmd) {
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE: {
            struct retro_log_callback *cb = (struct retro_log_callback *)data;
            cb->log = log_callback;
            return true;
        }
        
        case RETRO_ENVIRONMENT_GET_CAN_DUPE:
            *(bool *)data = true;
            return true;
            
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
            pixel_format = *(const int *)data;
            printf("[Libretro] Pixel format set to %d\n", pixel_format);
            return true;
        }
        
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
            *(const char **)data = system_directory[0] ? system_directory : ".";
            return true;
            
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
            *(const char **)data = save_directory[0] ? save_directory : ".";
            return true;
            
        case RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY:
            *(const char **)data = system_directory[0] ? system_directory : ".";
            return true;
            
        case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
            return true;
            
        case RETRO_ENVIRONMENT_GET_VARIABLE: {
            struct retro_variable *var = (struct retro_variable *)data;
            var->value = NULL;
            return false;
        }
        
        case RETRO_ENVIRONMENT_SET_VARIABLES:
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2:
            return true;
            
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
            *(bool *)data = false;
            return true;
            
        default:
            // printf("[Libretro] Unhandled environment command: %u\n", cmd);
            return false;
    }
}

#pragma mark - Core Loading

bool libretro_load_core(const char *path) {
    if (core_handle) {
        libretro_unload_core();
    }
    
    core_handle = dlopen(path, RTLD_LAZY);
    if (!core_handle) {
        printf("[Libretro] Failed to load core: %s\n", dlerror());
        return false;
    }
    
    // Load all function pointers
    #define LOAD_SYM(name) core_##name = (retro_##name##_t)dlsym(core_handle, "retro_" #name)
    
    LOAD_SYM(set_environment);
    LOAD_SYM(set_video_refresh);
    LOAD_SYM(set_audio_sample);
    LOAD_SYM(set_audio_sample_batch);
    LOAD_SYM(set_input_poll);
    LOAD_SYM(set_input_state);
    LOAD_SYM(init);
    LOAD_SYM(deinit);
    LOAD_SYM(api_version);
    LOAD_SYM(get_system_info);
    LOAD_SYM(get_system_av_info);
    LOAD_SYM(set_controller_port_device);
    LOAD_SYM(reset);
    LOAD_SYM(run);
    LOAD_SYM(serialize_size);
    LOAD_SYM(serialize);
    LOAD_SYM(unserialize);
    LOAD_SYM(load_game);
    LOAD_SYM(unload_game);
    LOAD_SYM(get_memory_data);
    LOAD_SYM(get_memory_size);
    
    #undef LOAD_SYM
    
    // Verify required functions
    if (!core_init || !core_deinit || !core_run || !core_load_game) {
        printf("[Libretro] Core missing required functions\n");
        dlclose(core_handle);
        core_handle = NULL;
        return false;
    }
    
    // Set up callbacks before init
    if (core_set_environment) core_set_environment(environment_callback);
    
    // Initialize core
    core_init();
    
    // Set remaining callbacks
    if (core_set_video_refresh) core_set_video_refresh(video_refresh_callback);
    if (core_set_audio_sample) core_set_audio_sample(audio_sample_callback);
    if (core_set_audio_sample_batch) core_set_audio_sample_batch(audio_sample_batch_callback);
    if (core_set_input_poll) core_set_input_poll(input_poll_callback);
    if (core_set_input_state) core_set_input_state(input_state_callback);
    
    // Get system info
    if (core_get_system_info) {
        core_get_system_info(&system_info);
        printf("[Libretro] Loaded core: %s %s\n", system_info.library_name, system_info.library_version);
    }
    
    // Allocate audio buffer
    audio_buffer = (int16_t *)malloc(MAX_AUDIO_FRAMES * 2 * sizeof(int16_t));
    
    return true;
}

void libretro_unload_core(void) {
    if (game_loaded) {
        libretro_unload_game();
    }
    
    if (core_handle) {
        if (core_deinit) core_deinit();
        dlclose(core_handle);
        core_handle = NULL;
    }
    
    free(framebuffer);
    framebuffer = NULL;
    framebuffer_size = 0;
    
    free(audio_buffer);
    audio_buffer = NULL;
    
    memset(&system_info, 0, sizeof(system_info));
}

bool libretro_is_loaded(void) {
    return core_handle != NULL;
}

#pragma mark - Core Info

const char* libretro_get_name(void) {
    return system_info.library_name ? system_info.library_name : "";
}

const char* libretro_get_version(void) {
    return system_info.library_version ? system_info.library_version : "";
}

const char* libretro_get_extensions(void) {
    return system_info.valid_extensions ? system_info.valid_extensions : "";
}

#pragma mark - Game Management

bool libretro_load_game(const char *path) {
    if (!core_handle || !core_load_game) return false;
    
    struct retro_game_info game = {0};
    game.path = path;
    
    // Load file data if core needs it
    if (!system_info.need_fullpath) {
        FILE *f = fopen(path, "rb");
        if (f) {
            fseek(f, 0, SEEK_END);
            game.size = ftell(f);
            fseek(f, 0, SEEK_SET);
            
            void *data = malloc(game.size);
            if (data) {
                fread(data, 1, game.size, f);
                game.data = data;
            }
            fclose(f);
        }
    }
    
    bool result = core_load_game(&game);
    
    // Free loaded data
    if (game.data) {
        free((void *)game.data);
    }
    
    if (result) {
        game_loaded = true;
        
        // Get AV info
        struct retro_system_av_info av_info;
        if (core_get_system_av_info) {
            core_get_system_av_info(&av_info);
            video_width = av_info.geometry.base_width;
            video_height = av_info.geometry.base_height;
            video_fps = av_info.timing.fps;
            audio_sample_rate = av_info.timing.sample_rate;
            
            printf("[Libretro] Game loaded: %ux%u @ %.2f fps, audio %.0f Hz\n",
                   video_width, video_height, video_fps, audio_sample_rate);
        }
        
        // Set up controllers
        if (core_set_controller_port_device) {
            core_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
            core_set_controller_port_device(1, RETRO_DEVICE_JOYPAD);
        }
    } else {
        printf("[Libretro] Failed to load game: %s\n", path);
    }
    
    return result;
}

void libretro_unload_game(void) {
    if (core_handle && core_unload_game && game_loaded) {
        core_unload_game();
        game_loaded = false;
    }
}

bool libretro_is_game_loaded(void) {
    return game_loaded;
}

#pragma mark - Emulation Control

void libretro_run_frame(void) {
    if (core_handle && core_run && game_loaded) {
        audio_frames = 0; // Reset audio buffer
        core_run();
    }
}

void libretro_reset(void) {
    if (core_handle && core_reset && game_loaded) {
        core_reset();
    }
}

#pragma mark - Video

unsigned libretro_get_width(void) {
    return video_width;
}

unsigned libretro_get_height(void) {
    return video_height;
}

double libretro_get_fps(void) {
    return video_fps;
}

int libretro_get_pixel_format(void) {
    return pixel_format;
}

const void* libretro_get_framebuffer(void) {
    return framebuffer;
}

size_t libretro_get_framebuffer_pitch(void) {
    return video_pitch;
}

#pragma mark - Audio

double libretro_get_sample_rate(void) {
    return audio_sample_rate;
}

const int16_t* libretro_get_audio_buffer(void) {
    return audio_buffer;
}

size_t libretro_get_audio_frames(void) {
    return audio_frames;
}

void libretro_clear_audio_buffer(void) {
    audio_frames = 0;
}

#pragma mark - Input

void libretro_set_button(unsigned port, unsigned button, bool pressed) {
    if (port < MAX_PORTS && button < MAX_BUTTONS) {
        input_state[port][button] = pressed;
    }
}

void libretro_clear_input(void) {
    memset(input_state, 0, sizeof(input_state));
}

#pragma mark - Save States

size_t libretro_get_save_state_size(void) {
    if (core_handle && core_serialize_size) {
        return core_serialize_size();
    }
    return 0;
}

bool libretro_save_state(void *buffer, size_t size) {
    if (core_handle && core_serialize && game_loaded) {
        return core_serialize(buffer, size);
    }
    return false;
}

bool libretro_load_state(const void *buffer, size_t size) {
    if (core_handle && core_unserialize && game_loaded) {
        return core_unserialize(buffer, size);
    }
    return false;
}

#pragma mark - SRAM

void* libretro_get_sram(void) {
    if (core_handle && core_get_memory_data) {
        return core_get_memory_data(RETRO_MEMORY_SAVE_RAM);
    }
    return NULL;
}

size_t libretro_get_sram_size(void) {
    if (core_handle && core_get_memory_size) {
        return core_get_memory_size(RETRO_MEMORY_SAVE_RAM);
    }
    return 0;
}

#pragma mark - Paths

void libretro_set_system_directory(const char *path) {
    if (path) {
        strncpy(system_directory, path, sizeof(system_directory) - 1);
    }
}

void libretro_set_save_directory(const char *path) {
    if (path) {
        strncpy(save_directory, path, sizeof(save_directory) - 1);
    }
}

#pragma mark - Initialization

void libretro_init(void) {
    // Initialize global state
    memset(input_state, 0, sizeof(input_state));
    pixel_format = RETRO_PIXEL_FORMAT_XRGB8888;
}

void libretro_deinit(void) {
    if (core_handle) {
        libretro_unload_core();
    }
}

#pragma mark - Additional Core Info

void libretro_get_system_info(struct retro_system_info *info) {
    if (info) {
        *info = system_info;
    }
}

void libretro_get_system_av_info(struct retro_system_av_info *info) {
    if (info && core_handle && core_get_system_av_info && game_loaded) {
        core_get_system_av_info(info);
    } else if (info) {
        // Return default values if no game loaded
        info->geometry.base_width = video_width ? video_width : 320;
        info->geometry.base_height = video_height ? video_height : 240;
        info->geometry.max_width = info->geometry.base_width;
        info->geometry.max_height = info->geometry.base_height;
        info->geometry.aspect_ratio = 0;
        info->timing.fps = video_fps > 0 ? video_fps : 60.0;
        info->timing.sample_rate = audio_sample_rate > 0 ? audio_sample_rate : 44100.0;
    }
}

#pragma mark - Video with output parameters

const void* libretro_get_framebuffer_ex(unsigned *width, unsigned *height, size_t *pitch) {
    if (width) *width = video_width;
    if (height) *height = video_height;
    if (pitch) *pitch = video_pitch;
    return framebuffer;
}

#pragma mark - Input alias

void libretro_set_input(unsigned port, int button, bool pressed) {
    libretro_set_button(port, (unsigned)button, pressed);
}

#pragma mark - File-based Save States

bool libretro_save_state_to_file(const char *path) {
    if (!core_handle || !game_loaded) return false;
    
    size_t size = libretro_get_save_state_size();
    if (size == 0) return false;
    
    void *buffer = malloc(size);
    if (!buffer) return false;
    
    bool success = false;
    if (libretro_save_state(buffer, size)) {
        FILE *f = fopen(path, "wb");
        if (f) {
            success = fwrite(buffer, 1, size, f) == size;
            fclose(f);
        }
    }
    
    free(buffer);
    return success;
}

bool libretro_load_state_from_file(const char *path) {
    if (!core_handle || !game_loaded) return false;
    
    FILE *f = fopen(path, "rb");
    if (!f) return false;
    
    fseek(f, 0, SEEK_END);
    size_t size = ftell(f);
    fseek(f, 0, SEEK_SET);
    
    void *buffer = malloc(size);
    if (!buffer) {
        fclose(f);
        return false;
    }
    
    bool success = false;
    if (fread(buffer, 1, size, f) == size) {
        success = libretro_load_state(buffer, size);
    }
    
    free(buffer);
    fclose(f);
    return success;
}

#pragma mark - SRAM File Operations

void libretro_save_sram(const char *path) {
    void *sram = libretro_get_sram();
    size_t size = libretro_get_sram_size();
    
    if (sram && size > 0 && path) {
        FILE *f = fopen(path, "wb");
        if (f) {
            fwrite(sram, 1, size, f);
            fclose(f);
            printf("[Libretro] Saved SRAM to %s (%zu bytes)\n", path, size);
        }
    }
}

void libretro_load_sram(const char *path) {
    void *sram = libretro_get_sram();
    size_t size = libretro_get_sram_size();
    
    if (sram && size > 0 && path) {
        FILE *f = fopen(path, "rb");
        if (f) {
            fread(sram, 1, size, f);
            fclose(f);
            printf("[Libretro] Loaded SRAM from %s (%zu bytes)\n", path, size);
        }
    }
}
