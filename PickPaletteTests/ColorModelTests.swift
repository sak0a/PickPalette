import XCTest
@testable import PickPalette

final class ColorModelTests: XCTestCase {

    let tolerance: CGFloat = 0.01

    // MARK: - RGB Init

    func testRGBInit() {
        let c = ColorModel(red: 0.5, green: 0.3, blue: 0.8, alpha: 0.9)
        XCTAssertEqual(c.red, 0.5, accuracy: tolerance)
        XCTAssertEqual(c.green, 0.3, accuracy: tolerance)
        XCTAssertEqual(c.blue, 0.8, accuracy: tolerance)
        XCTAssertEqual(c.alpha, 0.9, accuracy: tolerance)
    }

    func testClampingOutOfRange() {
        let c = ColorModel(red: 1.5, green: -0.3, blue: 0.5, alpha: 2.0)
        XCTAssertEqual(c.red, 1.0, accuracy: tolerance)
        XCTAssertEqual(c.green, 0.0, accuracy: tolerance)
        XCTAssertEqual(c.blue, 0.5, accuracy: tolerance)
        XCTAssertEqual(c.alpha, 1.0, accuracy: tolerance)
    }

    // MARK: - Pure White

    func testPureWhite() {
        let c = ColorModel.white
        XCTAssertEqual(c.red, 1, accuracy: tolerance)
        XCTAssertEqual(c.green, 1, accuracy: tolerance)
        XCTAssertEqual(c.blue, 1, accuracy: tolerance)
        // HSL: 0, 0, 1
        XCTAssertEqual(c.lightness, 1.0, accuracy: tolerance)
        XCTAssertEqual(c.saturationHSL, 0, accuracy: tolerance)
        // HSB: 0, 0, 1
        XCTAssertEqual(c.brightness, 1.0, accuracy: tolerance)
        XCTAssertEqual(c.saturationHSB, 0, accuracy: tolerance)
        // CMYK: 0, 0, 0, 0
        XCTAssertEqual(c.cyan, 0, accuracy: tolerance)
        XCTAssertEqual(c.key, 0, accuracy: tolerance)
        // Hex
        XCTAssertEqual(c.hexString, "#FFFFFF")
    }

    // MARK: - Pure Black

    func testPureBlack() {
        let c = ColorModel.black
        XCTAssertEqual(c.lightness, 0, accuracy: tolerance)
        XCTAssertEqual(c.brightness, 0, accuracy: tolerance)
        XCTAssertEqual(c.key, 1.0, accuracy: tolerance)
        XCTAssertEqual(c.hexString, "#000000")
    }

    // MARK: - Fully Transparent

    func testFullyTransparent() {
        let c = ColorModel.clear
        XCTAssertEqual(c.alpha, 0, accuracy: tolerance)
        XCTAssertEqual(c.hexaString, "#00000000")
    }

    // MARK: - HSL Roundtrip

    func testHSLRoundtrip() {
        // Known color: pure red
        let red = ColorModel(red: 1, green: 0, blue: 0)
        XCTAssertEqual(red.hue, 0, accuracy: tolerance)
        XCTAssertEqual(red.saturationHSL, 1.0, accuracy: tolerance)
        XCTAssertEqual(red.lightness, 0.5, accuracy: tolerance)

        // Roundtrip: create from HSL then verify RGB
        let fromHSL = ColorModel.fromHSL(h: 0, s: 1.0, l: 0.5)
        XCTAssertEqual(fromHSL.red, 1.0, accuracy: tolerance)
        XCTAssertEqual(fromHSL.green, 0.0, accuracy: tolerance)
        XCTAssertEqual(fromHSL.blue, 0.0, accuracy: tolerance)
    }

    func testHSLGreen() {
        let green = ColorModel(red: 0, green: 1, blue: 0)
        XCTAssertEqual(green.hue * 360, 120, accuracy: 1.0)
        XCTAssertEqual(green.saturationHSL, 1.0, accuracy: tolerance)
        XCTAssertEqual(green.lightness, 0.5, accuracy: tolerance)
    }

    func testHSLBlue() {
        let blue = ColorModel(red: 0, green: 0, blue: 1)
        XCTAssertEqual(blue.hue * 360, 240, accuracy: 1.0)
    }

    // MARK: - HSB Roundtrip

    func testHSBRoundtrip() {
        let c = ColorModel(red: 0.5, green: 0.7, blue: 0.3)
        let h = c.hueHSB
        let s = c.saturationHSB
        let b = c.brightness

        let roundtrip = ColorModel.fromHSB(h: h, s: s, b: b)
        XCTAssertEqual(roundtrip.red, c.red, accuracy: tolerance)
        XCTAssertEqual(roundtrip.green, c.green, accuracy: tolerance)
        XCTAssertEqual(roundtrip.blue, c.blue, accuracy: tolerance)
    }

    // MARK: - CMYK

