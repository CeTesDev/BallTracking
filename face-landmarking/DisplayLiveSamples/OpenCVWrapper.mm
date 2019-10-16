//
//  OpenCVWrapper.m
//  palmRecognition
//
//  Created by mojado on 6/19/19.
//  Copyright © 2019 andrew. All rights reserved.
//

#ifdef __cplusplus
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"

#import <opencv2/opencv.hpp>
#import "OpenCVWrapper.h"

#pragma clang pop
#endif

using namespace std;
using namespace cv;

#pragma mark - Private Declarations

@interface OpenCVWrapper ()

#ifdef __cplusplus

+ (Mat)_grayFrom:(Mat)source;
+ (Mat)_matFrom:(UIImage *)source;
+ (UIImage *)_imageFrom:(Mat)source;
+ (float) _distanceToCamera:(float)knownWidth withFocalLength:(float)focalLenght withPixels:(float)pixels;
+ (cv::Scalar)_colorLower:(int)colorType;
+ (cv::Scalar)_colorUpper:(int)colorType;

#endif

@end

#pragma mark - OpenCVWrapper
@implementation OpenCVWrapper {
    std::vector<Point2i> pts;
}


#pragma mark Public

+ (UIImage *)toGray:(UIImage *)source {
    cout << "OpenCV: ";
    return [OpenCVWrapper _imageFrom:[OpenCVWrapper _grayFrom:[OpenCVWrapper _matFrom:source]]];
}


#pragma mark Private

+ (Mat)_grayFrom:(Mat)source {
    cout << "-> grayFrom ->";
    
    Mat result;
    cvtColor(source, result, CV_BGR2GRAY);
    
    return result;
}

- (void)doWorkOnSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
    // MARK: magic
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    
    CGFloat width = CVPixelBufferGetWidth(pixelBuffer);
    CGFloat height = CVPixelBufferGetHeight(pixelBuffer);
    CGFloat byPerRosw = CVPixelBufferGetBytesPerRow(pixelBuffer);
    void *baseAddress = CVPixelBufferGetBaseAddress( pixelBuffer );
    

    cv::Mat frame(height, width, CV_8UC4, baseAddress, 0);
    
    CGFloat ratio = 600 / width;
    
    // resize the frame, blur it, and convert it to the HSV
    // color space
    cv::Mat resized;
    cv::resize(frame, resized, cv::Size(ratio * width, ratio * height));
    cv::Mat blured;
    cv::GaussianBlur(resized, blured, cv::Size(11,11), 0);
    cv::Mat hsv;
    cv::cvtColor(blured, hsv, CV_BGR2HSV);

    int colorType = 0;//0: green, 1:yello, others: white
    cv::Scalar colorLower = [OpenCVWrapper _colorLower:colorType];
    cv::Scalar colorUpper = [OpenCVWrapper _colorUpper:colorType];
   
    // construct a mask for the color "green", then perform
    // a series of dilations and erosions to remove any small
    // blobs left in the mask
    cv::Mat mask;
    cv::inRange(hsv, colorLower, colorUpper, mask);
    
    cv::Mat kernel = cv::Mat::ones(3, 3, CV_8U);
    
    cv::erode(mask, mask, kernel);
    cv::dilate(mask, mask, kernel);
    
    // find contours in the mask and initialize the current
    // (x, y) center of the ball
    
    std::vector<std::vector<cv::Point> > contours;
    std::vector<cv::Vec4i> hierarchy;
    cv::findContours(mask, contours, hierarchy, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    
    Point2f center_temp;
    Point2i center;
    float radius;
    
    // only proceed if at least one contour was found
    if(contours.size() > 0)
    {
    // find the largest contour in the mask, then use
    // it to compute the minimum enclosing circle and
    // centroid
        double max_area = 0;
        int max_index = 0;
        for(int i = 0; i < contours.size(); i++)
        {
            double conArea = cv::contourArea(contours.at(i));
            if(conArea > max_area)
            {
                max_index = i;
                max_area = conArea;
            }
        }
        
        std::vector<cv::Point> c = contours.at(max_index);

        cv::minEnclosingCircle(c, center_temp, radius);
        cv::Moments m = cv::moments(c);
        center = Point2i(int((m.m10 / m.m00)/ratio), int((m.m01 / m.m00)/ratio));
        
        // only proceed if the radius meets a minimum size
        if(radius > 10)
        {
            // draw the circle and centroid on the frame,
            // then update the list of tracked points
            cv::circle(frame, center, radius/ratio, cv::Scalar(0,255,255),2);
            cv::circle(frame, center, 5, cv::Scalar(0, 0, 255), -1);
            
            float distance = [OpenCVWrapper _distanceToCamera:42.67 withFocalLength:1734.24 withPixels:2*radius/ratio];
            std::string s = "distance:" + std::to_string((int)distance) + "mm";
            cv::putText(frame, s.c_str(), cv::Point(30,width/2-10), FONT_HERSHEY_SCRIPT_SIMPLEX, 2, cv::Scalar(0,0,255));
            
            // update the points queue
            pts.insert(pts.begin(), center);
            int max_count = 60;
            if(pts.size() > max_count)
                pts.pop_back();
            
            // loop over the set of tracked points
            for(int i = 1; i< pts.size(); i++)
            {
                int thickness = int(std::sqrt(max_count / float(i + 1)) * 2.5);
                cv::line(frame, pts.at(i-1), pts.at(i), cv::Scalar(0,0,255), thickness);
            }

        }
    }
    else
        pts.clear();
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

}

