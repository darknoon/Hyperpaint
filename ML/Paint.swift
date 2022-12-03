//
//  Paint.swift
//  Hyperpaint
//
//  Created by Andrew Pouliot on 12/3/22.
//

import Foundation
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
    
    let pipeline: StableDiffusionPipeline
    
    init() throws {
        let resourcePath = Bundle.main.path(forResource: "coreml-stable-diffusion-v1-4_original_compiled", ofType: nil)!
        guard FileManager.default.fileExists(atPath: resourcePath) else {
            throw RunError.resources("Resource path does not exist \(resourcePath)")
        }
        
        let config = MLModelConfiguration()
        config.computeUnits = .all
        let resourceURL = URL(filePath: resourcePath)

        log("Creating pipeline...")
        pipeline = try StableDiffusionPipeline(resourcesAt: resourceURL,
                                               configuration: config,
                                               disableSafety: disableSafety)
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
        log(String(format: "mean: %.2f, ", 1.0/sampleTimer.mean))
        log(String(format: "median: %.2f, ", 1.0/sampleTimer.median))
        log(String(format: "last %.2f", 1.0/sampleTimer.allSamples.last!))
        log("] step/sec")

//        if saveEvery > 0, progress.step % saveEvery == 0 {
//            let saveCount = (try? saveImages(progress.currentImages, step: progress.step)) ?? 0
//            log(" saved \(saveCount) image\(saveCount != 1 ? "s" : "")")
//        }
        log("\n")
    }

    func generate(prompt: String, imageCount: Int, stepCount: Int, seed: Int, progressHandler: @escaping (StableDiffusionPipeline.Progress) -> Void) async throws -> [CGImage?] {
        log("Starting...")
        let t = Task(priority: .userInitiated) {
            // Create a task to run the pipeline
            log("Sampling ...\n")
            let sampleTimer = SampleTimer()
            sampleTimer.start()
            
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
