cmake_minimum_required(VERSION 3.16)
project(ElvonOSDefrag LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

add_executable(elvonos-defrag
    main.cpp
    ../common/elvonapp.h
    resources.qrc
)

target_link_libraries(elvonos-defrag
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

install(TARGETS elvonos-defrag RUNTIME DESTINATION bin)
