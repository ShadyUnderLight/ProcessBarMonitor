import Foundation
import CSensors

struct AppleSiliconTemperatureProvider {
    private let page: Int32 = 0xff00
    private let usage: Int32 = 0x0005
    private let eventType: Int32 = kIOHIDEventTypeTemperature

    func temperature(mode: TemperatureMode) -> Double? {
        #if arch(arm64)
        guard let unmanaged = AppleSiliconTemperatureSensors(page, usage, eventType) else {
            return nil
        }

        let sensors = unmanaged.takeRetainedValue() as NSDictionary
        var cpuValues: [Double] = []
        var socValues: [Double] = []
        var fallbackValues: [Double] = []

        for (rawKey, rawValue) in sensors {
            guard let key = rawKey as? String,
                  let value = rawValue as? Double,
                  value > 1,
                  value < 120 else {
                continue
            }

            if key.hasPrefix("pACC") || key.hasPrefix("eACC") {
                cpuValues.append(value)
            }
            if key.hasPrefix("SOC MTR Temp") || key.contains("SOC Die") {
                socValues.append(value)
            }
            if key.contains("CPU") || key.contains("Die") || key.contains("PMU tdie") {
                fallbackValues.append(value)
            }
        }

        switch mode {
        case .hottestCPU:
            return cpuValues.max() ?? fallbackValues.max() ?? socValues.max()
        case .averageCPU:
            if !cpuValues.isEmpty { return cpuValues.reduce(0, +) / Double(cpuValues.count) }
            if !fallbackValues.isEmpty { return fallbackValues.reduce(0, +) / Double(fallbackValues.count) }
            return socValues.isEmpty ? nil : socValues.reduce(0, +) / Double(socValues.count)
        case .hottestSoC:
            return socValues.max() ?? cpuValues.max() ?? fallbackValues.max()
        }
        #else
        return nil
        #endif
    }
}
