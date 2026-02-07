cmake_minimum_required(VERSION 3.18.1)
project(hev_tun_bridge)

add_library(hev_tun_bridge SHARED
    hev_tun_bridge.cpp
)

find_library(log-lib log)
find_library(dl-lib dl)

target_link_libraries(hev_tun_bridge
    ${log-lib}
    ${dl-lib}
)
