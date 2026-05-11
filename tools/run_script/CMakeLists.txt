#

find_package(Threads REQUIRED)

add_executable(test_slowcontrol test_slowcontrol.cpp)
add_executable(sc_tool sc_tool.cpp)
add_executable(rc_tool rc_tool.cpp)
add_executable(dma_tool dma_tool.cpp)

target_link_libraries(test_slowcontrol libmudaq)
target_link_libraries(sc_tool libmudaq)
target_link_libraries(rc_tool libmudaq)
target_include_directories(dma_tool PRIVATE
    ${INCMUDAQ_DIR}
    ${INCMUDAQ_DIR}/generated
)
target_link_libraries(dma_tool PRIVATE Threads::Threads)

install(TARGETS test_slowcontrol
    DESTINATION bin
)
install(TARGETS sc_tool
    DESTINATION bin
)
install(TARGETS rc_tool
    DESTINATION bin
)
install(TARGETS dma_tool
    DESTINATION bin
)