    func testCMYKPureRed() {
        let red = ColorModel(red: 1, green: 0, blue: 0)
        XCTAssertEqual(red.cyan, 0, accuracy: tolerance)
        XCTAssertEqual(red.magenta, 1.0, accuracy: tolerance)
        XCTAssertEqual(red.yellow, 1.0, accuracy: tolerance)
        XCTAssertEqual(red.key, 0, accuracy: tolerance)
    }

    func testCMYKRoundtrip() {
        let c = ColorModel(red: 0.2, green: 0.6, blue: 0.4)
        let roundtrip = ColorModel.fromCMYK(c: c.cyan, m: c.magenta, y: c.yellow, k: c.key)
        XCTAssertEqual(roundtrip.red, c.red, accuracy: tolerance)
        XCTAssertEqual(roundtrip.green, c.green, accuracy: tolerance)
        XCTAssertEqual(roundtrip.blue, c.blue, accuracy: tolerance)
    }

    // MARK: - Hex

    func testHexParsing6Digit() {
        let c = ColorModel.fromHex("#6E85F7")!
        XCTAssertEqual(c.red, 110.0 / 255.0, accuracy: tolerance)
        XCTAssertEqual(c.green, 133.0 / 255.0, accuracy: tolerance)
        XCTAssertEqual(c.blue, 247.0 / 255.0, accuracy: tolerance)
        XCTAssertEqual(c.alpha, 1.0, accuracy: tolerance)
    }

    func testHexParsing8Digit() {
        let c = ColorModel.fromHex("#6E85F780")!
        XCTAssertEqual(c.alpha, 128.0 / 255.0, accuracy: tolerance)
    }

    func testHexParsing3Digit() {
        let c = ColorModel.fromHex("#F00")!
        XCTAssertEqual(c.red, 1.0, accuracy: tolerance)
        XCTAssertEqual(c.green, 0.0, accuracy: tolerance)
        XCTAssertEqual(c.blue, 0.0, accuracy: tolerance)
    }

    func testHexOutputRoundtrip() {
        let original = ColorModel.fromHex("#6E85F7")!
        XCTAssertEqual(original.hexString, "#6E85F7")
    }

    func testHexInvalid() {
        XCTAssertNil(ColorModel.fromHex("ZZZZZZ"))
        XCTAssertNil(ColorModel.fromHex("#12345"))
    }

    // MARK: - Hue Wrapping

    func testHueWrapping() {
        // Hue at exactly 360 should be treated as 0
        let c = ColorModel.fromHSL(h: 1.0, s: 1.0, l: 0.5) // h=1.0 means 360 degrees
        // After clamping to 0–1, h=1.0 is valid (equivalent to 0)
        XCTAssertEqual(c.red, 1.0, accuracy: tolerance)
        XCTAssertEqual(c.green, 0.0, accuracy: tolerance)
        XCTAssertEqual(c.blue, 0.0, accuracy: tolerance)
    }

    // MARK: - Alpha Preservation

    func testAlphaPreservedInConversions() {
        let c = ColorModel(red: 0.5, green: 0.3, blue: 0.8, alpha: 0.42)
        let fromHSL = ColorModel.fromHSL(h: c.hue, s: c.saturationHSL, l: c.lightness, a: c.alpha)
        XCTAssertEqual(fromHSL.alpha, 0.42, accuracy: tolerance)
        let fromHSB = ColorModel.fromHSB(h: c.hueHSB, s: c.saturationHSB, b: c.brightness, a: c.alpha)
        XCTAssertEqual(fromHSB.alpha, 0.42, accuracy: tolerance)
    }

    // MARK: - Bidirectional Updates

    func testBidirectionalHSLUpdate() {
        var c = ColorModel(red: 1, green: 0, blue: 0) // Pure red
        c.lightness = 0.75 // Lighten
        // Should produce a lighter red, not change hue
        XCTAssertEqual(c.hue, 0, accuracy: tolerance)
        XCTAssertGreaterThan(c.red, 0.5)
    }

    func testBidirectionalHSBUpdate() {
        var c = ColorModel(red: 0, green: 0, blue: 1) // Pure blue
        c.brightness = 0.5 // Darken
        XCTAssertEqual(c.blue, 0.5, accuracy: tolerance)
        XCTAssertEqual(c.red, 0, accuracy: tolerance)
        XCTAssertEqual(c.green, 0, accuracy: tolerance)
    }

    // MARK: - Format Output

    func testHexFormat() {
        let c = ColorModel.fromHex("#6E85F7")!
        let output = ColorFormat.hexFormat.format(color: c)
        XCTAssertEqual(output, "#6E85F7")
    }

    func testRGBAFormat() {
        let c = ColorModel(red: 110/255, green: 133/255, blue: 247/255, alpha: 1.0)
        let output = ColorFormat.rgbaFormat.format(color: c)
        XCTAssertEqual(output, "rgba(110, 133, 247, 100%)")
    }

    func testHSLAFormat() {
        let c = ColorModel.fromHSL(h: 230.0/360.0, s: 0.9, l: 0.7)
        let output = ColorFormat.hslaFormat.format(color: c)
        XCTAssertTrue(output.hasPrefix("hsla("))
        XCTAssertTrue(output.hasSuffix(")"))
    }
}
