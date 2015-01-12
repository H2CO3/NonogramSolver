CXX = clang++
LD = $(CXX)

CXXFLAGS = -std=c++11 -c -pedantic -Wall -Wshadow -Wnull-conversion -Wnon-literal-null-conversion -Wconversion-null -O0 -g -fobjc-arc
LDFLAGS = -O0 -g -lgecodeint -lgecodekernel -lgecodesearch -lgecodesupport -lgecodeminimodel -lobjc -framework Foundation -framework AppKit -framework QuartzCore

OBJECTS  = $(patsubst %.mm, %.o, $(wildcard *.mm))
OBJECTS += $(patsubst %.cpp, %.o, $(wildcard *.cpp))

APP_DIR = NonogramSolver.app
TARGET = $(APP_DIR)/Contents/MacOS/NonogramSolver

$(TARGET): $(OBJECTS)
	$(LD) $(LDFLAGS) -o $@ $^

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

%.o: %.mm
	$(CXX) $(CXXFLAGS) -o $@ $<

all: $(TARGET)

clean:
	rm -f $(OBJECTS) $(TARGET)

run:
	open $(APP_DIR)

.PHONY: all clean run
