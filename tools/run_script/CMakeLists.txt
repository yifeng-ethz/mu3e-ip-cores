cmake_minimum_required(VERSION 3.10)
project(mu3e_run_script_tools LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Python3 REQUIRED COMPONENTS Interpreter)
find_package(Threads REQUIRED)

set(ONLINE_DPV2_ROOT "/home/yifeng/packages/online_dpv2/online" CACHE PATH "online_dpv2 checkout root")
set(ONLINE_SC_ROOT "/home/yifeng/packages/online_sc/online" CACHE PATH "online_sc checkout root")

set(MUDAQ_COMMON_DIR "${ONLINE_DPV2_ROOT}/common" CACHE PATH "MuDAQ common source/include root")
set(MUDAQ_BUILD_DIR "${ONLINE_DPV2_ROOT}/build/common/libmudaq" CACHE PATH "MuDAQ build directory")
set(INCMUDAQ_DIR "${MUDAQ_COMMON_DIR}/include" CACHE PATH "MuDAQ public include directory")

if(NOT EXISTS "${MUDAQ_BUILD_DIR}/liblibmudaq.a" AND EXISTS "${ONLINE_SC_ROOT}/build-mf/common/libmudaq/liblibmudaq.a")
    set(MUDAQ_COMMON_DIR "${ONLINE_SC_ROOT}/common")
    set(MUDAQ_BUILD_DIR "${ONLINE_SC_ROOT}/build-mf/common/libmudaq")
    set(INCMUDAQ_DIR "${MUDAQ_COMMON_DIR}/include")
endif()

set(MUDAQ_LIBRARY "${MUDAQ_BUILD_DIR}/liblibmudaq.a" CACHE FILEPATH "MuDAQ static library")
if(NOT EXISTS "${MUDAQ_LIBRARY}")
    message(FATAL_ERROR "MuDAQ library not found: ${MUDAQ_LIBRARY}")
endif()

set(RUN_SCRIPT_COMMON_INCLUDES
    ${MUDAQ_COMMON_DIR}/libmudaq
    ${MUDAQ_COMMON_DIR}/include
    ${MUDAQ_COMMON_DIR}/include/generated
    ${MUDAQ_COMMON_DIR}/firmware/include
)

set(SWB_A10_REGISTERS_VHD
    "${CMAKE_CURRENT_SOURCE_DIR}/../../firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/registers/a10_pcie_registers.vhd"
    CACHE FILEPATH "Firmware-authoritative SWB PCIe register package"
)
get_filename_component(SWB_A10_REGISTERS_VHD "${SWB_A10_REGISTERS_VHD}" ABSOLUTE)
set(SWB_PCIE_REGISTERS_HEADER "${CMAKE_CURRENT_BINARY_DIR}/swb_pcie_registers_generated.h")
add_custom_command(
    OUTPUT "${SWB_PCIE_REGISTERS_HEADER}"
    COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/gen_swb_pcie_registers.py"
        --input "${SWB_A10_REGISTERS_VHD}"
        --output "${SWB_PCIE_REGISTERS_HEADER}"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/gen_swb_pcie_registers.py"
        "${SWB_A10_REGISTERS_VHD}"
    VERBATIM
)
add_custom_target(generate_swb_pcie_registers DEPENDS "${SWB_PCIE_REGISTERS_HEADER}")

add_executable(sc_tool sc_tool.cpp)
add_executable(rc_tool rc_tool.cpp)
add_executable(dma_tool dma_tool.cpp)

add_dependencies(sc_tool generate_swb_pcie_registers)
target_include_directories(sc_tool PRIVATE ${RUN_SCRIPT_COMMON_INCLUDES} "${CMAKE_CURRENT_BINARY_DIR}")
target_include_directories(rc_tool PRIVATE ${RUN_SCRIPT_COMMON_INCLUDES})
target_include_directories(dma_tool PRIVATE
    ${RUN_SCRIPT_COMMON_INCLUDES}
    ${INCMUDAQ_DIR}
    ${INCMUDAQ_DIR}/generated
)
target_link_libraries(sc_tool PRIVATE ${MUDAQ_LIBRARY})
target_link_libraries(rc_tool PRIVATE ${MUDAQ_LIBRARY})
target_link_libraries(dma_tool PRIVATE Threads::Threads)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../switching_pc/slowcontrol/FEBSlowcontrolInterface.h")
    add_executable(test_slowcontrol test_slowcontrol.cpp)
    target_include_directories(test_slowcontrol PRIVATE ${RUN_SCRIPT_COMMON_INCLUDES})
    target_link_libraries(test_slowcontrol PRIVATE ${MUDAQ_LIBRARY})
    install(TARGETS test_slowcontrol DESTINATION bin)
endif()

install(TARGETS sc_tool
    DESTINATION bin
)
install(TARGETS rc_tool
    DESTINATION bin
)
install(TARGETS dma_tool
    DESTINATION bin
)
