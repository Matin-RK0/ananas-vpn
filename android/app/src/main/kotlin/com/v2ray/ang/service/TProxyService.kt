package com.v2ray.ang.service

object TProxyService {
    init {
        System.loadLibrary("hev-socks5-tunnel")
    }

    external fun TProxyStartService(configPath: String, tunFd: Int)
    external fun TProxyStopService()
    external fun TProxyGetStats(): LongArray?
}
