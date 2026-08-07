//
//  QnScalePlugin.m
//  Copy to ios/Runner/QnScalePlugin.m
//
//  Bridge between the Qingniu scale SDK and Flutter.
//
//  Channel names and event shapes match the Android bridge exactly,
//  so the Dart side does not care which platform it is running on.
//
//  Fails soft throughout: a scale that misbehaves sends an error
//  event, never an exception across the channel.
//

#import "QnScalePlugin.h"
#import <QNSDK/QNDeviceSDK.h>

@interface QnScalePlugin () <FlutterStreamHandler,
                             QNBleDeviceDiscoveryListener,
                             QNBleConnectionChangeListener,
                             QNScaleDataListener>

@property (nonatomic, strong) FlutterEventSink eventSink;
@property (nonatomic, strong) NSMutableDictionary<NSString *, QNBleDevice *> *devices;
@property (nonatomic, strong) QNBleDevice *currentDevice;
@property (nonatomic, strong) QNUser *user;

@end

@implementation QnScalePlugin

// Held so the instance survives registration — the channels keep only
// weak references to their handlers.
static QnScalePlugin *sharedPlugin = nil;

+ (void)registerWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    QnScalePlugin *instance = [[QnScalePlugin alloc] init];
    sharedPlugin = instance;
    instance.devices = [NSMutableDictionary dictionary];

    FlutterMethodChannel *method =
        [FlutterMethodChannel methodChannelWithName:@"bmh/qn_scale"
                                    binaryMessenger:messenger];
    [method setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
        [instance handleMethodCall:call result:result];
    }];

    FlutterEventChannel *events =
        [FlutterEventChannel eventChannelWithName:@"bmh/qn_scale_events"
                                  binaryMessenger:messenger];
    [events setStreamHandler:instance];
}

#pragma mark - Events

- (FlutterError *)onListenWithArguments:(id)arguments
                              eventSink:(FlutterEventSink)events {
    self.eventSink = events;
    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

- (void)send:(NSDictionary *)payload {
    // Sinks must be touched on the main thread; SDK callbacks make no
    // promises about which thread they arrive on.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.eventSink) self.eventSink(payload);
    });
}

- (void)sendError:(NSString *)message {
    [self send:@{@"event": @"error", @"message": message ?: @"Unknown error"}];
}

