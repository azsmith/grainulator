//
//  AUHostingRegressionTests.swift
//  Grainulator
//
//  Regression tests locking current AU hosting behavior before VST3 abstraction.
//  Tests cover: slot lifecycle, bypass, state persistence, thread-safe accessors,
//  snapshot coding, and send slot specifics.
//

import XCTest
@testable import Grainulator

// MARK: - AUInsertSlot Regression Tests

final class AUInsertSlotRegressionTests: XCTestCase {

    // MARK: - Initialization

    func testSlotInitializesEmpty() async {
        await MainActor.run {
            let slot = AUInsertSlot(slotIndex: 0)
            XCTAssertEqual(slot.slotIndex, 0)
            XCTAssertNil(slot.audioUnit)
            XCTAssertNil(slot.pluginInfo)
            XCTAssertFalse(slot.isBypassed)
            XCTAssertFalse(slot.isLoading)
            XCTAssertNil(slot.loadError)
            XCTAssertNil(slot.viewController)
            XCTAssertFalse(slot.isLoadingUI)
        }
    }

    func testSlotIndexPreserved() {
        let slot0 = AUInsertSlot(slotIndex: 0)
        let slot1 = AUInsertSlot(slotIndex: 1)
        XCTAssertEqual(slot0.slotIndex, 0)
        XCTAssertEqual(slot1.slotIndex, 1)
    }

    func testSlotHasUniqueID() {
        let slot0 = AUInsertSlot(slotIndex: 0)
        let slot1 = AUInsertSlot(slotIndex: 0)
        XCTAssertNotEqual(slot0.id, slot1.id)
    }

    // MARK: - Thread-Safe Accessors (shadow state)

    func testShadowStateDefaultsMatchPublished() {
        let slot = AUInsertSlot(slotIndex: 0)
        XCTAssertFalse(slot.hasPluginSafe)
        XCTAssertNil(slot.pluginNameSafe)
        XCTAssertNil(slot.pluginInfoSafe)
        XCTAssertFalse(slot.isBypassedSafe)
        XCTAssertFalse(slot.isLoadingSafe)
    }

    func testBypassShadowUpdatesWithPublished() async {
        await MainActor.run {
            let slot = AUInsertSlot(slotIndex: 0)
            XCTAssertFalse(slot.isBypassedSafe)
            slot.isBypassed = true
            XCTAssertTrue(slot.isBypassedSafe)
            slot.isBypassed = false
            XCTAssertFalse(slot.isBypassedSafe)
        }
    }

    func testLoadingShadowUpdatesWithPublished() async {
        await MainActor.run {
            let slot = AUInsertSlot(slotIndex: 0)
            XCTAssertFalse(slot.isLoadingSafe)
            slot.isLoading = true
            XCTAssertTrue(slot.isLoadingSafe)
        }
    }

    // MARK: - Unload (without a loaded plugin)

    func testUnloadOnEmptySlotIsNoop() async {
        await MainActor.run {
            let slot = AUInsertSlot(slotIndex: 0)
            slot.unloadPlugin() // should not crash
            XCTAssertNil(slot.audioUnit)
            XCTAssertFalse(slot.hasPluginSafe)
        }
    }

    // MARK: - Bypass (without a loaded plugin)

    func testSetBypassWithoutPlugin() async {
        await MainActor.run {
            let slot = AUInsertSlot(slotIndex: 0)
            slot.setBypass(true)
            XCTAssertTrue(slot.isBypassed)
            XCTAssertTrue(slot.isBypassedSafe)
        }
    }

    func testSetBypassIdempotent() async {
        await MainActor.run {
            let slot = AUInsertSlot(slotIndex: 0)
            var callbackCount = 0
            slot.onBypassChanged = { _ in callbackCount += 1 }

            slot.setBypass(false) // same as default, should not fire
            XCTAssertEqual(callbackCount, 0)
        }
    }

    // MARK: - Callbacks

