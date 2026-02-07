package com.example.ananas

object HevTunBridge {
    init {
        System.loadLibrary("hev_tun_bridge")
    }

    external fun start(config: String, tunFd: Int): Int
    external fun stop()
}
