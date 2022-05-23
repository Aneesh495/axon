cmake_minimum_required(VERSION 3.16)
project(axon_runtime CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -Wall -Wextra -pthread")

include_directories(include)

add_executable(axon-runtime
    src/main.cpp
    src/lexer.cpp
    src/parser.cpp
    src/typechecker.cpp
    src/interpreter.cpp
    src/stdlib.cpp
)
