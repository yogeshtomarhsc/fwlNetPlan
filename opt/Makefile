CC=g++ -g
LD=g++ -g
SRCHOME=/home/ggne0015/src/
OPENCV_DIR=$(SRCHOME)/opencv-4.1.1
CFLAGS = -pthread -I/usr/local/include/opencv4/ -I$(OPENCV_DIR)/modules/core/include -I$(OPENCV_DIR)/build/  -I$(OPENCV_DIR)/modules/videoio/include
CPPFLAGS = -fpermissive $(CFLAGS) 


pixCount: pixCount.o
	$(LD) -o $@ pixCount.o -lopencv_world
