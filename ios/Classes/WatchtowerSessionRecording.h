#import <Flutter/Flutter.h>

@interface WatchtowerSessionRecording : NSObject<FlutterStreamHandler>
- (void)startRecorder:(NSInteger)interval;
@end
