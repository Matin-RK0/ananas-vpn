#include <jni.h>
#include <string>
#include <thread>
#include <atomic>
#include <android/log.h>
#include <dlfcn.h>

static std::atomic<bool> g_running(false);
static std::thread g_thread;
static void* g_lib_handle = nullptr;

using hevtun_main_t = int (*)(const char *);
using hevtun_quit_t = void (*)();
static hevtun_main_t g_hev_main = nullptr;
static hevtun_quit_t g_hev_quit = nullptr;

static bool ensure_loaded() {
    if (g_lib_handle && g_hev_main && g_hev_quit) {
        return true;
    }
    dlerror();
    g_lib_handle = dlopen("libhev-socks5-tunnel.so", RTLD_NOW);
    if (!g_lib_handle) {
        __android_log_print(ANDROID_LOG_ERROR, "AnanasHevTun", "dlopen failed: %s", dlerror());
        return false;
    }
    g_hev_main = reinterpret_cast<hevtun_main_t>(dlsym(g_lib_handle, "hev_socks5_tunnel_main_from_str"));
    g_hev_quit = reinterpret_cast<hevtun_quit_t>(dlsym(g_lib_handle, "hev_socks5_tunnel_quit"));
    if (!g_hev_main || !g_hev_quit) {
        __android_log_print(ANDROID_LOG_ERROR, "AnanasHevTun", "dlsym failed: %s", dlerror());
        return false;
    }
    return true;
}

static void run_tunnel(std::string config) {
    g_running.store(true);
    if (!ensure_loaded()) {
        g_running.store(false);
        return;
    }
    int rc = g_hev_main(config.c_str());
    __android_log_print(ANDROID_LOG_INFO, "AnanasHevTun", "hev_socks5_tunnel exited rc=%d", rc);
    g_running.store(false);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_ananas_HevTunBridge_start(JNIEnv *env, jclass, jstring config, jint tunFd) {
    if (g_running.load()) {
        return 0;
    }
    if (!ensure_loaded()) {
        return -1;
    }
    const char *cfg = env->GetStringUTFChars(config, nullptr);
    std::string configStr(cfg);
    env->ReleaseStringUTFChars(config, cfg);

    // Inject tunfd into config if not present
    if (configStr.find("tunfd:") == std::string::npos) {
        configStr += "\n";
        configStr += "tunfd: " + std::to_string(tunFd) + "\n";
    }

    g_thread = std::thread(run_tunnel, configStr);
    g_thread.detach();
    return 0;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_ananas_HevTunBridge_stop(JNIEnv *, jclass) {
    if (!g_running.load()) {
        return;
    }
    if (!ensure_loaded()) {
        return;
    }
    g_hev_quit();
}
