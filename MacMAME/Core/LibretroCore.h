//
//  LibretroCore.h
//  MacMAME
//
//  Libretro API interface for loading and running emulator cores
//

#ifndef LibretroCore_h
#define LibretroCore_h

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#pragma mark - Libretro API Types

// Pixel formats
#define RETRO_PIXEL_FORMAT_0RGB1555 0
#define RETRO_PIXEL_FORMAT_XRGB8888 1
#define RETRO_PIXEL_FORMAT_RGB565   2

// Device types
#define RETRO_DEVICE_NONE     0
#define RETRO_DEVICE_JOYPAD   1
#define RETRO_DEVICE_MOUSE    2
#define RETRO_DEVICE_KEYBOARD 3
#define RETRO_DEVICE_LIGHTGUN 4
#define RETRO_DEVICE_ANALOG   5
#define RETRO_DEVICE_POINTER  6

// Joypad buttons
#define RETRO_DEVICE_ID_JOYPAD_B        0
#define RETRO_DEVICE_ID_JOYPAD_Y        1
#define RETRO_DEVICE_ID_JOYPAD_SELECT   2
#define RETRO_DEVICE_ID_JOYPAD_START    3
#define RETRO_DEVICE_ID_JOYPAD_UP       4
#define RETRO_DEVICE_ID_JOYPAD_DOWN     5
#define RETRO_DEVICE_ID_JOYPAD_LEFT     6
#define RETRO_DEVICE_ID_JOYPAD_RIGHT    7
#define RETRO_DEVICE_ID_JOYPAD_A        8
#define RETRO_DEVICE_ID_JOYPAD_X        9
#define RETRO_DEVICE_ID_JOYPAD_L       10
#define RETRO_DEVICE_ID_JOYPAD_R       11
#define RETRO_DEVICE_ID_JOYPAD_L2      12
#define RETRO_DEVICE_ID_JOYPAD_R2      13
#define RETRO_DEVICE_ID_JOYPAD_L3      14
#define RETRO_DEVICE_ID_JOYPAD_R3      15

// Environment commands
#define RETRO_ENVIRONMENT_SET_ROTATION               1
#define RETRO_ENVIRONMENT_GET_OVERSCAN               2
#define RETRO_ENVIRONMENT_GET_CAN_DUPE               3
#define RETRO_ENVIRONMENT_SET_MESSAGE                6
#define RETRO_ENVIRONMENT_SHUTDOWN                   7
#define RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL      8
#define RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY       9
#define RETRO_ENVIRONMENT_SET_PIXEL_FORMAT          10
#define RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS     11
#define RETRO_ENVIRONMENT_SET_KEYBOARD_CALLBACK     12
#define RETRO_ENVIRONMENT_GET_VARIABLE              15
#define RETRO_ENVIRONMENT_SET_VARIABLES             16
#define RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE       17
#define RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME       18
#define RETRO_ENVIRONMENT_GET_LIBRETRO_PATH         19
#define RETRO_ENVIRONMENT_SET_AUDIO_CALLBACK        22
#define RETRO_ENVIRONMENT_SET_FRAME_TIME_CALLBACK   21
#define RETRO_ENVIRONMENT_GET_RUMBLE_INTERFACE      23
#define RETRO_ENVIRONMENT_GET_INPUT_DEVICE_CAPABILITIES 24
#define RETRO_ENVIRONMENT_GET_LOG_INTERFACE         27
#define RETRO_ENVIRONMENT_GET_PERF_INTERFACE        28
#define RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY 30
#define RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY        31
#define RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO        32
#define RETRO_ENVIRONMENT_SET_GEOMETRY              37
#define RETRO_ENVIRONMENT_GET_CURRENT_SOFTWARE_FRAMEBUFFER 40
#define RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2       67

// Memory types
#define RETRO_MEMORY_SAVE_RAM  0
#define RETRO_MEMORY_RTC       1
#define RETRO_MEMORY_SYSTEM_RAM 2
#define RETRO_MEMORY_VIDEO_RAM  3

#pragma mark - Libretro Structures

struct retro_system_info {
    const char *library_name;
    const char *library_version;
    const char *valid_extensions;
    bool need_fullpath;
    bool block_extract;
};

struct retro_game_geometry {
    unsigned base_width;
    unsigned base_height;
    unsigned max_width;
    unsigned max_height;
    float aspect_ratio;
};

struct retro_system_timing {
    double fps;
    double sample_rate;
};

