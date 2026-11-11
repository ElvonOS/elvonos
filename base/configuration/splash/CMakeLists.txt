cmake_minimum_required(VERSION 3.16)
project(ElvonOSSplash LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(LayerShellQt REQUIRED)

add_executable(elvonos-splash
    main.cpp
    resources.qrc
)

target_link_libraries(elvonos-splash
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    LayerShellQt::Interface
)

install(TARGETS elvonos-splash RUNTIME DESTINATION bin)
