import SwiftUI

typealias TextPathAttributes = [NSAttributedString.Key:Any]

public class TextPathGlyph {
    public typealias Index = String.UnicodeScalarView.Index
    public fileprivate(set) var index: Index
    public fileprivate(set) var path: CGPath
    public fileprivate(set) var position: CGPoint
    public fileprivate(set) var advance = CGSize.zero
    public fileprivate(set) var originOffset = CGPoint.zero
    fileprivate var lineRun: Int = 0
    fileprivate weak var line: TextPathLine?
    public var attributes: [NSAttributedString.Key:Any]? {
        return line?.attributes(ForGlyph: self)
    }
    init(index: Index, path: CGPath, position: CGPoint){
        self.index = index
        self.path = path
        self.position = position
    }
}
public class TextPathLine {
    public fileprivate(set) var index: Int

    public fileprivate(set) var lineBounds = CGRect.zero

    public fileprivate(set) var textBounds = CGRect.zero

    public fileprivate(set) var leading = CGFloat(0.0)
    public fileprivate(set) var ascent = CGFloat(0.0)
    public fileprivate(set) var descent = CGFloat(0.0)
    public fileprivate(set) var effectiveDescent = CGFloat(0.0)

    public fileprivate(set) var effectiveAscent = CGFloat(0.0)

    fileprivate var attributes: [TextPathAttributes]?

    fileprivate var glyphs = [TextPathGlyph]()

    init(index: Int) {
        self.index = index
    }

    public func enumerateGlyphs(_ callback:(_ line: TextPathLine, _ glyph: TextPathGlyph) -> ()) {
        for glyph in glyphs {
            callback(self, glyph)
        }
    }
    fileprivate func attributes(ForGlyph glyph: TextPathGlyph) -> TextPathAttributes? {
        if let attributes = attributes {
            return attributes[glyph.lineRun]
        }
        return nil
    }
}

public class TextPathFrame {
    public fileprivate(set) var path: CGPath

    public fileprivate(set) var lines = [TextPathLine]()
    init(path: CGPath) {
        self.path = path
    }

    public func enumerateGlyphs(_ callback: @escaping(_ line: TextPathLine, _ glyph: TextPathGlyph) -> ()) {
        for line in lines {
            line.enumerateGlyphs(callback)
        }
    }
}
public class TextPath {
    public fileprivate(set) var attributedString: NSAttributedString
    public fileprivate(set) var composedPath: CGPath?
    public fileprivate(set) var composedBounds: CGRect
    public fileprivate(set) var frames = [TextPathFrame]()
    init(text: NSAttributedString, path: CGPath? = nil) {
        self.attributedString = text
        self.composedPath = path
        self.composedBounds = path?.boundingBoxOfPath ?? CGRect.zero
    }
}
typealias TextShape = NSAttributedString.TextShape

