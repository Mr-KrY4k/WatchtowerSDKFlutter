#import "WatchtowerPlugin.h"
#import "WatchtowerSessionRecording.h"

@interface WatchtowerPlugin()
@property (nonatomic, strong) FlutterMethodChannel *methodChannel;
@property (nonatomic, strong) FlutterEventChannel *eventChannel;
@property (nonatomic, strong) WatchtowerSessionRecording *screenRecording;
@end

@implementation WatchtowerPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    WatchtowerPlugin *instance = [[WatchtowerPlugin alloc] init];
    
    // Создаём MethodChannel
    instance.methodChannel = [FlutterMethodChannel
        methodChannelWithName:@"com.watchtower.plugin/screen_recording"
              binaryMessenger:[registrar messenger]];
    [registrar addMethodCallDelegate:instance channel:instance.methodChannel];
    
    // Создаём EventChannel
    instance.eventChannel = [FlutterEventChannel
        eventChannelWithName:@"com.watchtower.plugin/screen_recording_stream"
             binaryMessenger:[registrar messenger]];
    [instance.eventChannel setStreamHandler:instance.screenRecording];
    
    // Создаём экземпляр записи экрана
    instance.screenRecording = [[WatchtowerSessionRecording alloc] init];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([@"startRecorder" isEqualToString:call.method]) {
        NSNumber *interval = call.arguments[@"interval"];
        if (interval != nil) {
            [self.screenRecording startRecorder:[interval integerValue]];
            result(nil);
        } else {
            result([FlutterError errorWithCode:@"INVALID_ARGUMENT"
                                       message:@"Interval is required"
                                       details:nil]);
        }
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end
