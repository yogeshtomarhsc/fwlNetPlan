#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <getopt.h>
#include <string.h>

#include "opencv2/imgproc.hpp"
#include "opencv2/highgui.hpp"
#include "opencv2/videoio.hpp"

#include <iostream>

using namespace cv;

const int max_value = 255;

const String window_capture_name = "Image Capture";
const String window_detection_name = "Pixel Detection";

int low_R = 0, low_G = 0, low_B = 0;
int high_R = max_value, high_G = max_value, high_B = max_value;

int countPixels(Mat frame,int coloured) ;
int convertWhiteToBlack(Mat frame) ;
int makeRanges(uint32_t colour, int *lowR, int *highR, int *lowG, int *highG, int *lowB, int *highB, int var) ;
uint32_t rgbToInt(char *) ;

uint32_t qam16 = 0xffff00, qam64=0xff0000, qam256=0x0000ff ;
int main(int argc, char* argv[])
{
	int notExit = 1 ;
	char imageName[1024] ;
	char ch ;
	extern char *optarg ;
	int option_index = 0;
	bzero(imageName,1024*sizeof(char)) ;
	int variation = 10;

	static struct option long_options[] = {
                   {"qam16",    required_argument, 0,  4 },
                   {"qam64",  	required_argument, 0,  6 },
                   {"qam256",  required_argument, 0,  8 },
                   {"var",  required_argument, 0,  'v' },
                   {0,         0,                 0,  0 }
	};
	while ((ch = getopt_long(argc, argv, "f:", long_options, &option_index)) != -1)
	{
               switch (ch) {
		case 'f': strncpy(imageName,optarg,1023) ; break ;
		case 'v': variation = atoi(optarg) ; break ;
               	case 4: qam16 = rgbToInt(optarg) ; break ;
               	case 6: qam64 = rgbToInt(optarg) ; break ;
               	case 8: qam256 = rgbToInt(optarg) ; break ;
               default: printf("?? getopt returned character code 0%o ??\n", ch);
               }
	}
	printf("16QAM:%x 64QAM:%x 256QAM:%x\n",qam16,qam64,qam256) ;



           if (optind < argc) {

               printf("non-option ARGV-elements: ");

               while (optind < argc)

                   printf("%s ", argv[optind++]);

               printf("\n");

           }
    
	namedWindow(window_detection_name);
    Mat frame, frame_RGB, frame_threshold;
	if (strlen(imageName) == 0) {
		fprintf(stderr,"Need an image name\n" ) ;
		exit(1) ;
	}
	struct stat fbuf ;
	if (stat(imageName,&fbuf) != 0) {
		fprintf(stderr,"Couldn't stat %s:\n",imageName) ;
		perror("File stat error:\n") ;
		exit(2) ;
	}
	frame = imread(imageName) ;
    {

        // Convert from BGR to HSV colorspace

        //cvtColor(frame, frame_HSV, COLOR_BGR2HSV);

        // Detect the object based on HSV Range Values

	//    low_B = 240; high_B = 255 ; low_G = 240; high_G = 255 ; low_R = 240; high_R = 255 ;
        //inRange(frame, Scalar(low_B, low_G, low_R), Scalar(high_B, high_G, high_R), frame_threshold);
	int coloured = convertWhiteToBlack(frame) ;
	printf("Counted %d coloured\n", coloured) ;
	    // First 16qam.
	printf("QAM 16:\n") ;
	makeRanges(qam16,&low_R, &high_R, &low_G, & high_G, &low_B, &high_B,variation) ;
//	    low_B = 0; high_B = 1 ; low_G = 0; high_G = 1 ; low_R = 0; high_R = 255 ;
        inRange(frame, Scalar(low_B, low_G, low_R), Scalar(high_B, high_G, high_R), frame_threshold);
        imshow(window_detection_name, frame_threshold);
	countPixels(frame_threshold,coloured) ;
	waitKey(5000) ;
		// Then Blue
	printf("QAM 64:\n") ;
	makeRanges(qam64,&low_R, &high_R, &low_G, & high_G, &low_B, &high_B,variation) ;
//	    low_B = 128; high_B = 255 ; low_G = 0; high_G = 1 ; low_R = 0; high_R = 1 ;
        inRange(frame, Scalar(low_B, low_G, low_R), Scalar(high_B, high_G, high_R), frame_threshold);
        imshow(window_detection_name, frame_threshold);
	countPixels(frame_threshold,coloured) ;
	waitKey(5000) ;
		// Then Yellow
	printf("QAM 256:\n") ;
	makeRanges(qam256,&low_R, &high_R, &low_G, & high_G, &low_B, &high_B,variation) ;
//	    low_B = 0; high_B = 255 ; low_G = 240; high_G = 255 ; low_R = 240; high_R = 255 ;
        inRange(frame, Scalar(low_B, low_G, low_R), Scalar(high_B, high_G, high_R), frame_threshold);
	countPixels(frame_threshold,coloured) ;
        imshow(window_detection_name, frame_threshold);

        // Show the frames

//        imshow(window_capture_name, frame);
        //imshow(window_detection_name, frame_threshold);

        char key = (char) waitKey(-1);

        if (key == 'q' || key == 27)

        {

            exit(3);

        }

    }

    return 0;

}

