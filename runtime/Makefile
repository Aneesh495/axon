CXX ?= clang++
CXXFLAGS = -std=c++20 -O3 -Wall -Wextra -pthread -Iinclude

SRCS = src/main.cpp src/lexer.cpp src/parser.cpp src/typechecker.cpp src/interpreter.cpp src/stdlib.cpp
OBJS = $(SRCS:.cpp=.o)
TARGET = ../bin/axon-runtime

all: $(TARGET)

$(TARGET): $(OBJS)
	@mkdir -p ../bin
	$(CXX) $(CXXFLAGS) -o $@ $(OBJS)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean
