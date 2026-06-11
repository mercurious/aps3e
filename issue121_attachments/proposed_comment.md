**Fixed it — and validated on-device. #121 is a misdiagnosis; the real issue is a missing (and, it turns out, mistimed) `VkPipelineCache`.**

The on-disk shader cache loads fine — RPCS3 rebuilds `VkPipeline`s from cached ucode every launch by design. What costs full price every boot is that aPS3e never used a **`VkPipelineCache`**, so the Adreno/Turnip driver recompiles SPIR-V→native ISA cold every time. Both creation calls passed null and there was no cache object anywhere.

**The fix (patch attached, ~5 small files):** register `vkCreate/Get/DestroyPipelineCache`, create one persistent `VkPipelineCache` per title (`get_ppu_cache() + "vk_pipeline_cache.bin"`), and pass it into the two `vkCreate*Pipelines` calls. Internally synchronized for `vkCreate*Pipelines`, so the compiler workers share it lock-free.

**The non-obvious part — and the bit that actually made it work:** saving the cache only on clean teardown (`destroy_pipe_compiler`) is **useless** on mobile, because DRM-spawn titles (and anything that crashes before a clean exit) never reach it. On GT5P the launcher (`EBOOT.BIN`) renderer saved a tiny 24 KB cache, but the **game** renderer (`EMAIN.SELF`) compiled all 3272 pipelines and then the title crashed before it ever saved — so the big cache was never written, and every boot recompiled cold. The fix is to **`flush` the cache right after the startup compile burst** (`shaders_cache::load()`), not only on teardown.

**On-device validation (Retroid Flip2 · Adreno 650 · Turnip 26.1.2), GT5P:**
- Cold launch → flush writes `EMAIN.SELF/vk_pipeline_cache.bin` = **93.6 MB** (the full 3272-pipeline ISA cache), and it survives the subsequent crash.
- Warm relaunch → `Loaded Vulkan pipeline cache (93611565 bytes)` and the pipeline-compile phase **zips through** instead of recompiling cold — same instant relaunch you get on desktop/other backends.

Patch is ready whenever you want it (happy to open a PR). The `flush`-after-load timing is the key takeaway — without it the cache is effectively dead weight for the exact titles that need it most.

**For anyone hitting this in the meantime:** I've put an **unofficial interim build** with the patch on my fork — [`shader-patch-1`](https://github.com/mercurious/aps3e/releases/tag/shader-patch-1) (built from `main4` + this fix, SHA256 in the release notes, source = the [`vk-pipeline-cache`](https://github.com/mercurious/aps3e/tree/vk-pipeline-cache) branch). Clearly marked unofficial, bug reports to the fork please, and **it retires the moment this lands upstream** — it exists only so people aren't stuck recompiling every boot while the PR is reviewed. After several days of daily Gran Turismo sessions on it, the per-title cache has grown to ~295 MB and warm launches stay fast.

*(Minor, unrelated: this only reproduces against the post-2.39 dev branch; the 2.39 tag also needs `3rdparty/abseil-cpp` populated to build, and curl pulls its test suite in unless `-DBUILD_TESTING=OFF`. Small notes if useful.)*
