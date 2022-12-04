//
//  DiagonalGaussianDistribution.swift
//  Hyperpaint
//
//  Created by Andrew Pouliot on 12/4/22.
//

import Foundation
import CoreML

public struct DiagonalGaussianDistribution {
//  let parameters: MLShapedArray<Double>
  let mean: MLShapedArraySlice<Double>
let logvar: MLShapedArraySlice<Double>
//  let deterministic: Bool
//  let std: MLShapedArray<Double>
//  let `var`: MLShapedArray<Double>
  
  init(parameters: MLShapedArray<Double>, deterministic: Bool = false) {
//    self.parameters = parameters
    self.mean = parameters[[0..<1, 0..<4]]
    self.logvar = parameters[[0..<1, 4..<8]]
//    self.logvar = max(min(self.logvar, -30.0), 20.0)
//    self.deterministic = deterministic
//    self.std = exp(0.5 * self.logvar)
//    self.var = exp(self.logvar)
//    if self.deterministic {
//      self.var = self.std = MLShapedArray<Double>(zerosLike: self.mean, device: self.parameters.device, dtype: self.parameters.dtype)
//    }
  }
  

  func sample(generator: NumPyRandomSource? = nil) -> MLShapedArray<Double> {
    return mode()
  }

  
//  func sample(generator: NumPyRandomSource? = nil) -> MLShapedArray<Double> {
//    var sample: MLShapedArray<Double>
//    if let generator = generator {
//      sample = generator.normal(loc: 0, scale: 1, size: self.mean.shape)
//    } else {
//      let generator = NumPyRandomSource(seed: 0)
//      sample = generator.normal(loc: 0, scale: 1, size: self.mean.shape)
//    }
//    sample = sample.astype(self.parameters.dtype)
//    let x = self.mean.add(self.std.mul(sample))
//    return x
//  }
//
//  func kl(other: DiagonalGaussianDistribution? = nil) -> MLShapedArray<Double> {
//    if self.deterministic {
//      return MLShapedArray<Double>([0.0])
//    } else {
//      if let other = other {
//        return 0.5 * (
//          (self.mean.sub(other.mean).pow(2)).div(other.var)
//          + self.var.div(other.var)
//          - 1.0
//          - self.logvar
//          + other.logvar
//        ).sum(dim: [1, 2, 3])
//      } else {
//        return 0.5 * (self.mean.pow(2) + self.var - 1.0 - self.logvar).sum(dim: [1, 2, 3])
//      }
//    }
//  }
//
//  func nll(sample: MLShapedArray<Double>, dims: [Int] = [1, 2, 3]) -> MLShapedArray<Double> {
//    if self.deterministic {
//      return MLShapedArray<Double>([0.0])
//    }
//    let logtwopi = log(2.0 * Double.pi)
//    return 0.5 * (logtwopi + self.logvar + (sample.sub(self.mean)).pow(2).div(self.var)).sum(dim: dims)
//  }
//
  func mode() -> MLShapedArray<Double> {
    return MLShapedArray(converting: self.mean)
  }
}
