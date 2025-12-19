# MAME Embedding Research for macOS

## Executive Summary

After researching the MAME source code and related projects, here are the viable approaches for embedding MAME emulation into a native macOS app with Metal rendering.

---

## 1. Libretro-MAME Core

### Status: ✅ EXISTS and builds for macOS

**Repository:** https://github.com/libretro/mame

**Build Command for macOS:**
```bash
# For Apple Silicon (arm64)
make -f Makefile.libretro platform=osx CROSS_COMPILE=1

# For Intel
make -f Makefile.libretro platform=osx

# For faster rebuilds after initial build
make -f Makefile.libretro platform=osx PREMAKE=0
```

**Key Build Flags:**
- `OSD=retro` - Uses the libretro OSD layer instead of SDL/native
- `TARGETOS=macosx`
- `PLATFORM=arm64` or `PLATFORM=x64`
- `NO_OPENGL=1` - Can disable OpenGL if not needed
- `DONT_USE_NETWORK=1` - For simpler builds

**Framebuffer Output:**
The libretro API provides raw framebuffer output via the `retro_video_refresh_t` callback:
```c
typedef void (*retro_video_refresh_t)(const void *data, 
                                       unsigned width, 
                                       unsigned height, 
                                       size_t pitch);
```

This gives you direct access to the rendered frame as a pixel buffer (typically XRGB8888 format) that can be uploaded to a Metal texture.

**Pros:**
- Clean API designed for embedding
- Handles all MAME complexity internally
- Provides framebuffer directly - perfect for Metal rendering
- Active maintenance (updated to MAME 0.274)
- Includes savestates, input abstraction, etc.

**Cons:**
- Large library (~200MB+ for full MAME)
- May need filtering to specific arcade cores for smaller size
- Uses older MAME versions (updates lag behind mainline)

---

## 2. MAME as Library (Native Approach)

### Status: ⚠️ POSSIBLE but requires custom OSD implementation

MAME doesn't have an official library build target, but the architecture supports it through the **OSD (Operating System Dependent) interface**.

### Key Files:
- **`src/osd/osdepend.h`** - Core OSD interface definition
- **`src/osd/mac/`** - Existing macOS OSD implementation
- **`src/emu/render.h`** - Render target and primitive system

### The OSD Interface (`osd_interface` class)

```cpp
// From src/osd/osdepend.h
class osd_interface
{
public:
    // Core lifecycle
    virtual void init(running_machine &machine) = 0;
    virtual void update(bool skip_redraw) = 0;
    virtual void input_update(bool relative_reset) = 0;
    
    // Video (where framebuffer access happens)
    virtual void add_audio_to_recording(const int16_t *buffer, int samples_this_frame) = 0;
    virtual std::vector<ui::menu_item> get_slider_list() = 0;
    
    // Audio
    virtual bool no_sound() = 0;
    virtual uint32_t sound_stream_sink_open(...) = 0;
    virtual void sound_stream_sink_update(uint32_t id, const int16_t *buffer, int samples_this_frame) = 0;
    
    // Input
    virtual void customize_input_type_list(std::vector<input_type_entry> &typelist) = 0;
};
```

### Framebuffer Access via Software Renderer

The key to getting raw framebuffers is in **`src/emu/rendersw.hxx`**:

```cpp
// Software renderer that outputs to raw pixel buffer
template <typename PixelType, int SrcShiftR, int SrcShiftG, int SrcShiftB, 
          int DstShiftR, int DstShiftG, int DstShiftB>
class software_renderer
{
    // Renders primitives directly to a pixel buffer
    static void draw_primitives(render_primitive_list const &primlist, 
                                void *dstdata,  // Your framebuffer!
                                u32 width, 
                                u32 height, 
                                u32 pitch);
};
```

**Usage pattern (from `src/emu/video.cpp`):**
```cpp
// MAME uses this internally for screenshots - same pattern works for embedding
snap_renderer::draw_primitives(primlist, 
                               &m_snap_bitmap.pix(0),  // output buffer
                               width, height, 
                               m_snap_bitmap.rowpixels());
```

### Building a Custom Embedding

1. Create a minimal OSD that inherits from `osd_common_t` (in `src/osd/modules/lib/osdobj_common.h`)
2. Override `video_init()` to NOT create windows
3. Use `render_target` to get primitives, render to buffer with `software_renderer`
4. Upload buffer to Metal texture

**Minimal Build Target:**
```bash
# Use tiny subtarget for minimal driver set
make SUBTARGET=tiny OSD=mac
```

---

## 3. BGFX Metal Backend

### Status: ✅ MAME has native Metal support via BGFX

**Key finding:** MAME's BGFX renderer already supports Metal!

From **`src/osd/modules/lib/osdobj_common.cpp`**:
```cpp
{ OSDOPTION_BGFX_BACKEND, "auto", 
  "BGFX backend to use (d3d9, d3d11, d3d12, metal, opengl, gles, vulkan)" }
```

From **`src/osd/modules/render/drawbgfx.cpp`**:
```cpp
init.type = bgfx::RendererType::Metal;
```

### External Metal Texture Integration

BGFX supports external textures but requires modifications. The cleaner approach is:

1. **Option A:** Use BGFX's Metal backend with a custom window target
2. **Option B:** Bypass BGFX entirely, use software_renderer to a buffer, upload to Metal

For native app integration, **Option B is recommended** - it gives you full control over the Metal pipeline.

---

## 4. Minimal MAME (Tiny Subtarget)

### Status: ✅ SUPPORTED