#pragma mark - Methods

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSDictionary *args = [call.arguments isKindOfClass:[NSDictionary class]]
        ? call.arguments : @{};

    if ([call.method isEqualToString:@"init"]) {
        [self initSdk:args result:result];
    } else if ([call.method isEqualToString:@"startScan"]) {
        [self startScan:result];
    } else if ([call.method isEqualToString:@"stopScan"]) {
        [self stopScan:result];
    } else if ([call.method isEqualToString:@"connect"]) {
        [self connect:args result:result];
    } else if ([call.method isEqualToString:@"disconnect"]) {
        [self disconnect:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)initSdk:(NSDictionary *)args result:(FlutterResult)result {
    NSString *appId = args[@"appId"] ?: @"123456789";
    NSString *resource = args[@"configIos"] ?: @"123456789";

    NSString *file = [[NSBundle mainBundle] pathForResource:resource ofType:@"qn"];
    if (file == nil) {
        // Almost always means the .qn file is in the folder but not
        // ticked for the Runner target, so it never reached the bundle.
        [self sendError:[NSString stringWithFormat:
            @"Config file %@.qn is not in the app bundle.", resource]];
        result(@(NO));
        return;
    }

    [[QNBleApi sharedBleApi] initSdk:appId
                       firstDataFile:file
                            callback:^(NSError *error) {
        if (error) {
            [self sendError:[NSString stringWithFormat:
                @"SDK init failed: %@", error.localizedDescription]];
            result(@(NO));
        } else {
            result(@(YES));
        }
    }];
}

- (void)startScan:(FlutterResult)result {
    // Assigned as a property. The documentation describes
    // setBleDeviceDiscoveryListener:, which is the Android API — the
    // iOS SDK exposes these as weak properties instead.
    [QNBleApi sharedBleApi].discoveryListener = self;
    [[QNBleApi sharedBleApi] startBleDeviceDiscovery:^(NSError *error) {
        if (error) {
            [self sendError:[NSString stringWithFormat:
                @"Scan failed: %@", error.localizedDescription]];
        }
    }];
    result(@(YES));
}

- (void)stopScan:(FlutterResult)result {
    // "Discorvery" is spelled that way in the SDK header. Not a typo
    // here — correcting it does not compile.
    [[QNBleApi sharedBleApi] stopBleDeviceDiscorvery:^(NSError *error) {}];
    result(@(YES));
}

- (void)connect:(NSDictionary *)args result:(FlutterResult)result {
    NSString *mac = args[@"mac"];
    if (mac.length == 0) { result(@(NO)); return; }

    // iOS gives no MAC address for a peripheral, so a device cannot be
    // rebuilt from a string the way it can on Android. The object from
    // discovery is kept and reused instead.
    QNBleDevice *device = self.devices[mac];
    if (device == nil) {
        [self sendError:@"That scale is no longer in range. Scan again."];
        result(@(NO));
        return;
    }
    self.currentDevice = device;

    NSString *userId = args[@"userId"] ?: @"bmh_local_user";
    NSString *gender = args[@"gender"] ?: @"male";
    int height = [args[@"height"] intValue] ?: 170;
    NSString *birthdayStr = args[@"birthday"] ?: @"1990-01-01";

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    NSDate *birthday = [formatter dateFromString:birthdayStr] ?: [NSDate date];

    self.user = [[QNBleApi sharedBleApi] buildUser:userId
                                            height:height
                                            gender:gender
                                          birthday:birthday
                                          callback:^(NSError *error) {
        if (error) {
            [self sendError:[NSString stringWithFormat:
                @"User: %@", error.localizedDescription]];
        }
    }];

    [QNBleApi sharedBleApi].connectionChangeListener = self;
    [QNBleApi sharedBleApi].dataListener = self;

    [[QNBleApi sharedBleApi] connectDevice:device
                                      user:self.user
                                  callback:^(NSError *error) {
        if (error) {
            [self sendError:[NSString stringWithFormat:
                @"Connect: %@", error.localizedDescription]];
        }
    }];
    result(@(YES));
}

- (void)disconnect:(FlutterResult)result {
    if (self.currentDevice) {
        [[QNBleApi sharedBleApi] disconnectDevice:self.currentDevice
                                         callback:^(NSError *error) {}];
    }
    self.currentDevice = nil;
    result(@(YES));
}

#pragma mark - Discovery

- (void)onDeviceDiscover:(QNBleDevice *)device {
    if (device == nil || device.mac == nil) return;
    self.devices[device.mac] = device;
    [self send:@{
        @"event": @"device",
        @"mac": device.mac ?: @"",
        @"name": device.name ?: @"Scale",
        @"rssi": device.RSSI ?: @(0),
        @"modelId": device.modeId ?: @"",
    }];
}

- (void)onStartScan {}
- (void)onStopScan {}

#pragma mark - Connection

- (void)onConnecting:(QNBleDevice *)device {
    [self send:@{@"event": @"connection", @"state": @"connecting"}];
}

- (void)onConnected:(QNBleDevice *)device {
    [self send:@{@"event": @"connection", @"state": @"connected"}];
}

- (void)onDisconnecting:(QNBleDevice *)device {}

- (void)onDisconnected:(QNBleDevice *)device {
    [self send:@{@"event": @"connection", @"state": @"disconnected"}];
}

- (void)onConnectError:(QNBleDevice *)device error:(NSError *)error {
    [self sendError:[NSString stringWithFormat:
        @"Connection error: %@", error.localizedDescription]];
}

- (void)onServiceSearchComplete:(QNBleDevice *)device {}

#pragma mark - Data

// Weight while the person is still settling. Streamed for the live
// display only, never stored — a moving number is not a measurement.
- (void)onGetUnsteadyWeight:(QNBleDevice *)device weight:(double)weight {
    [self send:@{@"event": @"weighing", @"weight": @(weight)}];
}

- (void)onGetScaleData:(QNBleDevice *)device data:(QNScaleData *)scaleData {
    NSMutableArray *items = [NSMutableArray array];
    for (QNScaleItemData *item in [scaleData getAllItem]) {
        [items addObject:@{
            @"type": @(item.type),
            @"name": item.name ?: @"",
            @"value": @(item.value),
            @"valueType": @(item.valueType),
        }];
    }

    double weight = 0;
    QNScaleItemData *weightItem = [scaleData getItem:QNScaleTypeWeight];
    if (weightItem) weight = weightItem.value;

    [self send:@{
        @"event": @"measurement",
        @"weight": @(weight),
        @"measureTime": @([scaleData.measureTime timeIntervalSince1970] * 1000),
        @"hmac": scaleData.hmac ?: @"",
        @"items": items,
    }];
}

- (void)onGetStoredScale:(QNBleDevice *)device data:(NSArray *)storedDataList {}

- (void)onGetElectric:(NSUInteger)electric device:(QNBleDevice *)device {}

- (void)onScaleStateChange:(QNBleDevice *)device
                scaleState:(QNScaleState)state {
    // Surfaced so the UI can say "measuring body composition" rather
    // than sitting on a spinner. Bioimpedance only reads with bare
    // feet, which is why the app says so before you step on.
    if (state == QNScaleStateBodyFat) {
        [self send:@{@"event": @"connection", @"state": @"measuring"}];
    }
}

- (void)onScaleEventChange:(QNBleDevice *)device
                scaleEvent:(QNScaleEvent)scaleEvent {}

@end
