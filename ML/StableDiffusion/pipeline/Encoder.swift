import Accelerate
import Accelerate.vImage
import CoreGraphics
import CoreML
// For licensing see accompanying LICENSE.md file.
// Copyright (C) 2022 Apple Inc. All Rights Reserved.
import Foundation

enum EncoderError: Error {
  case imageResizeFailure
  case imageToFloatFailure
  case modelInputFailure
  case unexpectedModelOutput
}

/// A model which encodes images into latent space
public struct Encoder {

  /// Image encoder model
  var model: MLModel

  /// Create encoder from Core ML model
  ///
  /// - Parameters:
  ///   - model: Core ML model for image encoder
  public init(model: MLModel) {
    self.model = model
  }

  /// Prediction queue
  let queue = DispatchQueue(label: "encoder.predict")

  typealias PixelBufferPFx1 = vImage.PixelBuffer<vImage.PlanarF>
  typealias PixelBufferP8x3 = vImage.PixelBuffer<vImage.Planar8x3>
  typealias PixelBufferIFx3 = vImage.PixelBuffer<vImage.InterleavedFx3>
  typealias PixelBufferI8x3 = vImage.PixelBuffer<vImage.Interleaved8x3>
  typealias PixelBufferI8x4 = vImage.PixelBuffer<vImage.Interleaved8x4>

  func getRGBPlanes(of rgbaImage: CGImage) throws -> PixelBufferP8x3 {
    // Reference as interleaved 8 bit vImage PixelBuffer
    var emptyFormat = vImage_CGImageFormat()
    guard
      let bufferI8x4 = try? PixelBufferI8x4(
        cgImage: rgbaImage,
        cgImageFormat: &emptyFormat
      )
    else {
      throw EncoderError.imageToFloatFailure
    }

    // Drop the alpha channel, keeping RGB
    let bufferI8x3 = PixelBufferI8x3(width: rgbaImage.width, height: rgbaImage.height)
    bufferI8x4.convert(to: bufferI8x3, channelOrdering: .RGBA)

    // De-interleave into 8-bit planes
    return PixelBufferP8x3(interleavedBuffer: bufferI8x3)
  }

  func normalizeToFloatShapedArray(_ bufferP8x3: PixelBufferP8x3) -> MLShapedArray<Float32> {
    let width = bufferP8x3.width
    let height = bufferP8x3.height

    let means = [0.485, 0.456, 0.406] as [Float]
    let stds = [0.229, 0.224, 0.225] as [Float]

    // Convert to normalized float 1x3xWxH input (plannar)
    let arrayPFx3 = MLShapedArray<Float32>(repeating: 0.0, shape: [1, 3, width, height])
    for c in 0..<3 {
      arrayPFx3[0][c].withUnsafeShapedBufferPointer { ptr, _, strides in
        let floatChannel = PixelBufferPFx1(
          data: .init(mutating: ptr.baseAddress!),
          width: width,
          height: height,
          byteCountPerRow: strides[0] * 4
        )

        bufferP8x3.withUnsafePixelBuffer(at: c) { uint8Channel in
          uint8Channel.convert(to: floatChannel)  // maps [0 255] -> [0 1]
          floatChannel.multiply(
            by: 1.0 / stds[c],
            preBias: -means[c],
            postBias: 0.0,
            destination: floatChannel
          )
        }
      }
    }
    return arrayPFx3
  }

  func resizeToRGBA(
    _ image: CGImage,
    width: Int,
    height: Int
  ) throws -> CGImage {

    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
      )
    else {
      throw EncoderError.imageResizeFailure
    }

    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let resizedImage = context.makeImage() else {
      throw EncoderError.imageResizeFailure
    }

    return resizedImage
  }

  /// Encode image
  ///
  /// - Parameters:
  ///   - image: Input image
  /// - Returns: Encoded latent representation of the input image
  public func encode(_ image: CGImage) throws -> DiagonalGaussianDistribution {

    let inputInfo = model.modelDescription.inputDescriptionsByName
    let inputShape = inputInfo[inputName]!.multiArrayConstraint!.shape

    let width = inputShape[2].intValue
    let height = inputShape[3].intValue

    let resizedImage = try resizeToRGBA(image, width: width, height: height)

    let bufferP8x3 = try getRGBPlanes(of: resizedImage)

    let arrayPFx3 = normalizeToFloatShapedArray(bufferP8x3)

    guard
      let input = try? MLDictionaryFeatureProvider(
        dictionary: [
          // Input that is analyzed for safety
          inputName: MLMultiArray(arrayPFx3)
        ]
      )
    else {
      throw EncoderError.modelInputFailure
    }

    let outputs = try queue.sync { try model.prediction(from: input) }

    // Extract the latent distribution from the model's output and sample from it
    let outputName = outputs.featureNames.first!
    let output = outputs.featureValue(for: outputName)!.multiArrayValue!
    return DiagonalGaussianDistribution(parameters: MLShapedArray<Double>(converting: output))
  }

  var inputName: String {
    model.modelDescription.inputDescriptionsByName.first!.key
  }

}