struct retro_system_av_info {
    struct retro_game_geometry geometry;
    struct retro_system_timing timing;
};

struct retro_game_info {
    const char *path;
    const void *data;
    size_t size;
    const char *meta;
};

struct retro_variable {
    const char *key;
    const char *value;
};

struct retro_log_callback {
    void (*log)(int level, const char *fmt, ...);
};

#pragma mark - Callback Types

typedef void (*retro_video_refresh_t)(const void *data, unsigned width, unsigned height, size_t pitch);
typedef void (*retro_audio_sample_t)(int16_t left, int16_t right);
typedef size_t (*retro_audio_sample_batch_t)(const int16_t *data, size_t frames);
typedef void (*retro_input_poll_t)(void);
typedef int16_t (*retro_input_state_t)(unsigned port, unsigned device, unsigned index, unsigned id);
typedef bool (*retro_environment_t)(unsigned cmd, void *data);

#pragma mark - Core Function Pointers

typedef void (*retro_set_environment_t)(retro_environment_t);
typedef void (*retro_set_video_refresh_t)(retro_video_refresh_t);
typedef void (*retro_set_audio_sample_t)(retro_audio_sample_t);
typedef void (*retro_set_audio_sample_batch_t)(retro_audio_sample_batch_t);
typedef void (*retro_set_input_poll_t)(retro_input_poll_t);
typedef void (*retro_set_input_state_t)(retro_input_state_t);
typedef void (*retro_init_t)(void);
typedef void (*retro_deinit_t)(void);
typedef unsigned (*retro_api_version_t)(void);
typedef void (*retro_get_system_info_t)(struct retro_system_info *info);
typedef void (*retro_get_system_av_info_t)(struct retro_system_av_info *info);
typedef void (*retro_set_controller_port_device_t)(unsigned port, unsigned device);
typedef void (*retro_reset_t)(void);
typedef void (*retro_run_t)(void);
typedef size_t (*retro_serialize_size_t)(void);
typedef bool (*retro_serialize_t)(void *data, size_t size);
typedef bool (*retro_unserialize_t)(const void *data, size_t size);
typedef bool (*retro_load_game_t)(const struct retro_game_info *game);
typedef void (*retro_unload_game_t)(void);
typedef void *(*retro_get_memory_data_t)(unsigned id);
typedef size_t (*retro_get_memory_size_t)(unsigned id);

#pragma mark - C Interface for Swift

#ifdef __cplusplus
extern "C" {
#endif

// Initialization
void libretro_init(void);
void libretro_deinit(void);

// Core management
bool libretro_load_core(const char *path);
void libretro_unload_core(void);
bool libretro_is_loaded(void);

// Core info
void libretro_get_system_info(struct retro_system_info *info);
void libretro_get_system_av_info(struct retro_system_av_info *info);
const char* libretro_get_name(void);
const char* libretro_get_version(void);
const char* libretro_get_extensions(void);

// Game management
bool libretro_load_game(const char *path);
void libretro_unload_game(void);
bool libretro_is_game_loaded(void);

// Emulation control
void libretro_run_frame(void);
void libretro_reset(void);

// Video
unsigned libretro_get_width(void);
unsigned libretro_get_height(void);
double libretro_get_fps(void);
int libretro_get_pixel_format(void);
const void* libretro_get_framebuffer(void);
const void* libretro_get_framebuffer_ex(unsigned *width, unsigned *height, size_t *pitch);
size_t libretro_get_framebuffer_pitch(void);

// Audio
double libretro_get_sample_rate(void);
const int16_t* libretro_get_audio_buffer(void);
size_t libretro_get_audio_frames(void);
void libretro_clear_audio_buffer(void);

// Input
void libretro_set_input(unsigned port, int button, bool pressed);
void libretro_set_button(unsigned port, unsigned button, bool pressed);
void libretro_clear_input(void);

// Save states (file-based)
bool libretro_save_state_to_file(const char *path);
bool libretro_load_state_from_file(const char *path);

// Save states (buffer-based)
size_t libretro_get_save_state_size(void);
bool libretro_save_state(void *buffer, size_t size);
bool libretro_load_state(const void *buffer, size_t size);

// SRAM
void libretro_save_sram(const char *path);
void libretro_load_sram(const char *path);
void* libretro_get_sram(void);
size_t libretro_get_sram_size(void);

// Paths
void libretro_set_system_directory(const char *path);
void libretro_set_save_directory(const char *path);

#ifdef __cplusplus
}
#endif

#endif /* LibretroCore_h */