    func testOnAudioUnitChangedCalledOnUnload() async {
        let expectation = XCTestExpectation(description: "onAudioUnitChanged called")
        await MainActor.run {
            let slot = AUInsertSlot(slotIndex: 0)
            // Manually set audioUnit to non-nil to simulate loaded state
            // (we can't easily mock AVAudioUnit, so test the unload path check)
            slot.onAudioUnitChanged = { au in
                XCTAssertNil(au)
                expectation.fulfill()
            }
            // unloadPlugin only fires callback if audioUnit != nil
            // Since we can't set it without a real AU, verify the guard works:
            slot.unloadPlugin()
        }
        // The callback should NOT fire because audioUnit is nil
        // Verify by waiting briefly
        let result = XCTWaiter.wait(for: [expectation], timeout: 0.1)
        XCTAssertEqual(result, .timedOut, "Callback should not fire on empty unload")
    }

    // MARK: - Native UI

    func testLoadPluginUIWithoutPluginIsNoop() async {
        await MainActor.run {
            let slot = AUInsertSlot(slotIndex: 0)
            slot.loadPluginUI() // should not crash
            XCTAssertNil(slot.viewController)
            XCTAssertFalse(slot.isLoadingUI)
        }
    }

    func testUnloadPluginUIClearsViewController() async {
        await MainActor.run {
            let slot = AUInsertSlot(slotIndex: 0)
            slot.unloadPluginUI()
            XCTAssertNil(slot.viewController)
        }
    }

    // MARK: - State Persistence

    func testCreateSnapshotReturnsNilForEmptySlot() async {
        await MainActor.run {
            let slot = AUInsertSlot(slotIndex: 0)
            XCTAssertNil(slot.createSnapshot())
        }
    }

    func testFullStateIsNilForEmptySlot() async {
        await MainActor.run {
            let slot = AUInsertSlot(slotIndex: 0)
            XCTAssertNil(slot.fullState)
        }
    }

    func testRestoreStateOnEmptySlotIsNoop() async {
        await MainActor.run {
            let slot = AUInsertSlot(slotIndex: 0)
            slot.restoreState(["key": "value"]) // should not crash
        }
    }
}

// MARK: - AUSendSlot Regression Tests

final class AUSendSlotRegressionTests: XCTestCase {

    // MARK: - Initialization

    func testSendSlotInitializesWithDefaults() async {
        await MainActor.run {
            let slot = AUSendSlot(busIndex: 0, busName: "Delay")
            XCTAssertEqual(slot.busIndex, 0)
            XCTAssertEqual(slot.busName, "Delay")
            XCTAssertNil(slot.audioUnit)
            XCTAssertNil(slot.pluginInfo)
            XCTAssertFalse(slot.isBypassed)
            XCTAssertEqual(slot.returnLevel, 0.5)
            XCTAssertFalse(slot.isLoading)
            XCTAssertNil(slot.loadError)
        }
    }

    func testSendSlotBusIdentity() {
        let delay = AUSendSlot(busIndex: 0, busName: "Delay")
        let reverb = AUSendSlot(busIndex: 1, busName: "Reverb")
        XCTAssertEqual(delay.busIndex, 0)
        XCTAssertEqual(reverb.busIndex, 1)
        XCTAssertNotEqual(delay.id, reverb.id)
    }

    // MARK: - Thread-Safe Accessors

    func testSendShadowStateDefaults() {
        let slot = AUSendSlot(busIndex: 0, busName: "Delay")
        XCTAssertFalse(slot.hasPluginSafe)
        XCTAssertNil(slot.pluginNameSafe)
        XCTAssertNil(slot.pluginInfoSafe)
        XCTAssertFalse(slot.isBypassedSafe)
        XCTAssertFalse(slot.isLoadingSafe)
        XCTAssertEqual(slot.returnLevelSafe, 0.5)
    }

    func testReturnLevelShadowUpdates() async {
        await MainActor.run {
            let slot = AUSendSlot(busIndex: 0, busName: "Delay")
            slot.returnLevel = 0.75
            XCTAssertEqual(slot.returnLevelSafe, 0.75, accuracy: 0.001)
        }
    }

    // MARK: - Return Level

