//
//  MobyBLEThread.swift
//  ios-device-lib
//


import Foundation
import CoreFoundation

// MARK: - MobyBLEThread

/// Manages a dedicated, long-lived thread for all BLE operations.
///
/// All calls that enter `RUADeviceManager` / `LDBluetoothManager` **must** be
/// dispatched through `bleDispatch { }` (or `MobyBLEThread.dispatch { }`) to
/// ensure they run on the correct run-loop thread.
///
/// Conversion notes (ObjC → Swift):
///   - `dispatch_once`          → `static let shared` (thread-safe lazy init by the Swift runtime)
///   - `NSThread initWithBlock` → `Thread { }`
///   - `NSRunLoop`              → `RunLoop`
///   - `[NSMachPort port]`      → `Port()` (same underlying Mach port on iOS)
///   - `dispatch_semaphore_t`   → `DispatchSemaphore`
///   - `CFRunLoopWakeUp`        → `CFRunLoopWakeUp` (CoreFoundation is available directly in Swift)
final class MobyBLEThread {

    // MARK: - Singleton

    /// The single shared BLE thread. Created exactly once (thread-safe).
    private static let shared = MobyBLEThread()

    // MARK: - Private state

    private var bleThread: Thread?
    private var bleRunLoop: RunLoop?

    // MARK: - Init

    private init() {
        startBLEThread()
    }

    // MARK: - Thread bootstrap

    /// Creates and starts the dedicated BLE thread, then blocks until its
    /// `RunLoop` is ready to accept work (max 2 seconds).
    private func startBLEThread() {
        // Semaphore lets us wait until the new thread's run loop is running
        // before we allow any bleDispatch calls through.
        let ready = DispatchSemaphore(value: 0)

        let thread = Thread {
            autoreleasepool {
                let runLoop = RunLoop.current
                self.bleRunLoop = runLoop

                // A Mach port keeps the run loop alive when it has no other
                // active sources (equivalent to [runLoop addPort:[NSMachPort port]
                // forMode:NSDefaultRunLoopMode] in ObjC).
                runLoop.add(Port(), forMode: .default)

                // Signal that the run loop is ready before entering its infinite loop.
                ready.signal()

                // Runs forever — blocks this thread intentionally.
                runLoop.run()
            }
        }

        thread.name = "com.example.moby5500.ble"
        thread.qualityOfService = .userInitiated
        thread.start()
        self.bleThread = thread

        // Wait up to 2 s for the run loop to be ready (mirrors the ObjC
        // dispatch_semaphore_wait with 2 * NSEC_PER_SEC timeout).
        _ = ready.wait(timeout: .now() + 2)
    }

    // MARK: - Dispatch

    /// Schedules `block` on the BLE thread's run loop and immediately wakes
    /// it so the block executes without waiting for the next run-loop cycle.
    ///
    /// Equivalent to the ObjC:
    /// ```objc
    /// [sMobyBLERunLoop performBlock:block];
    /// CFRunLoopWakeUp([sMobyBLERunLoop getCFRunLoop]);
    /// ```
    static func dispatch(_ block: @escaping () -> Void) {
        let runLoop = shared.bleRunLoop
        runLoop?.perform(block)
        if let cfRunLoop = runLoop?.getCFRunLoop() {
            CFRunLoopWakeUp(cfRunLoop)
        }
    }
}

// MARK: - Free function

/// Convenience free function that mirrors the ObjC C function `bleDispatch()`.
///
/// All existing call sites in `IngenicoDeviceManager.swift` use this form:
/// ```swift
/// bleDispatch { [weak self] in … }
/// ```
/// which requires no changes after replacing the ObjC implementation with this file.
func bleDispatch(_ block: @escaping () -> Void) {
    MobyBLEThread.dispatch(block)
}