MAME has built-in support for minimal builds via SUBTARGET.

**Build command:**
```bash
make SUBTARGET=tiny
```

**Configuration file:** `scripts/target/mame/tiny.lua`

This creates a build with only specific drivers. You can create your own subtarget:

```lua
-- scripts/target/mame/arcade.lua (custom)
-- Only include CPUs and sound chips needed for your games
CPUS["Z80"] = true
CPUS["M68000"] = true
SOUNDS["YM2151"] = true
-- etc.
```

**Size reduction:** Full MAME is ~300MB+, tiny builds can be 20-50MB.

---

## 5. FinalBurn Neo Alternative

### Status: ✅ BETTER EMBEDDING SUPPORT

**Repository:** https://github.com/finalburnneo/FBNeo

FBNeo has a cleaner embedding architecture than MAME:

**Key directories:**
- `src/burn/` - Core emulation (standalone, no UI dependencies)
- `src/burner/` - Frontend code (can be replaced)
- `src/intf/` - Platform interfaces (video, audio, input abstractions)

**macOS build:**
```bash
make sdl2  # SDL2-based build
```

**Pros:**
- Smaller codebase (~50% of MAME's arcade code)
- Cleaner separation between core and frontend
- Good libretro integration
- C++03 compatible (simpler dependencies)

**Cons:**
- Fewer supported games than MAME
- Less accurate for some systems
- Based on older MAME code for some drivers

---

## 6. Existing macOS Apps Using Emulators

### OpenEmu
- **Architecture:** Plugin-based, each emulator is a separate bundle
- **Video:** Uses OpenGL/Metal for rendering
- **Integration:** Does NOT use MAME (uses FinalBurn for arcade)
- **Approach:** Loads emulators as dylibs with a standard interface

### SDL MAME (from mame-src)
- MAME's official macOS OSD is in `src/osd/mac/`
- Uses NSWindow + OpenGL view
- Has Metal support via BGFX backend

---

## Recommended Approach for MacMAME

### Option 1: Libretro Core (Fastest to Implement)

```
┌─────────────────────────────────────────────────────┐
│  MacMAME App (Swift)                                │
│  ┌─────────────────┐    ┌─────────────────────┐    │
│  │   Metal View    │◄───│ libretro-mame.dylib │    │
│  │   (renders      │    │ (loaded at runtime)  │    │
│  │    framebuffer) │    │                      │    │
│  └─────────────────┘    └─────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

**Implementation:**
1. Build libretro-mame for macOS
2. Create Swift wrapper for libretro API
3. On each frame, receive pixel buffer via `retro_video_refresh`
4. Upload to MTLTexture, render with Metal

### Option 2: Custom MAME OSD (More Control)

```
┌─────────────────────────────────────────────────────┐
│  MacMAME App (Swift + C++)                          │
│  ┌─────────────────┐    ┌─────────────────────┐    │
│  │   Metal View    │◄───│ Custom OSD Layer    │    │
│  │                 │    │ (software_renderer) │    │
│  └─────────────────┘    └─────────────────────┘    │
│                              │                      │
│                              ▼                      │
│                    ┌─────────────────────┐         │
│                    │ MAME Core (static)  │         │
│                    └─────────────────────┘         │
└─────────────────────────────────────────────────────┘
```

**Implementation:**
1. Create custom OSD inheriting from `osd_common_t`
2. Use `software_renderer::draw_primitives()` to render to buffer
3. Link MAME statically or as dynamic library
4. Swift/ObjC bridge for Metal integration

---

## Code Snippets for Integration

### Libretro Integration (Swift)

```swift
// Load libretro core
let core = dlopen("mame_libretro.dylib", RTLD_NOW)
let retro_run = dlsym(core, "retro_run")

// Video callback - receives framebuffer
let videoCallback: retro_video_refresh_t = { data, width, height, pitch in
    guard let pixels = data else { return }
    // Upload to Metal texture
    metalTexture.replace(region: MTLRegionMake2D(0, 0, Int(width), Int(height)),
                         mipmapLevel: 0,
                         withBytes: pixels,
                         bytesPerRow: Int(pitch))
}
```

### MAME Software Renderer Integration (C++)

```cpp
// Custom OSD video update
void my_osd::update(bool skip_redraw) {
    if (!skip_redraw) {
        render_primitive_list &primlist = m_target->get_primitives();
        primlist.acquire_lock();
        
        // Render to our buffer (BGRA format for Metal)
        software_renderer<uint32_t, 0,0,0, 16,8,0>::draw_primitives(
            primlist,
            m_framebuffer,  // uint32_t* buffer
            m_width,
            m_height,
            m_pitch
        );
        
        primlist.release_lock();
        
        // Signal Swift/Metal side to upload texture
        notifyFrameReady(m_framebuffer, m_width, m_height);
    }
}
```

---

## Next Steps

1. **Prototype libretro approach first** - fastest path to working emulation
2. **Create tiny subtarget** with just CPS1/CPS2/Neo Geo for testing
3. **Build EmulatorBridge** Swift class to manage core lifecycle
4. **Implement Metal rendering pipeline** for framebuffer display
5. **Add input handling** via libretro or custom OSD

---

## References

- MAME Source: `mame-src/` in workspace
- Libretro MAME: https://github.com/libretro/mame
- Libretro API: https://docs.libretro.com/development/cores/developing-cores/
- FinalBurn Neo: https://github.com/finalburnneo/FBNeo
- OpenEmu: https://github.com/OpenEmu/OpenEmu (architecture reference)
