//
//  SwiftUIBridgeTests.swift
//  IKEMEN Lab Tests
//
//  Tests for SwiftUI migration infrastructure
//

import XCTest
import SwiftUI
@testable import IKEMEN_Lab

final class SwiftUIBridgeTests: XCTestCase {
    
    func testSwiftUIHostingViewCreation() throws {
        // Test that we can create a SwiftUI hosting view
        let testView = Text("Test")
        let hostingView = SwiftUIHostingView(rootView: testView)
        
        XCTAssertNotNil(hostingView, "SwiftUIHostingView should be created")
        XCTAssertEqual(hostingView.subviews.count, 1, "SwiftUIHostingView should contain the hosting controller's view")
    }
    
    func testAppKitHostableProtocol() throws {
        // Test that AppKitHostable protocol works
        struct TestView: View, AppKitHostable {
            var body: some View {
                Text("Test View")
            }
        }
        
        let testView = TestView()
        let hostView = testView.makeHostView()
        
        XCTAssertNotNil(hostView, "makeHostView() should create a hosting view")
        XCTAssertTrue(hostView is SwiftUIHostingView<TestView>, "Should return SwiftUIHostingView type")
    }
    
    func testDesignSystemColors() throws {
        // Test that SwiftUI colors are accessible
        let bgColor = Color.background
        let textColor = Color.textPrimary
        let cardColor = Color.cardBackground
        
        XCTAssertNotNil(bgColor, "Design system colors should be accessible")
        XCTAssertNotNil(textColor, "Text colors should be accessible")
        XCTAssertNotNil(cardColor, "Card colors should be accessible")
    }
    
    func testDesignSystemFonts() throws {
        // Test that SwiftUI fonts are accessible
        let headerFont = Font.header(size: 24)
        let bodyFont = Font.body(size: 14)
        let captionFont = Font.caption(size: 12)
        
        XCTAssertNotNil(headerFont, "Header font should be accessible")
        XCTAssertNotNil(bodyFont, "Body font should be accessible")
        XCTAssertNotNil(captionFont, "Caption font should be accessible")
    }
    
    func testAboutViewCreation() throws {
        // Test that AboutView can be instantiated
        let aboutView = AboutView()
        
        XCTAssertNotNil(aboutView, "AboutView should be created")
    }
    
    func testAppStateInitialization() throws {
        // Test that AppState singleton initializes
        let appState = AppState.shared
        
        XCTAssertNotNil(appState, "AppState.shared should be accessible")
        XCTAssertNotNil(appState.characters, "Characters array should be initialized")
        XCTAssertNotNil(appState.stages, "Stages array should be initialized")
    }
}
