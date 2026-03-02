import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import ExpoModulesCore

public class CityPopProcessorModule: Module {
  private let context = CIContext(options: [.useSoftwareRenderer: false])

  public func definition() -> ModuleDefinition {
    Name("CityPopProcessor")

    AsyncFunction("process") { (args: ProcessArgs, promise: Promise) in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let result = try self.processImage(args: args)
          promise.resolve([
            "resultUri": result.uri,
            "width": result.width,
            "height": result.height
          ])
        } catch {
          promise.reject("ERR_PROCESS_FAILED", "Image processing failed: \(error.localizedDescription)")
        }
      }
    }
  }

  private func processImage(args: ProcessArgs) throws -> (uri: String, width: Int, height: Int) {
    let inputURL = args.inputUri.starts(with: "file://") ? URL(fileURLWithPath: args.inputUri.replacingOccurrences(of: "file://", with: "")) : URL(fileURLWithPath: args.inputUri)
    let outputURL = args.outputUri.starts(with: "file://") ? URL(fileURLWithPath: args.outputUri.replacingOccurrences(of: "file://", with: "")) : URL(fileURLWithPath: args.outputUri)

    // Ensure they are file URLs for Data operations
    guard inputURL.isFileURL, outputURL.isFileURL else {
      throw NSError(domain: "CityPop", code: 1, userInfo: [NSLocalizedDescriptionKey: "URIs must be file URLs"])
    }

    // Load Image & Fix Orientation
    guard let imageData = try? Data(contentsOf: inputURL),
          let uiImage = UIImage(data: imageData),
          let cgImage = uiImage.cgImage else {
      throw NSError(domain: "CityPop", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
    }

    let originalOrientation = uiImage.imageOrientation
    let normalizedImage = normalizeOrientation(cgImage: cgImage, orientation: originalOrientation)
    let ciInputImage = CIImage(cgImage: normalizedImage)

    let targetSize = CGSize(width: CGFloat(args.targetWidth), height: CGFloat(args.targetHeight))

    // 1. Create Background (Blurred & Tinted)
    let bgImage = createBackgroundLayer(input: ciInputImage, targetSize: targetSize, mood: args.mood)
    
    // 2. Create Main Overlay (Center Cropped to 9:16)
    var mainImage = createMainLayer(input: ciInputImage, targetSize: targetSize, tone: CGFloat(args.tone))
    
    // 3. Apply Neon Glow
    mainImage = applyNeon(input: mainImage, neon: CGFloat(args.neon))

    // Composite
    guard let compositeFilter = CIFilter(name: "CISourceOverCompositing") else {
      throw NSError(domain: "CityPop", code: 3, userInfo: [NSLocalizedDescriptionKey: "Filter failed"])
    }
    compositeFilter.setValue(mainImage, forKey: kCIInputImageKey)
    compositeFilter.setValue(bgImage, forKey: kCIInputBackgroundImageKey)
    
    var finalCImage = compositeFilter.outputImage ?? bgImage

    // 4. Apply Grain
    finalCImage = applyGrain(input: finalCImage, grain: CGFloat(args.grain))

    // 5. Apply Title
    finalCImage = applyTitle(input: finalCImage, title: args.title, targetSize: targetSize)

    // Render to JPEG
    let colorSpace = finalCImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
    guard let outputCGImage = context.createCGImage(finalCImage, from: finalCImage.extent) else {
      throw NSError(domain: "CityPop", code: 4, userInfo: [NSLocalizedDescriptionKey: "Render failed"])
    }

    let finalUIImage = UIImage(cgImage: outputCGImage)
    guard let jpegData = finalUIImage.jpegData(compressionQuality: CGFloat(args.jpegQuality)) else {
      throw NSError(domain: "CityPop", code: 5, userInfo: [NSLocalizedDescriptionKey: "JPEG compression failed"])
    }

    try jpegData.write(to: outputURL)

    // Return the file:// URI
    return (uri: "file://" + outputURL.path, width: Int(targetSize.width), height: Int(targetSize.height))
  }

  // MARK: - Helpers

  private func normalizeOrientation(cgImage: CGImage, orientation: UIImage.Orientation) -> CGImage {
    if orientation == .up { return cgImage }
    let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    UIGraphicsBeginImageContextWithOptions(uiImage.size, false, 1.0)
    uiImage.draw(in: CGRect(origin: .zero, size: uiImage.size))
    let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
    UIGraphicsEndImageContext()
    return normalizedImage ?? cgImage
  }

  private func createBackgroundLayer(input: CIImage, targetSize: CGSize, mood: String) -> CIImage {
    // Scale to cover target size
    let scaleX = targetSize.width / input.extent.width
    let scaleY = targetSize.height / input.extent.height
    let bgScale = max(scaleX, scaleY)
    
    var bg = input.transformed(by: CGAffineTransform(scaleX: bgScale, y: bgScale))
    
    // Center crop to target extent
    let dX = (bg.extent.width - targetSize.width) / 2
    let dY = (bg.extent.height - targetSize.height) / 2
    bg = bg.cropped(to: CGRect(x: dX, y: dY, width: targetSize.width, height: targetSize.height))
    // Reset origin
    bg = bg.transformed(by: CGAffineTransform(translationX: -dX, y: -dY))

    // Heavy blur
    let blur = CIFilter.gaussianBlur()
    blur.inputImage = bg
    blur.radius = 40.0
    bg = blur.outputImage?.cropped(to: bg.extent) ?? bg

    // Darken and tint based on mood
    // Simplified color adjustment representation
    let colorMatrix = CIFilter.colorMatrix()
    colorMatrix.inputImage = bg
    
    // Darken mostly
    colorMatrix.rVector = CIVector(x: 0.5, y: 0, z: 0, w: 0)
    colorMatrix.gVector = CIVector(x: 0, y: 0.5, z: 0, w: 0)
    colorMatrix.bVector = CIVector(x: 0, y: 0, z: 0.8, w: 0) // slight blue tint
    colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
    
    return colorMatrix.outputImage ?? bg
  }

  private func createMainLayer(input: CIImage, targetSize: CGSize, tone: CGFloat) -> CIImage {
    // 9:16 aspect ratio center crop
    let inputAspect = input.extent.width / input.extent.height
    let targetAspect = 9.0 / 16.0
    
    var cropRect = input.extent
    if inputAspect > targetAspect {
      // Input is wider, crop sides
      let newWidth = input.extent.height * targetAspect
      cropRect.origin.x += (input.extent.width - newWidth) / 2
      cropRect.size.width = newWidth
    } else {
      // Input is taller, crop top/bottom
      let newHeight = input.extent.width / targetAspect
      cropRect.origin.y += (input.extent.height - newHeight) / 2
      cropRect.size.height = newHeight
    }
    
    var main = input.cropped(to: cropRect)
    
    // Scale to fill target
    let mainScale = targetSize.width / main.extent.width
    main = main.transformed(by: CGAffineTransform(scaleX: mainScale, y: mainScale))
    main = main.transformed(by: CGAffineTransform(translationX: -main.extent.origin.x, y: -main.extent.origin.y))
    
    // Apply Tone mapping (simple exposure / saturation adjustment for now)
    let controls = CIFilter.colorControls()
    controls.inputImage = main
    controls.saturation = 1.0 + Float((tone - 0.5) * 1.0) // Boost saturation slightly
    controls.contrast = 1.0 + Float((tone - 0.5) * 0.5) 
    
    return controls.outputImage ?? main
  }

  private func applyNeon(input: CIImage, neon: CGFloat) -> CIImage {
    let highlightBoost = CIFilter.colorControls()
    highlightBoost.inputImage = input
    highlightBoost.contrast = 1.0 + Float(neon * 2.0)
    highlightBoost.brightness = Float(neon * 0.5)
    
    let baseHighlight = highlightBoost.outputImage ?? input

    let blur = CIFilter.gaussianBlur()
    blur.inputImage = baseHighlight
    blur.radius = Float(10.0 + neon * 30.0)
    
    let blurredHighlight = blur.outputImage?.cropped(to: input.extent) ?? baseHighlight
    
    let addition = CIFilter.additionCompositing()
    addition.inputImage = blurredHighlight
    addition.backgroundImage = input
    
    return addition.outputImage ?? input
  }

  private func applyGrain(input: CIImage, grain: CGFloat) -> CIImage {
    if grain <= 0 { return input }
    
    let randomGenerator = CIFilter.randomGenerator()
    guard let noiseImage = randomGenerator.outputImage?.cropped(to: input.extent) else { return input }
    
    let noiseColor = CIFilter.colorMatrix()
    noiseColor.inputImage = noiseImage
    let alpha = CGFloat(grain * 0.2)
    noiseColor.rVector = CIVector(x: 0, y: 1, z: 0, w: 0)
    noiseColor.gVector = CIVector(x: 0, y: 1, z: 0, w: 0)
    noiseColor.bVector = CIVector(x: 0, y: 1, z: 0, w: 0)
    noiseColor.aVector = CIVector(x: 0, y: 0, z: 0, w: alpha)
    
    let adjustedNoise = noiseColor.outputImage ?? noiseImage
    
    let blend = CIFilter.sourceOverCompositing()
    blend.inputImage = adjustedNoise
    blend.backgroundImage = input
    
    return blend.outputImage ?? input
  }

  private func applyTitle(input: CIImage, title: String, targetSize: CGSize) -> CIImage {
    if title.isEmpty { return input }
    
    let w = targetSize.width
    let h = targetSize.height
    
    let fontSize = h * 0.065
    let x = w * 0.07
    let y = h * (1.0 - 0.78)

    var line1 = title
    var line2 = ""
    if title.contains(" ") {
      let parts = title.split(separator: " ", maxSplits: 1).map(String.init)
      line1 = parts[0]
      if parts.count > 1 { line2 = parts[1] }
    } else if title.count > 12 {
      let mid = title.index(title.startIndex, offsetBy: 12)
      line1 = String(title[..<mid])
      line2 = String(title[mid...])
    }
    let finalText = line2.isEmpty ? line1 : "\(line1)\n\(line2)"

    let font = UIFont(name: "AvenirNext-HeavyItalic", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize, weight: .heavy)
    let textColor = UIColor.white
    
    let shadow = NSShadow()
    shadow.shadowColor = UIColor(white: 1.0, alpha: 0.8)
    shadow.shadowBlurRadius = 8.0
    shadow.shadowOffset = .zero

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .left
    
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: textColor,
      .shadow: shadow,
      .paragraphStyle: paragraphStyle
    ]
    
    let attributedText = NSAttributedString(string: finalText, attributes: attributes)
    let textSize = attributedText.size()
    
    UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
    guard UIGraphicsGetCurrentContext() != nil else {
      UIGraphicsEndImageContext()
      return input
    }
    
    let drawY = h * 0.78 - textSize.height
    attributedText.draw(in: CGRect(x: x, y: drawY, width: w - x*2, height: textSize.height))
    
    guard let textCGImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage else {
      UIGraphicsEndImageContext()
      return input
    }
    UIGraphicsEndImageContext()
    
    let textCIImage = CIImage(cgImage: textCGImage)
    
    let blend = CIFilter.sourceOverCompositing()
    blend.inputImage = textCIImage
    blend.backgroundImage = input
    
    return blend.outputImage ?? input
  }
}

// Struct matching JS arguments
struct ProcessArgs: Record {
  @Field var inputUri: String
  @Field var outputUri: String
  @Field var mood: String
  @Field var neon: Double
  @Field var tone: Double
  @Field var grain: Double
  @Field var title: String
  @Field var targetWidth: Int
  @Field var targetHeight: Int
  @Field var jpegQuality: Double
}
