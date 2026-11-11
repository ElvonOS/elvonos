cmake_minimum_required(VERSION 3.16)
project(ElvonOSPDF LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

add_executable(elvonos-pdf
    main.cpp
    resources.qrc
)

target_link_libraries(elvonos-pdf
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

install(TARGETS elvonos-pdf RUNTIME DESTINATION bin)