    func testSetReturnLevelClampsToRange() async {
        await MainActor.run {
            let slot = AUSendSlot(busIndex: 0, busName: "Delay")
            slot.setReturnLevel(1.5)
            XCTAssertEqual(slot.returnLevel, 1.0, accuracy: 0.001)
            slot.setReturnLevel(-0.5)
            XCTAssertEqual(slot.returnLevel, 0.0, accuracy: 0.001)
        }
    }

    func testReturnLevelDBFormatting() async {
        await MainActor.run {
            let slot = AUSendSlot(busIndex: 0, busName: "Delay")
            slot.returnLevel = 0.0
            XCTAssertEqual(slot.returnLevelDB, "-∞")
            slot.returnLevel = 1.0
            XCTAssertEqual(slot.returnLevelDB, "0.0")
            slot.returnLevel = 0.5
            // -6.0 dB
            XCTAssertTrue(slot.returnLevelDB.contains("-6"))
        }
    }

    // MARK: - isActive computed property

    func testIsActiveRequiresPluginAndNotBypassed() async {
        await MainActor.run {
            let slot = AUSendSlot(busIndex: 0, busName: "Delay")
            // No plugin → not active
            XCTAssertFalse(slot.isActive)
            // With bypass and no plugin → not active
            slot.isBypassed = true
            XCTAssertFalse(slot.isActive)
        }
    }

    // MARK: - Bypass

    func testSendBypassIdempotent() async {
        await MainActor.run {
            let slot = AUSendSlot(busIndex: 0, busName: "Delay")
            var callbackCount = 0
            slot.onParameterChanged = { callbackCount += 1 }
            slot.setBypass(false) // same as default
            XCTAssertEqual(callbackCount, 0)
        }
    }

    func testSendBypassToggle() async {
        await MainActor.run {
            let slot = AUSendSlot(busIndex: 0, busName: "Delay")
            slot.setBypass(true)
            XCTAssertTrue(slot.isBypassed)
            XCTAssertTrue(slot.isBypassedSafe)
            slot.setBypass(false)
            XCTAssertFalse(slot.isBypassed)
            XCTAssertFalse(slot.isBypassedSafe)
        }
    }

    // MARK: - Unload

    func testSendUnloadOnEmptyIsNoop() async {
        await MainActor.run {
            let slot = AUSendSlot(busIndex: 0, busName: "Delay")
            slot.unloadPlugin() // should not crash
            XCTAssertNil(slot.audioUnit)
        }
    }

    // MARK: - State Persistence

    func testSendCreateSnapshotReturnsNilForEmpty() async {
        await MainActor.run {
            let slot = AUSendSlot(busIndex: 0, busName: "Delay")
            XCTAssertNil(slot.createSnapshot())
        }
    }

    func testSendFullStateNilForEmpty() async {
        await MainActor.run {
            let slot = AUSendSlot(busIndex: 0, busName: "Delay")
            XCTAssertNil(slot.fullState)
        }
    }
}

// MARK: - AUSlotSnapshot Coding Tests

final class AUSlotSnapshotCodingTests: XCTestCase {

    func testInsertSnapshotRoundTrip() throws {
        let original = AUSlotSnapshot(
            componentType: 0x61756678,    // 'aufx'
            componentSubType: 0x64656C79, // 'dely'
            componentManufacturer: 0x6170706C, // 'appl'
            fullState: Data([0x01, 0x02, 0x03]),
            isBypassed: true
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AUSlotSnapshot.self, from: encoded)

        XCTAssertEqual(decoded.componentType, original.componentType)
        XCTAssertEqual(decoded.componentSubType, original.componentSubType)
        XCTAssertEqual(decoded.componentManufacturer, original.componentManufacturer)
        XCTAssertEqual(decoded.fullState, original.fullState)
        XCTAssertEqual(decoded.isBypassed, original.isBypassed)
    }

