# Persist a VkPipelineCache — fixes per-launch cold pipeline recompilation (issue #121)

## TL;DR
- **#121 is mostly a misdiagnosis.** The on-disk shader cache *is* loaded; RPCS3's design rebuilds every `VkPipeline` from cached PS3 ucode at each launch (the "Compiling shaders" screen). That part is expected.
- **The real gap:** aPS3e never creates a `VkPipelineCache`. Both pipeline-creation calls pass a null cache, so the driver recompiles **SPIR-V → native ISA cold on every launch** — the dominant cost of that screen on mobile.
- **Fix (this PR, 5 files / +135 lines):** one persistent, per-title `VkPipelineCache`, loaded at renderer init and — the part that makes it work on mobile — **flushed to disk right after the startup compile burst**, not only at teardown.
- **Fully validated on-device** (Retroid Flip2 · SM8250 · Adreno 650 · Turnip 26.1.2 · Android 13), plus several days of daily field use on Gran Turismo titles.

## Root cause
`Emu/RSX/VK/VKPipelineCompiler.cpp` / `VKProgramPipeline.cpp` — both creation sites pass no pipeline cache:
```cpp
_vkCreateGraphicsPipelines(*m_device, VK_NULL_HANDLE, 1, &create_info, nullptr, &pipeline);
_vkCreateComputePipelines(*g_render_device, nullptr, 1, &create_info, nullptr, &pipeline);
```
There is no `VkPipelineCache` anywhere in the tree. The on-disk shader cache stores PS3 ucode + pipeline state (not native binaries), so each launch re-links every pipeline from scratch with zero driver-side reuse.

## Why flush-after-burst is the load-bearing detail
Saving only on clean teardown is useless for the titles that need it most: DRM-spawn games (e.g. GT5 Prologue boots `EBOOT.BIN` → spawns `EMAIN.SELF`) and anything that crashes before a clean exit never reach teardown. On GT5P the launcher saved a tiny 24 KB cache while the game renderer compiled all 3272 pipelines and then never saved them — so every boot recompiled cold even "with" a cache object. This PR flushes the cache immediately after `shaders_cache::load()` completes in `on_init_thread`, so the full ISA cache hits disk the moment the burst ends and survives whatever happens later in the session.

## The changes
1. `VKPFNTable.h` — register `vkCreatePipelineCache` / `vkGetPipelineCacheData` / `vkDestroyPipelineCache` (existing dlsym wrangler).
2. `VKPipelineCompiler.cpp` — global `g_pipeline_cache`; `load_pipeline_cache()` at init (header sanity check — corrupt/foreign cache falls back to empty); `flush_pipeline_cache()` (save without destroy); `save_pipeline_cache()` (flush + destroy) at teardown. Per-title path: `rpcs3::cache::get_ppu_cache() + "vk_pipeline_cache.bin"`.
3. `VKPipelineCompiler.h` — declare `flush_pipeline_cache`.
4. `VKProgramPipeline.cpp` — pass the cache handle into both `vkCreate*Pipelines` calls.
5. `VKGSRender.cpp` — `vk::flush_pipeline_cache(*m_device)` right after `shaders_cache::load()` in `on_init_thread`.

Thread-safety: pipeline caches are internally synchronized for `vkCreate*Pipelines`, so the compiler workers share the handle lock-free; no locking added.

## On-device validation (GT5P / NPUA80075, a DRM-spawn title — the hard case)
- Renderer confirmed on the intended driver: `RSX: Found Vulkan-compatible GPU 'Turnip Adreno (TM) 650' running on driver 26.1.2`.
- Cold launch → flush writes `EMAIN.SELF/vk_pipeline_cache.bin` = **93,611,565 bytes** (the full 3272-pipeline ISA cache); survives the title's later in-game crash.
- Warm relaunch → `Loaded Vulkan pipeline cache (93611565 bytes)`; the pipeline-compile phase zips through instead of recompiling cold.
- Invalidation behaves correctly: changing shader quality invalidates only affected pipelines and re-warms on the next boot (content-addressed, no stale serving).
- Field data: across several days of daily sessions the GT5P cache grew incrementally to ~295 MB with consistently fast warm launches; GT6 sits at ~68 MB. No regressions observed.

## Notes
- Targets `main4` (the defect equally exists on 2.39/`main2`).
- `main4` build notes from a clean checkout, if useful: `3rdparty/abseil-cpp` needs populating (built against `20250512.1`), and curl pulls its test suite in unless `-DBUILD_TESTING=OFF`.
- An unofficial interim build is published on my fork for affected users ([`shader-patch-1`](https://github.com/mercurious/aps3e/releases/tag/shader-patch-1)), clearly marked as such; it retires when this lands.
