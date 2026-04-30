import Foundation
import IOKit.ps

struct PowerSourceProvider {
    func getPowerSourceInfo() -> PowerSourceInfo {
        guard let powerSourceInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let powerSourceList = IOPSCopyPowerSourcesList(powerSourceInfo)?.takeRetainedValue() as? [CFTypeRef],
              !powerSourceList.isEmpty else {
            return .unavailable
        }

        for source in powerSourceList {
            guard let description = IOPSGetPowerSourceDescription(powerSourceInfo, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let type = description[kIOPSTypeKey as String] as? String
            guard type == kIOPSInternalBatteryType as String else { continue }

            let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int ?? 100
            let isCharging = description[kIOPSIsChargingKey as String] as? Bool ?? false
            let isPluggedIn = description[kIOPSPowerSourceStateKey as String] as? String == kIOPSACPowerValue as String

            let batteryPercent = maxCapacity > 0 ? (Double(currentCapacity) / Double(maxCapacity)) * 100 : 0

            let timeRemaining: Int?
            if let secs = description[kIOPSTimeToEmptyKey as String] as? Int, secs > 0 {
                timeRemaining = secs
            } else if let secs = description[kIOPSTimeToFullChargeKey as String] as? Int, secs > 0 {
                timeRemaining = secs
            } else {
                timeRemaining = nil
            }

            let status: BatteryStatus
            if isCharging {
                status = .charging
            } else if batteryPercent >= 99 {
                status = .full
            } else {
                status = .discharging
            }

            return PowerSourceInfo(
                batteryPercent: batteryPercent,
                status: status,
                isPluggedIn: isPluggedIn,
                timeRemaining: timeRemaining,
                hasBattery: true
            )
        }

        return .unavailable
    }
}