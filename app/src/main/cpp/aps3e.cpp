// SPDX-License-Identifier: WTFPL

#include <jni.h>
#include <assert.h>
#include <string.h>
#include <android/log.h>
#include <vector>
#include <android/native_window_jni.h>

#define VK_USE_PLATFORM_ANDROID_KHR
#include <vulkan/vulkan.h>

#include <linux/prctl.h>
#include <sys/prctl.h>
#include <sys/syscall.h>
#include <sys/resource.h>
#include <thread>
#include <string_view>

#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>

#include <stb_truetype.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-security"
#pragma clang diagnostic ignored "-Wold-style-cast"
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wmissing-noreturn"
#pragma clang diagnostic ignored "-Wsign-compare"

#include "util/logs.hpp"
#include "util/video_provider.h"

#include "Input/product_info.h"
#include "Input/pad_thread.h"

#include "Utilities/cheat_info.h"
#include "Emu/System.h"
#include "Emu/Io/interception.h"
#include "Emu/RSX/RSXThread.h"
#include "Emu/Cell/lv2/sys_usbd.h"

#include "Emu/IdManager.h"

#include "Emu/RSX/RSXDisAsm.h"
#include "Emu/Cell/PPUAnalyser.h"
#include "Emu/Cell/PPUDisAsm.h"
#include "Emu/Cell/PPUThread.h"
#include "Emu/Cell/SPUDisAsm.h"
#include "Emu/Cell/SPUThread.h"
#include "Emu/CPU/CPUThread.h"
#include "Emu/CPU/CPUDisAsm.h"

#include "Emu/Io/Null/NullPadHandler.h"

#include "rpcs3_version.h"
#include "Emu/IdManager.h"
#include "Emu/VFS.h"
#include "Emu/vfs_config.h"
#include "Emu/system_utils.hpp"
#include "Emu/system_config.h"

#include "Emu/system_progress.hpp"
#include "Emu/Cell/Modules/cellGem.h"
#include "Emu/Cell/Modules/cellMsgDialog.h"
#include "Emu/Cell/Modules/cellOskDialog.h"
#include "Emu/Cell/Modules/sceNp.h"

#include "Crypto/unpkg.h"
#include "Crypto/unself.h"
#include "Crypto/unzip.h"
#include "Crypto/decrypt_binaries.h"


#include "Loader/ISO.h"
#include "Loader/PUP.h"
#include "Loader/TAR.h"
#include "Loader/PSF.h"
#include "Loader/mself.hpp"

#include "Utilities/File.h"
#include "Utilities/Thread.h"
#include "util/sysinfo.hpp"
#include "util/serialization_ext.hpp"

#include "Emu/Io/PadHandler.h"

#include "Emu/Io/Null/null_music_handler.h"
#include "Emu/Io/Null/null_camera_handler.h"
#include "Emu/Io/Null/NullKeyboardHandler.h"
#include "Emu/Io/Null/NullMouseHandler.h"
#include "Emu/Io/KeyboardHandler.h"
#include "Emu/Io/MouseHandler.h"

#include "Emu/Audio/Null/NullAudioBackend.h"
#include "Emu/Audio/Cubeb/CubebBackend.h"
#include "Emu/Audio/Null/null_enumerator.h"
#include "Emu/Audio/Cubeb/cubeb_enumerator.h"

#include "Emu/RSX/GSFrameBase.h"

#include "Emu/Io/music_handler_base.h"

#include "Input/raw_mouse_handler.h"

#include "Emu/RSX/VK/VKGSRender.h"

#include "Input/sdl_pad_handler.h"

#include "Emu/Cell/Modules/cellSaveData.h"
#include "Emu/Cell/Modules/sceNpTrophy.h"

#include "Emu/Cell/Modules/cellMusic.h"

#include "Emu/RSX/Overlays/HomeMenu/overlay_home_menu.h"
#include "Emu/RSX/Overlays/overlay_message.h"

#include "yaml-cpp/yaml.h"

#include "Emu/RSX/Overlays/overlay_save_dialog.h"
#include "Emu/Cell/Modules/cellSysutil.h"
#include "Emu/RSX/Overlays/overlay_trophy_notification.h"
#include "Emu/RSX/Overlays/overlay_fonts.h"

#include "cpuinfo.h"
#include "meminfo.h"