+ (float) _distanceToCamera:(float)knownWidth withFocalLength:(float)focalLenght withPixels:(float)pixels
{
    return (knownWidth * focalLenght)/pixels;
}

+ (cv::Scalar) _colorLower:(int)colorType
{
   
    cv::Scalar colorLower;
    if(colorType == 0)//green
        colorLower = cv::Scalar(29, 86, 6 );
    else if(colorType == 1)//yellow
        colorLower = cv::Scalar(20, 100, 100 );
    else //white
        colorLower = cv::Scalar(0, 0, 0 );
        
    return colorLower;
}

+ (cv::Scalar) _colorUpper:(int)colorType
{
   
    cv::Scalar colorUpper;
    
    if(colorType == 0)//green
        colorUpper = cv::Scalar(64, 255, 255 );
    else if(colorType == 1)//yellow
        colorUpper = cv::Scalar(30, 255, 255);
    else //white
        colorUpper = cv::Scalar(0, 0, 255 );
    
    return colorUpper;
}

+ (Mat)_matFrom:(UIImage *)source {
    cout << "matFrom ->";
    
    CGImageRef image = CGImageCreateCopy(source.CGImage);
    CGFloat cols = CGImageGetWidth(image);
    CGFloat rows = CGImageGetHeight(image);
    Mat result(rows, cols, CV_8UC4);
    
    CGBitmapInfo bitmapFlags = kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault;
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = result.step[0];
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image);
    
    CGContextRef context = CGBitmapContextCreate(result.data, cols, rows, bitsPerComponent, bytesPerRow, colorSpace, bitmapFlags);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, cols, rows), image);
    CGContextRelease(context);
    
    return result;
}

+ (UIImage *)_imageFrom:(Mat)source {
    cout << "-> imageFrom\n";
    
    NSData *data = [NSData dataWithBytes:source.data length:source.elemSize() * source.total()];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGBitmapInfo bitmapFlags = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = source.step[0];
    CGColorSpaceRef colorSpace = (source.elemSize() == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB());
    
    CGImageRef image = CGImageCreate(source.cols, source.rows, bitsPerComponent, bitsPerComponent * source.elemSize(), bytesPerRow, colorSpace, bitmapFlags, provider, NULL, false, kCGRenderingIntentDefault);
    UIImage *result = [UIImage imageWithCGImage:image];
    
    CGImageRelease(image);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return result;
}

@end
