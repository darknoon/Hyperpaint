//
//  Paint.swift
//  Hyperpaint
//
//  Created by Andrew Pouliot on 12/3/22.
//

import CoreGraphics
import CoreML
import Foundation
//import StableDiffusion
import UniformTypeIdentifiers

func log(_ str: String, term: String = "") {
  print(str, terminator: term)
}

let disableSafety = true
enum RunError: Error {
  case resources(String)
  case saving(String)
}

class Paint {

  var pipeline: StableDiffusionPipeline

  init(resourceURL: URL) throws {
    guard FileManager.default.fileExists(atPath: resourceURL.path) else {
      throw RunError.resources("Resource path does not exist \(resourceURL)")
    }

    let config = MLModelConfiguration()
    config.computeUnits = .all

    log("Creating pipeline...")
    pipeline = try StableDiffusionPipeline(
      resourcesAt: resourceURL,
      configuration: config,
      disableSafety: disableSafety
    )
    log("Created pipeline!")
  }

  let saveEvery = 0

  func handleProgress(
    _ progress: StableDiffusionPipeline.Progress,
    _ sampleTimer: SampleTimer
  ) {
    log("\u{1B}[1A\u{1B}[K")
    log("Step \(progress.step) of \(progress.stepCount) ")
    log(" [")
    log(String(format: "mean: %.2f, ", 1.0 / sampleTimer.mean))
    log(String(format: "median: %.2f, ", 1.0 / sampleTimer.median))
    log(String(format: "last %.2f", 1.0 / sampleTimer.allSamples.last!))
    log("] step/sec")

    log("\n")
  }

  func generate(
    prompt: String,
    imageCount: Int,
    stepCount: Int,
    guidanceScale: Float,
    seed: Int,
    progressHandler: @escaping (StableDiffusionPipeline.Progress) -> Void
  ) async throws -> [CGImage?] {
    log("Starting...")
    let t = Task(priority: .userInitiated) {

      // Create a task to run the pipeline
      log("Sampling ...\n")
      let sampleTimer = SampleTimer()
      sampleTimer.start()

      pipeline.guidanceScale = guidanceScale
      let images = try pipeline.generateImages(
        prompt: prompt,
        imageCount: imageCount,
        stepCount: stepCount,
        seed: seed
      ) { progress in
        sampleTimer.stop()
        handleProgress(progress, sampleTimer)
        progressHandler(progress)
        if progress.stepCount != progress.step {
          sampleTimer.start()
        }
        return true
      }
      return images
    }
    return try await t.value
  }
}