public extension NSAttributedString {
    func getTextPath(InBounds bounds:CGSize, withAttributes: Bool = false, withPath: Bool = true) -> TextPath? {
        let clearText = self.string
        if clearText.isEmpty {
            return nil
        }
        let fontAttributeKey = NSAttributedString.Key.font
        let defaultAttributes: TextPathAttributes = [
            fontAttributeKey: UIFont.systemFont(ofSize: UIFont.systemFontSize),
            NSAttributedString.Key.foregroundColor: UIColor.black
        ]
        var lineIndex = 0
        let unicodeScalars = clearText.unicodeScalars
        var unicodeIndex = unicodeScalars.startIndex
        let frameSetter = CTFramesetterCreateWithAttributedString(self)
        let textRange = CFRangeMake(0, self.length)
        let frameSize = CTFramesetterSuggestFrameSizeWithConstraints(frameSetter, textRange, nil, bounds, nil)
        let framePath = UIBezierPath(rect: CGRect(origin: .zero, size: frameSize)).cgPath
        let frame = CTFramesetterCreateFrame(frameSetter, textRange, framePath, nil)
        let tpFrame = TextPathFrame(path: framePath)
        let frames = [tpFrame]

        let ignoredCharsSet = CharacterSet.whitespacesAndNewlines
        let path = CGMutablePath()
        if let lines = CTFrameGetLines(frame) as? [CTLine] {
            var linesShift = CGFloat(0)
            var origins = [CGPoint](repeating: CGPoint.zero, count: lines.count)
            CTFrameGetLineOrigins(frame, CFRangeMake(0, lines.count), &origins)
            var originItr = origins.makeIterator()
            for line in lines {
                let lineOrigin = originItr.next() ?? CGPoint.zero
                let tpLine = TextPathLine(index: lineIndex)
                tpLine.lineBounds = CTLineGetBoundsWithOptions(line, .excludeTypographicLeading)
                tpLine.textBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
                let _ = CTLineGetTypographicBounds(line, &tpLine.ascent, &tpLine.descent, &tpLine.leading)

                if let lineRuns = CTLineGetGlyphRuns(line) as? [CTRun] {
                    if withAttributes {
                        tpLine.attributes = [TextPathAttributes](repeating:defaultAttributes,
                                                                 count: lineRuns.count)
                    }
                    var effectiveDescent = CGFloat(0)
                    var effectiveAscent = CGFloat(0)
                    var lineRunIndex = 0
                    for lineRun in lineRuns {
                        let glyphsCount = CTRunGetGlyphCount(lineRun)
                        if glyphsCount == 0 {
                            continue
                        }
                        let attributes = (CTRunGetAttributes(lineRun) as? TextPathAttributes) ?? defaultAttributes
                        let font = (attributes[fontAttributeKey] as? UIFont) ?? (defaultAttributes[fontAttributeKey] as! UIFont)

                        if withAttributes {
                            tpLine.attributes![lineRunIndex] = attributes
                        }
                        var rt_ascent = CGFloat(0.0)
                        var rt_descent = CGFloat(0.0)
                        var rt_leading = CGFloat(0.0)
                        let _ = CTRunGetTypographicBounds(lineRun, CFRangeMake(0, glyphsCount), &rt_ascent, &rt_descent, &rt_leading)
                        let range = CFRangeMake(0, glyphsCount)
                        let glyphsBuffer = UnsafeMutableBufferPointer<CGGlyph>.allocate(capacity: glyphsCount)
                        let positionsBuffer = UnsafeMutableBufferPointer<CGPoint>.allocate(capacity: glyphsCount)
                        let advancesBuffer = UnsafeMutableBufferPointer<CGSize>.allocate(capacity: glyphsCount)
                        defer {
                            glyphsBuffer.deallocate()
                            positionsBuffer.deinitialize()
                            positionsBuffer.deallocate()
                            advancesBuffer.deinitialize()
                            advancesBuffer.deallocate()
                        }
                        let lineRunInfo = (glyphsBuffer.baseAddress, positionsBuffer.baseAddress, advancesBuffer.baseAddress)
                        switch( lineRunInfo ) {
                        case let (glyphsPtr?, positionsPtr?, advancesPtr?):
                            CTRunGetGlyphs(lineRun, range, glyphsPtr)
                            CTRunGetPositions(lineRun, range, positionsPtr)
                            CTRunGetAdvances(lineRun, range, advancesPtr)
                            var glyphPtr = glyphsPtr
                            var positionPtr = positionsPtr
                            var advancePtr = advancesPtr
                            for _ in 0..<glyphsCount {
                                let glyphUnicodeIndex = unicodeIndex
                                unicodeIndex = unicodeScalars.index(after: unicodeIndex)
                                if(!ignoredCharsSet.contains(unicodeScalars[glyphUnicodeIndex])) {
                                    effectiveAscent = max(effectiveAscent, abs(rt_ascent))
                                    effectiveDescent = max(effectiveDescent, abs(rt_descent))

                                    let glyph = glyphPtr.pointee
                                    let position = positionPtr.pointee
                                    var T = CGAffineTransform(scaleX: 1, y: 1)
                                    let ctFont = font as CTFont
                                    if let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, &T) {
                                        let pathBounds = glyphPath.boundingBoxOfPath
                                        var pathOffset = CGAffineTransform(translationX: -pathBounds.origin.x, y: -pathBounds.origin.y)
                                        let glyphPathRel = glyphPath.copy(using: &pathOffset) ?? glyphPath
                                        let originOffset = CGPoint(x: -pathBounds.origin.x, y: pathBounds.origin.y)
                                        let offset = CGPoint(x: lineOrigin.x + position.x + pathBounds.origin.x,
                                                             y: lineOrigin.y + position.y + pathBounds.origin.y)
                                        let tpGlyph = TextPathGlyph(index: glyphUnicodeIndex, path: glyphPathRel, position: offset)
                                        tpGlyph.lineRun = lineRunIndex
                                        tpGlyph.advance = advancePtr.pointee
                                        tpGlyph.originOffset = originOffset
                                        tpGlyph.line = tpLine
                                        tpLine.glyphs.append(tpGlyph)
                                    }
                                }
                                glyphPtr = glyphPtr.successor()
                                positionPtr = positionPtr.successor()
                                advancePtr = advancePtr.successor()
                            }
                            break;
                        default:
                            return nil
                        }
                        lineRunIndex += 1
                    }
                    if tpLine.glyphs.count != 0 {
                        tpLine.effectiveAscent = effectiveAscent
                        tpLine.effectiveDescent = effectiveDescent
                        for tpGlyph in tpLine.glyphs {
                            let position = tpGlyph.position
                            let offset = CGPoint(x: position.x, y: position.y + (tpLine.ascent - tpLine.effectiveAscent) + linesShift)
                            let T = CGAffineTransform(translationX: offset.x, y: offset.y)
                            path.addPath(tpGlyph.path, transform: T)
                            tpGlyph.position = offset
                        }
                        tpFrame.lines.append(tpLine)
                        lineIndex += 1
                    }

                    linesShift += (tpLine.ascent + tpLine.descent) - (effectiveAscent + effectiveDescent)
                }
            }
        }
        var finalPath = path as CGPath
        var pathBounds = CGRect.zero
        var matrix = CGAffineTransform.identity

