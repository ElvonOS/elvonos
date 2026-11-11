cmake_minimum_required(VERSION 3.16)
project(ElvonOSTerminal LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets)

add_executable(elvonos-terminal
    main.cpp
)

target_link_libraries(elvonos-terminal
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    util
)

install(TARGETS elvonos-terminal RUNTIME DESTINATION bin)
