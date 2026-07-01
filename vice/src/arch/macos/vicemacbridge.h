/*
 * vicemacbridge.h - Native macOS bridge for embedding VICE.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#ifndef VICE_VICEMACBRIDGE_H
#define VICE_VICEMACBRIDGE_H

#include <stdint.h>

#define VICEMAC_BRIDGE_ABI_VERSION 2

#ifdef __cplusplus
extern "C" {
#endif

typedef struct vicemac_video_frame_s {
    uint32_t width;
    uint32_t height;
    uint32_t stride;
    uint32_t pixel_format;
    uint64_t sequence;
    const uint8_t *pixels;
} vicemac_video_frame_t;

typedef struct vicemac_drive_status_s {
    uint32_t unit;
    uint32_t enabled;
    int32_t drive_type;
    uint32_t active_drive_number;
    uint32_t led_color;
    uint32_t led_pwm1;
    uint32_t led_pwm2;
    uint32_t drive0_led_intensity;
    uint32_t drive1_led_intensity;
    uint32_t track_valid;
    uint32_t track;
    uint32_t half_track;
    uint32_t disk_side;
    int32_t drive_status_code;
    const char *drive_status_text;
    const char *image_path;
    const char *drive0_image_path;
    const char *drive1_image_path;
} vicemac_drive_status_t;

typedef struct vicemac_cartridge_status_s {
    uint32_t attached;
    int32_t cartridge_id;
    uint32_t cartridge_flags;
    uint32_t rom_size;
    uint32_t chip_count;
    uint32_t bank_count;
    const char *cartridge_name;
    const char *image_path;
} vicemac_cartridge_status_t;

#define VICEMAC_VSID_TEXT_CAPACITY 192U

typedef struct vicemac_vsid_state_s {
    char name[VICEMAC_VSID_TEXT_CAPACITY];
    char author[VICEMAC_VSID_TEXT_CAPACITY];
    char copyright[VICEMAC_VSID_TEXT_CAPACITY];
    char irq[VICEMAC_VSID_TEXT_CAPACITY];
    char driver_info[VICEMAC_VSID_TEXT_CAPACITY];
    uint32_t sync;
    int32_t sid_model;
    uint32_t current_tune;
    uint32_t tune_count;
    uint32_t default_tune;
    uint32_t deciseconds;
    uint32_t driver_address;
    uint32_t load_address;
    uint32_t init_address;
    uint32_t play_address;
    uint32_t data_size;
} vicemac_vsid_state_t;

typedef struct vicemac_audio_samples_s {
    const int16_t *samples;
    uint32_t frame_count;
    uint32_t channel_count;
    uint32_t sample_rate;
    uint64_t sequence;
} vicemac_audio_samples_t;

#define VICEMAC_SID_VOICE_COUNT 3U

typedef struct vicemac_sid_voice_samples_s {
    const int16_t *samples;
    uint32_t frame_count;
    uint32_t voice_count;
    uint32_t chip_index;
    uint32_t sample_rate;
    uint32_t clock_rate;
    uint16_t frequency[VICEMAC_SID_VOICE_COUNT];
    uint8_t control[VICEMAC_SID_VOICE_COUNT];
    uint64_t sequence;
} vicemac_sid_voice_samples_t;

#define VICEMAC_DEBUGGER_MAX_REGISTERS 96U
#define VICEMAC_DEBUGGER_MAX_CPUS 8U
#define VICEMAC_DEBUGGER_REGISTER_NAME_CAPACITY 16U
#define VICEMAC_DEBUGGER_DISASSEMBLY_TEXT_CAPACITY 96U

typedef struct vicemac_debugger_register_s {
    uint32_t id;
    uint32_t bit_width;
    uint32_t flags;
    uint32_t extra;
    uint32_t value;
    char name[VICEMAC_DEBUGGER_REGISTER_NAME_CAPACITY];
} vicemac_debugger_register_t;

typedef struct vicemac_debugger_snapshot_s {
    uint32_t valid;
    uint32_t memspace;
    uint32_t cpu_type;
    int32_t bank;
    uint64_t cycle;
    uint32_t program_counter;
    uint32_t supported_cpu_count;
    uint32_t supported_cpu_types[VICEMAC_DEBUGGER_MAX_CPUS];
    uint32_t register_count;
    vicemac_debugger_register_t registers[VICEMAC_DEBUGGER_MAX_REGISTERS];
} vicemac_debugger_snapshot_t;

typedef struct vicemac_debugger_disassembly_line_s {
    uint32_t address;
    uint32_t size;
    uint8_t bytes[4];
    char text[VICEMAC_DEBUGGER_DISASSEMBLY_TEXT_CAPACITY];
} vicemac_debugger_disassembly_line_t;

typedef struct vicemac_debugger_checkpoint_s {
    uint32_t id;
    uint32_t memspace;
    uint32_t start_address;
    uint32_t end_address;
    uint32_t operations;
    uint32_t enabled;
    uint32_t stops;
    uint32_t temporary;
    uint32_t hit_count;
    uint32_t ignore_count;
} vicemac_debugger_checkpoint_t;

typedef void (*vicemac_video_frame_callback_t)(const vicemac_video_frame_t *frame,
                                               void *context);
typedef void (*vicemac_drive_status_callback_t)(const vicemac_drive_status_t *status,
                                                void *context);
typedef void (*vicemac_cartridge_status_callback_t)(const vicemac_cartridge_status_t *status,
                                                    void *context);
typedef void (*vicemac_vsid_state_callback_t)(const vicemac_vsid_state_t *state,
                                              void *context);
typedef void (*vicemac_audio_samples_callback_t)(const vicemac_audio_samples_t *samples,
                                                 void *context);
typedef void (*vicemac_sid_voice_samples_callback_t)(const vicemac_sid_voice_samples_t *samples,
                                                     void *context);

#define VICEMAC_PIXEL_FORMAT_RGBA8 1U

int vicemac_bridge_abi_version(void);
void vicemac_set_video_frame_callback(vicemac_video_frame_callback_t callback,
                                      void *context);
void vicemac_set_drive_status_callback(vicemac_drive_status_callback_t callback,
                                       void *context);
void vicemac_set_cartridge_status_callback(vicemac_cartridge_status_callback_t callback,
                                           void *context);
void vicemac_set_vsid_state_callback(vicemac_vsid_state_callback_t callback,
                                     void *context);
void vicemac_set_audio_samples_callback(vicemac_audio_samples_callback_t callback,
                                        void *context);
void vicemac_set_sid_voice_samples_callback(vicemac_sid_voice_samples_callback_t callback,
                                            void *context);
const char *vicemac_get_vice_version(void);
int vicemac_has_video_frame_callback(void);
int vicemac_should_capture_sid_voice_samples(uint32_t chip_index,
                                             uint32_t frame_count,
                                             uint32_t sample_rate);
void vicemac_publish_vsid_state(const vicemac_vsid_state_t *state);
void vicemac_publish_audio_samples(const int16_t *samples,
                                   uint32_t frame_count,
                                   uint32_t channel_count,
                                   uint32_t sample_rate);
void vicemac_publish_sid_voice_samples(const int16_t *samples,
                                       uint32_t frame_count,
                                       uint32_t voice_count,
                                       uint32_t chip_index,
                                       uint32_t sample_rate,
                                       uint32_t clock_rate,
                                       const uint16_t *frequency,
                                       const uint8_t *control);
void vicemac_publish_video_frame(uint32_t width,
                                 uint32_t height,
                                 uint32_t stride,
                                 const uint8_t *pixels);
void vicemac_publish_drive_status(uint32_t unit,
                                  uint32_t enabled,
                                  int32_t drive_type,
                                  uint32_t active_drive_number,
                                  uint32_t led_color,
                                  uint32_t led_pwm1,
                                  uint32_t led_pwm2,
                                  uint32_t drive0_led_intensity,
                                  uint32_t drive1_led_intensity,
                                  uint32_t track_valid,
                                  uint32_t track,
                                  uint32_t half_track,
                                  uint32_t disk_side,
                                  int32_t drive_status_code,
                                  const char *drive_status_text,
                                  const char *image_path,
                                  const char *drive0_image_path,
                                  const char *drive1_image_path);
int vicemac_queue_key_event(signed long key, int mod, int pressed);
int vicemac_queue_keyboard_clear(void);
int vicemac_queue_keyboard_text(const char *text);
int vicemac_queue_resource_int(const char *name, int value);
int vicemac_queue_resource_string(const char *name, const char *value);
int vicemac_get_resource_int(const char *name, int *value);
int vicemac_get_resource_string(const char *name, char *buffer, uint32_t buffer_capacity);
int vicemac_queue_joystick_value(uint32_t port, uint32_t value);
int vicemac_queue_mouse_move(float delta_x, float delta_y);
int vicemac_queue_mouse_button(uint32_t button, int pressed);
int vicemac_queue_mouse_reset(void);
int vicemac_queue_pause(int paused);
int vicemac_queue_system_time_sync(int enabled);
int vicemac_queue_machine_model(const char *model);
int vicemac_queue_machine_reset(uint32_t reset_mode);
int vicemac_queue_warp_mode(int enabled);
int vicemac_queue_quit(void);
int vicemac_queue_drive_reset(uint32_t unit);
int vicemac_queue_drive_attach_disk_v2(uint32_t unit,
                                       uint32_t drive,
                                       const char *path,
                                       const char *program_name,
                                       int run_mode);
int vicemac_queue_drive_attach_disk(uint32_t unit,
                                    uint32_t drive,
                                    const char *path,
                                    int run_mode);
int vicemac_queue_drive_detach_disk(uint32_t unit, uint32_t drive);
int vicemac_queue_drive_sound_preview(uint32_t unit);
int vicemac_queue_media_autostart(const char *path, int run_mode);
int vicemac_queue_tape_attach(uint32_t unit, const char *path);
int vicemac_queue_tape_detach(uint32_t unit);
int vicemac_queue_tape_control(uint32_t unit, int control);
int vicemac_queue_cartridge_attach(const char *path);
int vicemac_queue_cartridge_detach(void);
int vicemac_save_snapshot(const char *path, int save_roms, int save_disks);
int vicemac_load_snapshot(const char *path);
int vicemac_peek_memory(uint32_t memspace,
                        int32_t bank,
                        uint32_t address,
                        uint8_t *buffer,
                        uint32_t length);
int vicemac_poke_memory(uint32_t memspace,
                        int32_t bank,
                        uint32_t address,
                        const uint8_t *bytes,
                        uint32_t length);
int vicemac_debugger_snapshot(uint32_t memspace,
                              vicemac_debugger_snapshot_t *snapshot);
int vicemac_debugger_disassemble(uint32_t memspace,
                                 int32_t bank,
                                 uint32_t address,
                                 vicemac_debugger_disassembly_line_t *lines,
                                 uint32_t capacity,
                                 uint32_t *count);
int vicemac_debugger_list_checkpoints(vicemac_debugger_checkpoint_t *checkpoints,
                                      uint32_t capacity,
                                      uint32_t *count);
int vicemac_debugger_set_checkpoint(uint32_t memspace,
                                    uint32_t start_address,
                                    uint32_t end_address,
                                    uint32_t operations,
                                    int stops,
                                    int enabled,
                                    int temporary,
                                    uint32_t *checkpoint_id);
int vicemac_debugger_delete_checkpoint(uint32_t checkpoint_id);
int vicemac_debugger_set_checkpoint_enabled(uint32_t checkpoint_id,
                                            int enabled);
int vicemac_debugger_set_register(uint32_t memspace,
                                  uint32_t register_id,
                                  uint32_t value);
int vicemac_debugger_set_cpu(uint32_t memspace, uint32_t cpu_type);
int vicemac_debugger_step(uint32_t count, int step_over);
int vicemac_debugger_return(void);
int vicemac_debugger_continue(void);
void vicemac_dispatch_queued_events(void);

#ifdef __cplusplus
}
#endif

#endif