        pathBounds = path.boundingBoxOfPath
        let pathOffset = pathBounds.origin
        matrix = CGAffineTransform(translationX: -pathOffset.x, y: -pathOffset.y)
        if let copyPath = path.copy(using: &matrix) {
            finalPath = copyPath
            for tpFrame in frames {
                tpFrame.enumerateGlyphs { _, glyph in
                    glyph.position = glyph.position.applying(matrix)
                }
            }
        }
        pathBounds = path.boundingBoxOfPath
        matrix = CGAffineTransform(scaleX: 1, y: -1)
        matrix = matrix.translatedBy(x: 0, y: -pathBounds.size.height)
        if let copyPath = path.copy(using: &matrix) {
            finalPath = copyPath
            for tpFrame in frames {
                tpFrame.enumerateGlyphs { _, glyph in
                    let glyphPath = glyph.path
                    let glyphBounds = glyphPath.boundingBoxOfPath
                    let glyphHeight = glyphBounds.size.height
                    var flipMatrix = CGAffineTransform(scaleX: 1, y: -1)
                    flipMatrix = flipMatrix.translatedBy(x: 0, y: -glyphHeight)
                    if let copyPath = glyphPath.copy(using: &flipMatrix) {
                        glyph.path = copyPath
                        let position = glyph.position.applying(matrix).applying(CGAffineTransform(translationX: 0, y: -glyphHeight))
                        glyph.position = position
                    }
                }
            }
        }
        let tp = TextPath(text: self, path: withPath ? finalPath : nil)
        tp.composedBounds = CGRect(origin: pathOffset, size: finalPath.boundingBoxOfPath.size)
        tp.frames.append(contentsOf: frames)
        return tp
    }

    struct TextShape: Shape {
        let text: AttributedString
        public func path(in rect: CGRect) -> Path {
            let nsAttrStr = NSAttributedString(text)
            let textPath = nsAttrStr.getTextPath(InBounds: rect.size)!
            let bounds = textPath.composedBounds
            let path = textPath.composedPath!
            return Path(path)
                .applying(.init(
                    translationX: rect.midX - bounds.width / 2,
                    y: rect.midY - bounds.height / 2)
                )
        }
    }
}
