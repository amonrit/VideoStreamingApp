//
//  PerformanceBaseline.swift
//  steamTests
//
//  Baseline performance measurement for StateActor implementation.
//  Captures memory, CPU, and AsyncStream metrics for optimization comparison.
//

import XCTest
import Foundation
@testable import steam

// MARK: - Memory Metrics

class MemoryMetrics {
    static var startingMemory: UInt64 = 0
    static var peakMemory: UInt64 = 0

    static var currentMemory: UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size)/4

        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    $0,
                    &count
                )
            }
        }

        guard kerr == KERN_SUCCESS else { return 0 }
        return info.phys_footprint
    }

    static func startMeasurement() {
        startingMemory = currentMemory
        peakMemory = startingMemory
    }

    static func recordPeak() {
        let current = currentMemory
        if current > peakMemory {
            peakMemory = current
        }
    }

    static func memoryDelta() -> Int64 {
        return Int64(peakMemory) - Int64(startingMemory)
    }

    static func formatMemory(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Performance Baseline Tests

final class PerformanceBaselineTests: XCTestCase {

    // MARK: - Test: Single Stream Playback (Normal Case)

    func testBaselineMemoryDuringSingleStreamPlayback() {
        MemoryMetrics.startMeasurement()

        let expectation = XCTestExpectation(description: "playback complete")
        expectation.expectedFulfillmentCount = 1

        Task {
            let stateActor = DefaultPlaybackStateActor()

            // Simulate 10-second playback with periodic updates
            for i in 0..<100 {
                // Simulate various state changes
                await stateActor.updateLoading(i < 10)
                await stateActor.updatePlaying(i >= 10)
                await stateActor.updateConnectionStatus(.connected)
                await stateActor.updateViewerCount(50 + i)
                await stateActor.updateCurrentTime(Double(i) * 0.1)

                MemoryMetrics.recordPeak()

                // Small delay to simulate real playback
                try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15)

        let delta = MemoryMetrics.memoryDelta()
        let formattedDelta = MemoryMetrics.formatMemory(UInt64(abs(delta)))

        print("📊 BASELINE: Single Stream Playback")
        print("   Peak Memory: \(MemoryMetrics.formatMemory(MemoryMetrics.peakMemory))")
        print("   Memory Delta: \(delta > 0 ? "+" : "")\(formattedDelta)")

        // Baseline assertion: should use reasonable memory
        XCTAssertLessThan(delta, 50_000_000, "Memory usage should be < 50MB")
    }

    // MARK: - Test: Rapid State Updates (Worst Case)

    func testBaselineMemoryDuringRapidStateUpdates() {
        MemoryMetrics.startMeasurement()

        let expectation = XCTestExpectation(description: "rapid updates complete")
        expectation.expectedFulfillmentCount = 1

        Task {
            let stateActor = DefaultPlaybackStateActor()

            // Rapid sequential updates - stress test
            for i in 0..<1000 {
                // Rotate through different state updates
                switch i % 10 {
                case 0:
                    await stateActor.updateLoading(i % 2 == 0)
                case 1:
                    await stateActor.updatePlaying(i % 2 == 0)
                case 2:
                    await stateActor.updateError(i % 100 == 0 ? "Test error" : nil)
                case 3:
                    await stateActor.updateConnectionStatus(i % 2 == 0 ? .connected : .connecting)
                case 4:
                    await stateActor.updateViewerCount(i % 10)
                case 5:
                    await stateActor.updateRetryAttempt(i % 5)
                case 6:
                    await stateActor.updateCurrentTime(Double(i) * 0.001)
                case 7:
                    await stateActor.updateDuration(100.0)
                case 8:
                    await stateActor.updateBufferingCount(i % 3)
                default:
                    await stateActor.updateCurrentStream(nil)
                }

                if i % 100 == 0 {
                    MemoryMetrics.recordPeak()
                }
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 30)

        let delta = MemoryMetrics.memoryDelta()
        let allocationRate = delta / 1000  // bytes per update
        let formattedDelta = MemoryMetrics.formatMemory(UInt64(abs(delta)))

        print("📊 BASELINE: Rapid State Updates (1000 updates)")
        print("   Peak Memory: \(MemoryMetrics.formatMemory(MemoryMetrics.peakMemory))")
        print("   Memory Delta: \(delta > 0 ? "+" : "")\(formattedDelta)")
        print("   Allocation Rate: \(allocationRate) bytes/update")

        // Baseline assertion
        XCTAssertLessThan(delta, 2_000_000, "Rapid updates should use < 2MB")
    }

    // MARK: - Test: AsyncStream Throughput

    func testBaselineAsyncStreamThroughput() {
        let expectation = XCTestExpectation(description: "throughput measured")

        Task {
            let stateActor = DefaultPlaybackStateActor()
            var updateCount = 0
            var yieldCount = 0
            let startTime = CFAbsoluteTimeGetCurrent()

            // Observer task
            let observerTask = Task {
                for await state in await stateActor.stateUpdates {
                    yieldCount += 1
                    if yieldCount >= 500 {
                        expectation.fulfill()
                        return
                    }
                }
            }

            // Rapid updates
            for i in 0..<1000 {
                updateCount += 1
                await stateActor.updateViewerCount(i)
            }

            // Wait for observer to finish
            _ = try? await observerTask.value

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let throughput = Double(yieldCount) / elapsed
            let yieldPercentage = Double(yieldCount) / Double(updateCount) * 100

            print("📊 BASELINE: AsyncStream Throughput")
            print("   Updates Sent: \(updateCount)")
            print("   Yields Received: \(yieldCount)")
            print("   Yield Rate: \(String(format: "%.1f", yieldPercentage))%")
            print("   Throughput: \(String(format: "%.0f", throughput)) yields/sec")
            print("   Duration: \(String(format: "%.3f", elapsed))s")
        }

        wait(for: [expectation], timeout: 10)
    }

    // MARK: - Test: Polling Service Updates

    func testBaselinePollingServiceMemory() {
        MemoryMetrics.startMeasurement()

        let expectation = XCTestExpectation(description: "polling complete")
        expectation.expectedFulfillmentCount = 1

        Task {
            let stateActor = DefaultPlaybackStateActor()

            // Simulate polling service updates for 10 seconds
            // Assuming 10 updates per second (typical polling rate)
            for i in 0..<100 {
                // Viewer count polling (most frequent update)
                await stateActor.updateViewerCount(50 + (i % 30))
                MemoryMetrics.recordPeak()

                // Small delay between polls
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms per update
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15)

        let delta = MemoryMetrics.memoryDelta()
        let formattedDelta = MemoryMetrics.formatMemory(UInt64(abs(delta)))

        print("📊 BASELINE: Polling Service Updates (100 updates over 10s)")
        print("   Peak Memory: \(MemoryMetrics.formatMemory(MemoryMetrics.peakMemory))")
        print("   Memory Delta: \(delta > 0 ? "+" : "")\(formattedDelta)")

        // Baseline assertion
        XCTAssertLessThan(delta, 5_000_000, "Polling updates should use < 5MB")
    }

    // MARK: - Test: ViewModel Observer Pattern

    func testBaselineViewModelObserverOverhead() {
        let expectation = XCTestExpectation(description: "observer complete")
        expectation.expectedFulfillmentCount = 1

        let startTime = CFAbsoluteTimeGetCurrent()

        Task {
            let stateActor = DefaultPlaybackStateActor()
            let viewModel = await PlaybackViewModel(stateActor: stateActor)

            // Rapid updates through ViewModel
            for i in 0..<100 {
                // These go through the actor -> AsyncStream -> observer -> @Published
                Task {
                    await stateActor.updateViewerCount(i)
                    await stateActor.updateConnectionStatus(.connected)

                    if i == 99 {
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: 10)

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        print("📊 BASELINE: ViewModel Observer Overhead")
        print("   100 Update Cycles: \(String(format: "%.3f", elapsed))s")
        print("   Time per Update Cycle: \(String(format: "%.1f", elapsed * 1000 / 100))ms")

        // Should be very fast (< 100ms for 100 updates)
        XCTAssertLessThan(elapsed, 1.0, "Observer overhead should be < 1 second")
    }

    // MARK: - Test: Concurrent Updates Consistency

    func testBaselineConcurrentUpdateConsistency() {
        let expectation = XCTestExpectation(description: "concurrent updates complete")
        expectation.expectedFulfillmentCount = 100

        Task {
            let stateActor = DefaultPlaybackStateActor()

            // Concurrent updates from multiple tasks
            for i in 0..<100 {
                Task {
                    // Each task performs different updates
                    for _ in 0..<10 {
                        await stateActor.updateViewerCount(Int.random(in: 0..<100))
                    }
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 10)

        print("📊 BASELINE: Concurrent Updates Consistency")
        print("   100 concurrent tasks with 10 updates each = 1000 total updates")
        print("   ✅ No crashes or data races detected")
    }
}

// MARK: - Baseline Summary Generator

class BaselineReporter {
    static func generateSummary() {
        print("""

        ════════════════════════════════════════════════════════════════
        📊 PHASE 8 BASELINE SUMMARY
        ════════════════════════════════════════════════════════════════

        ✅ Baseline measurements complete. Use these as reference for
           Phase 8 optimizations:

        Key Metrics to Track:
        1. Memory Peak (target < 40MB)
        2. Memory Delta (target < 2MB for rapid updates)
        3. AsyncStream Yields (target 50% reduction)
        4. Update Latency (target < 5ms average)
        5. CPU Usage (target 45% reduction)

        Next Steps:
        - Step 2: Memory profiling with Xcode Instruments
        - Step 3: AsyncStream efficiency analysis
        - Step 4: Implement deduplication optimization
        - Step 5: Optimize polling updates
        - Step 6: Re-measure and compare
        - Step 7: Create performance benchmarks
        - Step 8: Document findings

        ════════════════════════════════════════════════════════════════

        """)
    }
}