#define LOG_TAG "aps3e_native"

#if 1

#define LOGI(...) {}
#define LOGW(...) {}
#define LOGE(...) {}
#define PR {}
#define PRE(f) {}

#else

#define LOGI(...) {      \
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG,"%s : %d",__func__,__LINE__);\
	__android_log_print(ANDROID_LOG_INFO, LOG_TAG,__VA_ARGS__);\
}

#define LOGW(...) {      \
    __android_log_print(ANDROID_LOG_WARN, LOG_TAG,"%s : %d",__func__,__LINE__);\
	__android_log_print(ANDROID_LOG_WARN, LOG_TAG,__VA_ARGS__);\
}

#define LOGE(...) {      \
    __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,"%s : %d",__func__,__LINE__);\
	__android_log_print(ANDROID_LOG_ERROR, LOG_TAG,__VA_ARGS__);\
}

#define PR {__android_log_print(ANDROID_LOG_WARN, LOG_TAG,"%s : %d",__func__,__LINE__);aps3e_log.notice("%s : %d",__func__,__LINE__);}
#define PRE(f) {__android_log_print(ANDROID_LOG_WARN, LOG_TAG,"EmuCallbacks::%s : %d",f,__LINE__);aps3e_log.notice("EmuCallbacks::%s : %d",f,__LINE__);}

#endif

LOG_CHANNEL(aps3e_log);
LOG_CHANNEL(sys_log, "SYS");



/*
static jboolean j_install_firmware(JNIEnv* env,jobject self,jstring pup_path){
	jboolean is_copy=false;
	const char* path=env->GetStringUTFChars(pup_path,&is_copy);
	jboolean result= aps3e_util::install_firmware(path);
    env->ReleaseStringUTFChars(pup_path,path);
    return result;
}*/



//esr ctx
  static const esr_context* find_esr_context(const ucontext_t* ctx)
    {
        u32 offset = 0;
        const auto& mctx = ctx->uc_mcontext;

        while ((offset + 4) < sizeof(mctx.__reserved))
        {
            const auto head = reinterpret_cast<const _aarch64_ctx*>(&mctx.__reserved[offset]);
            if (!head->magic)
            {
                // End of linked list
                return nullptr;
            }

            if (head->magic == ESR_MAGIC)
            {
                return reinterpret_cast<const esr_context*>(head);
            }

            offset += head->size;
        }

        return nullptr;
    }

	uint64_t find_esr(const ucontext_t* ctx){
		auto esr_ctx=find_esr_context(ctx);
		if(esr_ctx)return esr_ctx->esr;
		return -1;
	}

static void signal_handler(int /*sig*/, siginfo_t* info, void* uct) noexcept
{
	ucontext_t* ctx = static_cast<ucontext_t*>(uct);
	auto esr_ctx = find_esr_context(ctx);
    if(esr_ctx){
		LOGE("崩了 esr_ctx->esr %d[0x%x] ec %d[0x%x]",esr_ctx->esr,esr_ctx->esr,(esr_ctx->esr>>26)&0b111111,(esr_ctx->esr>>26)&0b111111)
	};
}

int register_Emulator(JNIEnv* env);
int register_Emulator$Config(JNIEnv* env);
int register_aps3e_Emulator(JNIEnv* env);
JavaVM* g_jvm;

extern "C" __attribute__((visibility("default")))
jint JNI_OnLoad(JavaVM* vm, void* reserved){

    JNIEnv* env = NULL;
    int result=-1;

    LOGW("JNI_OnLoad ");

    g_jvm = vm;
    
    if (vm->GetEnv((void**)&env, JNI_VERSION_1_6) != JNI_OK) {
        LOGE("GetEnv failed");
        goto bail;
    }

    if(register_Emulator(env) != JNI_OK){
        LOGE("register_Emulator failed");
        goto bail;
    }

    if(register_Emulator$Config(env) != JNI_OK){
        LOGE("register_Emulator$Config failed");
        goto bail;
    }
    if (register_aps3e_Emulator(env) != JNI_OK) {
        LOGE("register_Emulator failed");
        goto bail;
    }
    result = JNI_VERSION_1_6;

    LOGW("JNI_OnLoad OK");


    bail:
        return result;
}


#pragma clang diagnostic pop