int makeRanges( uint32_t col,
		int *lowR, int *highR,
		int *lowG, int *highG,
		int *lowB, int *highB,
		int var)
{
	*lowR = (col>>16 & 0xff) - var/2 ; if (*lowR < 0) *lowR = 0 ;
	*highR = (col>>16 & 0xff) + var/2 ; if (*highR > 255) *highR = 255 ;
	*lowG = (col>>8 & 0xff) - var/2 ; if (*lowG < 0) *lowG = 0 ;
	*highG = (col>>8 & 0xff) + var/2 ; if (*highG > 255) *highG = 255 ;
	*lowB = (col & 0xff) - var/2 ; if (*lowB < 0) *lowB = 0 ;
	*highB = (col & 0xff) + var/2 ; if (*highB > 255) *highB = 255 ;
	printf ("Range: Red: %d to %d, Green: %d to %d, Blue:%d to %d\n",
			*lowR, *highR,
			*lowG, *highG,
			*lowB, *highB) ;
}

typedef cv::Point3_<uint8_t> Pixel;
int convertWhiteToBlack(Mat frame)
{
	int coloured = 0 ;
	int rows=frame.rows ;
	int cols=frame.cols ;
	int dim = rows*cols ;
	printf("Dimension:rows=%d coluns=%d pixels=%d\n",frame.rows, frame.cols,dim) ;
	for (int r = 0; r < frame.rows; ++r) {
    		Pixel* ptr = frame.ptr<Pixel>(r, 0);
    		const Pixel* ptr_end = ptr + frame.cols;
    		for (; ptr != ptr_end; ++ptr) {
			if (ptr->x == 255 & ptr->y == 255 && ptr->z == 255) 
			{
				ptr->x = 0 ;
				ptr->y = 255 ;
				ptr->z = 0;
			}
			else
				coloured++ ;
    		}
	}
	printf("convertWhiteToBlack:coloured=%d\n",coloured) ;
	return coloured ;
}
int countPixels(Mat frame,int coloured)
{
	int white = 0 ;
	int rows=frame.rows ;
	int cols=frame.cols ;
	int dim = rows*cols ;
	printf("Dimension:rows=%d coluns=%d\n",frame.rows, frame.cols) ;
	printf("Number of channels:%d depth=%d, ",frame.channels(),frame.depth()) ;
	// first. raw pointer access.
#if 1
	for (int r = 0; r < frame.rows; ++r) {
    		uint8_t * ptr = frame.ptr<uint8_t>(r, 0);
    		const uint8_t* ptr_end = ptr + frame.cols;
    		for (; ptr != ptr_end; ++ptr) {
			if (*ptr != 0) 
				white++ ;
    		}
	}
	double pct = (double)(100*white)/(double)(coloured) ; 
	printf("white=%d dim=%d pct=%.3g%%\n",white,coloured,pct) ;
	return white ;
#endif
}

uint32_t rgbToInt(char *rgbname)
{
	uint32_t col ;
	int red,green,blue ;
	char *tok ;
	printf("%s returns ",rgbname) ;
	tok = strtok(rgbname,",") ; red = atoi(tok) ;
	tok = strtok(NULL,",") ; green = atoi(tok) ;
	tok = strtok(NULL,",\n") ; blue = atoi(tok);
	printf("%x,%x,%x\n",red,green,blue) ;
	return (red<<16 | green<<8 | blue) ;
}
