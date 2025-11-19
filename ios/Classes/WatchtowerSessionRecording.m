#import "WatchtowerSessionRecording.h"
#import <Flutter/Flutter.h>

@interface WatchtowerSessionRecording()
@property (nonatomic, assign) BOOL isForeground;
@property (nonatomic, copy) FlutterEventSink eventSink;
@end

@implementation WatchtowerSessionRecording

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    self.eventSink = events;
    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

- (void)startRec:(NSInteger)interval {
    NSTimeInterval timeInterval = (NSTimeInterval)interval / 1000.0;
    UIApplication *app = [UIApplication sharedApplication];
    UIViewController *rootController = app.delegate.window.rootViewController;
    self.isForeground = [self checkAppState];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (true) {
            if (self.isForeground && self.eventSink != nil) {
                @autoreleasepool {
                    UIImage *screenshot = [self takeScreenshot:rootController.view];
                    UIImage *compressedScreenshot = [self СompressScreenshot:screenshot];
                    
                    NSData *imageData = UIImagePNGRepresentation(compressedScreenshot);
                    
                    FlutterStandardTypedData *typedData = [FlutterStandardTypedData typedDataWithBytes:imageData];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.eventSink != nil) {
                            self.eventSink(typedData);
                        }
                    });
                }
            }
            [NSThread sleepForTimeInterval:timeInterval];
        }
    });
}

- (BOOL)checkAppState {
    UIApplication *app = [UIApplication sharedApplication];
    if (app.applicationState == UIApplicationStateActive) {
        return YES;
    }
    return NO;
}

- (UIImage *)takeScreenshot:(UIView *)view {
    CGFloat scale = UIScreen.mainScreen.scale;
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, scale);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:NO];
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return screenshot;
}

- (UIImage *)СompressScreenshot:(UIImage *)screenshotOriginal {
    CGFloat sizeRatio = screenshotOriginal.size.width / screenshotOriginal.size.height;
    CGImageRef imageRef = [screenshotOriginal CGImage];
    NSUInteger resolution = 640;
    NSUInteger height = resolution;
    NSUInteger width = (NSUInteger)(resolution * sizeRatio);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char* rawData = (unsigned char*)calloc(height * width * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGImageRef imageFromPixelsRef = CGBitmapContextCreateImage(context);
    UIImage *imageFromPixels = [UIImage imageWithCGImage:imageFromPixelsRef];
    CGImageRelease(imageFromPixelsRef);
    CGContextRelease(context);
    free(rawData);
    return imageFromPixels;
}

- (void)startRecorder:(NSInteger)interval {
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(applicationDidEnterBackgroud) 
                                                 name:UIApplicationDidEnterBackgroundNotification 
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(applicationWillEnterForeground) 
                                                 name:UIApplicationWillEnterForegroundNotification 
                                               object:nil];
    [self startRec:interval];
}

- (void)applicationDidEnterBackgroud {
    self.isForeground = NO;
}

- (void)applicationWillEnterForeground {
    self.isForeground = YES;
}

@end
