#import <Foundation/Foundation.h>
#import "bridge.h"

CFDictionaryRef AppleSiliconTemperatureSensors(int32_t page, int32_t usage, int32_t type) {
    NSDictionary *dictionary = @{ @"PrimaryUsagePage": @(page), @"PrimaryUsage": @(usage) };

    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (system == nil) {
        return NULL;
    }

    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)dictionary);
    CFArrayRef services = IOHIDEventSystemClientCopyServices(system);
    if (services == nil) {
        CFRelease(system);
        return NULL;
    }

    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    for (CFIndex i = 0; i < CFArrayGetCount(services); i++) {
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        NSString *name = CFBridgingRelease(IOHIDServiceClientCopyProperty(service, CFSTR("Product")));
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, type, 0, 0);
        if (name != nil && event != nil) {
            double value = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(type));
            result[name] = @(value);
        }
        if (event != nil) {
            CFRelease(event);
        }
    }

    CFRelease(services);
    CFRelease(system);
    return CFBridgingRetain(result);
}
