import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import ExpoModulesCore
import CoreML
import Vision

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
    
    // Generate output URL natively
    let filename = "citypop_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

    // Ensure input is file URL for Data operations
    guard inputURL.isFileURL else {
      throw NSError(domain: "CityPop", code: 1, userInfo: [NSLocalizedDescriptionKey: "Input URI must be a file URL"])
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
    
    // 2. Crop input to target aspect ratio before AI processing
    let preCropped = formatMainLayer(input: ciInputImage, targetSize: targetSize)
    
    // 3. AI Illustration Processing (Core ML)
    let illustratedImage = try runCoreMLIllustrationModel(input: preCropped)
    
    // 4. Ensure AI Output is scaled back to Target Size (as models often resize to 512x512 etc.)
    var mainImage = formatMainLayer(input: illustratedImage, targetSize: targetSize)
    
    // 5. Apply City Pop Tone
    mainImage = applyCityPopToneMapping(input: mainImage, tone: CGFloat(args.tone), mood: args.mood)
    
    // 6. Apply Neon Glow
    mainImage = applyNeon(input: mainImage, neon: CGFloat(args.neon))

    // Composite Over Background
    guard let compositeFilter = CIFilter(name: "CISourceOverCompositing") else {
      throw NSError(domain: "CityPop", code: 3, userInfo: [NSLocalizedDescriptionKey: "Filter failed"])
    }
    compositeFilter.setValue(mainImage, forKey: kCIInputImageKey)
    compositeFilter.setValue(bgImage, forKey: kCIInputBackgroundImageKey)
    
    var finalCImage = compositeFilter.outputImage ?? bgImage

    // 7. Apply Grain
    finalCImage = applyGrain(input: finalCImage, grain: CGFloat(args.grain))

    // 8. Apply Title
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

  private func formatMainLayer(input: CIImage, targetSize: CGSize) -> CIImage {
    // 9:16 aspect ratio center crop
    let inputAspect = input.extent.width / input.extent.height
    let targetAspect = 9.0 / 16.0
    
    var cropRect = input.extent
    if inputAspect > targetAspect {
      let newWidth = input.extent.height * targetAspect
      cropRect.origin.x += (input.extent.width - newWidth) / 2
      cropRect.size.width = newWidth
    } else {
      let newHeight = input.extent.width / targetAspect
      cropRect.origin.y += (input.extent.height - newHeight) / 2
      cropRect.size.height = newHeight
    }
    
    var main = input.cropped(to: cropRect)
    
    // Scale to fill target
    let mainScale = targetSize.width / main.extent.width
    main = main.transformed(by: CGAffineTransform(scaleX: mainScale, y: mainScale))
    main = main.transformed(by: CGAffineTransform(translationX: -main.extent.origin.x, y: -main.extent.origin.y))
    return main
  }

  private func runCoreMLIllustrationModel(input: CIImage) throws -> CIImage {
    var modelURL: URL? = nil
    
    // Check main app bundle
    if let url = Bundle.main.url(forResource: "IllustrationAI", withExtension: "mlmodelc") {
        modelURL = url
    } 
    // Check module bundle
    else if let bundle = Bundle(identifier: "org.cocoapods.city-pop-processor") ?? Bundle(for: type(of: self)),
            let url = bundle.url(forResource: "IllustrationAI", withExtension: "mlmodelc") {
        modelURL = url
    }

    guard let finalURL = modelURL else {
        throw NSError(domain: "CityPop", code: 10, userInfo: [NSLocalizedDescriptionKey: "[USER_ACTION_REQUIRED] AI Model 'IllustrationAI.mlmodelc' not found. Please follow instructions in scripts/setup_model.js to download an illustration CoreML model and place it in the ios directory."])
    }

    let mlModel = try MLModel(contentsOf: finalURL)
    let visionModel = try VNCoreMLModel(for: mlModel)

    var resultImage: CIImage?
    let request = VNCoreMLRequest(model: visionModel) { request, error in
        if let results = request.results as? [VNPixelBufferObservation], let pixelBuffer = results.first?.pixelBuffer {
            resultImage = CIImage(cvPixelBuffer: pixelBuffer)
        } else if let featureResults = request.results as? [VNCoreMLFeatureValueObservation],
                  let pixelBuffer = featureResults.first?.featureValue.imageBufferValue {
            resultImage = CIImage(cvPixelBuffer: pixelBuffer)
        }
    }
    
    request.imageCropAndScaleOption = .scaleFill
    
    let context = CIContext(options: nil)
    guard let cgImage = context.createCGImage(input, from: input.extent) else { return input }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])
    
    return resultImage ?? input
  }

  private func applyCityPopToneMapping(input: CIImage, tone: CGFloat, mood: String) -> CIImage {
    var main = input
    
    // --- City Pop Tone Mapping ---
    let finalControls = CIFilter.colorControls()
    finalControls.inputImage = main
    finalControls.saturation = 1.1 + Float((tone - 0.5) * 1.0)
    finalControls.contrast = 1.0 + Float((tone - 0.5) * 0.3)
    finalControls.brightness = 0.05
    main = finalControls.outputImage ?? main

    // --- Shift colors toward Retro City Pop tones ---
    let matrix = CIFilter.colorMatrix()
    matrix.inputImage = main
    
    switch mood.lowercased() {
    case "night":
        // Cool blue/purple emphasis
        matrix.rVector = CIVector(x: 0.9, y: 0.0, z: 0.15, w: 0.0)
        matrix.gVector = CIVector(x: 0.0, y: 0.9, z: 0.15, w: 0.0)
        matrix.bVector = CIVector(x: 0.0, y: 0.1, z: 1.15, w: 0.0)
    case "sunset":
        // Warm orange/red emphasis
        matrix.rVector = CIVector(x: 1.15, y: 0.1, z: 0.0, w: 0.0)
        matrix.gVector = CIVector(x: 0.1, y: 0.95, z: 0.0, w: 0.0)
        matrix.bVector = CIVector(x: 0.0, y: 0.0, z: 0.9, w: 0.0)
    case "afterglow":
        // Pinkish neon vaporwave feel
        matrix.rVector = CIVector(x: 1.1, y: 0.0, z: 0.15, w: 0.0)
        matrix.gVector = CIVector(x: 0.0, y: 0.95, z: 0.1, w: 0.0)
        matrix.bVector = CIVector(x: 0.1, y: 0.1, z: 1.1, w: 0.0)
    default:
        matrix.rVector = CIVector(x: 1.05, y: 0.0, z: 0.0, w: 0.0)
        matrix.gVector = CIVector(x: 0.0, y: 1.05, z: 0.0, w: 0.0)
        matrix.bVector = CIVector(x: 0.0, y: 0.0, z: 1.05, w: 0.0)
    }
    matrix.aVector = CIVector(x: 0.0, y: 0.0, z: 0.0, w: 1.0)
    main = matrix.outputImage ?? main
    
    return main
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
