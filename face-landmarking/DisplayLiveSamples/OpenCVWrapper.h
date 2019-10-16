//
//  OpenCVWrapper.h
//  palmRecognition
//
//  Created by mojado on 6/19/19.
//  Copyright © 2019 andrew. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#include <CoreVideo/CVPixelBuffer.h>
NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject
+ (UIImage *)toGray:(UIImage *)source;
- (void)doWorkOnSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

NS_ASSUME_NONNULL_END