    func testInsertSnapshotWithNilState() throws {
        let original = AUSlotSnapshot(
            componentType: 0x61756678,
            componentSubType: 0x64656C79,
            componentManufacturer: 0x6170706C,
            fullState: nil,
            isBypassed: false
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AUSlotSnapshot.self, from: encoded)

        XCTAssertNil(decoded.fullState)
        XCTAssertFalse(decoded.isBypassed)
    }

    func testInsertSnapshotIdentifier() {
        let snapshot = AUSlotSnapshot(
            componentType: 0x61756678,    // 'aufx'
            componentSubType: 0x64656C79, // 'dely'
            componentManufacturer: 0x6170706C, // 'appl'
            fullState: nil,
            isBypassed: false
        )
        // identifier format: "manufacturer:type:subType"
        XCTAssertEqual(snapshot.identifier, "appl:aufx:dely")
    }

    func testSendSnapshotRoundTrip() throws {
        let original = AUSendSnapshot(
            busIndex: 1,
            componentType: 0x61756678,
            componentSubType: 0x72767262, // 'rvrb'
            componentManufacturer: 0x6170706C,
            fullState: Data([0xAA, 0xBB]),
            isBypassed: false,
            returnLevel: 0.75
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AUSendSnapshot.self, from: encoded)

        XCTAssertEqual(decoded.busIndex, 1)
        XCTAssertEqual(decoded.componentType, original.componentType)
        XCTAssertEqual(decoded.componentSubType, original.componentSubType)
        XCTAssertEqual(decoded.componentManufacturer, original.componentManufacturer)
        XCTAssertEqual(decoded.fullState, original.fullState)
        XCTAssertFalse(decoded.isBypassed)
        XCTAssertEqual(decoded.returnLevel, 0.75, accuracy: 0.001)
    }
}

// MARK: - SendEffectType Tests

final class SendEffectTypeTests: XCTestCase {

    func testDelayConfiguration() {
        let delay = SendEffectType.delay
        XCTAssertEqual(delay.busIndex, 0)
        XCTAssertFalse(delay.searchKeywords.isEmpty)
        XCTAssertTrue(delay.searchKeywords.contains("delay"))
    }

    func testReverbConfiguration() {
        let reverb = SendEffectType.reverb
        XCTAssertEqual(reverb.busIndex, 1)
        XCTAssertFalse(reverb.searchKeywords.isEmpty)
        XCTAssertTrue(reverb.searchKeywords.contains("reverb"))
    }

    func testAllCasesHasTwoEntries() {
        XCTAssertEqual(SendEffectType.allCases.count, 2)
    }
}

// MARK: - AUPluginCategory Tests

final class AUPluginCategoryTests: XCTestCase {

    func testAllCategoryMatchesEverything() {
        XCTAssertTrue(AUPluginCategory.all.matches("Any Plugin Name"))
        XCTAssertTrue(AUPluginCategory.all.matches(""))
    }

    func testCategoryKeywordMatching() {
        XCTAssertTrue(AUPluginCategory.delay.matches("EchoBoy"))
        XCTAssertTrue(AUPluginCategory.delay.matches("Tape Delay"))
        XCTAssertTrue(AUPluginCategory.reverb.matches("ValhallaRoom"))
        XCTAssertTrue(AUPluginCategory.dynamics.matches("FET Compressor"))
        XCTAssertTrue(AUPluginCategory.eq.matches("Parametric EQ"))
    }

    func testCategoryNonMatch() {
        XCTAssertFalse(AUPluginCategory.delay.matches("ValhallaRoom"))
        XCTAssertFalse(AUPluginCategory.reverb.matches("EchoBoy"))
    }

    func testOtherCategoryMatchesNothing() {
        XCTAssertFalse(AUPluginCategory.other.matches("Random Plugin"))
    }

    func testAllCasesCount() {
        XCTAssertEqual(AUPluginCategory.allCases.count, 9)
    }
}

// MARK: - AUPluginError Tests

final class AUPluginErrorTests: XCTestCase {

    func testAllErrorsHaveDescriptions() {
        let errors: [AUPluginError] = [
            .instantiationFailed,
            .connectionFailed,
            .formatMismatch,
            .pluginNotFound,
            .stateSaveLoadFailed
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}
