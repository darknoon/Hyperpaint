//
//  ContentView.swift
//  Hyperpaint
//
//  Created by Andrew Pouliot on 12/3/22.
//

import SwiftUI

enum Status {
  case idle
  case compiling
  case running
}

struct ContentView: View {
  @State var text: String = "an ios icon of a paintbrush"
  @State var error: Error? = nil
  @State var painter: Paint? = nil
  @State var status: Status = .idle
  @State var image: CGImage? = nil
  @State var painting: Bool = false
  @State var progress: StableDiffusionPipeline.Progress? = nil
  @State var checkpoint: URL? = Bundle.main.url(
    forResource: "coreml-stable-diffusion-v1-4_original_compiled",
    withExtension: nil
  )

  // Settings
  @State var steps: Float = 10
  @State var guidanceScale: Float = 7
  @State var seed: Int = 42

  var body: some View {
    VStack {
      HStack {
        TextField("Prompt", text: $text).onSubmit {
          runModel()
        }
        Button("Sample", action: runModel).disabled(painting)
      }
      DisclosureGroup("Settings") {
        VStack(alignment: .leading) {
          // Labeled sliders
          HStack {
            Text("Steps").frame(width: 100)
            Slider(value: $steps, in: 1...100)
            TextField("", value: $steps, formatter: NumberFormatter()).frame(width: 50)
          }
          HStack {
            Text("Guidance Scale").frame(width: 100)
            Slider(value: $guidanceScale, in: 1...10)
            TextField("", value: $guidanceScale, formatter: NumberFormatter()).frame(width: 50)
          }
          // Seed
          HStack {
            Text("Seed").frame(width: 100)
            TextField("Seed", value: $seed, formatter: NumberFormatter()).frame(width: 50)
          }
        }
        .padding()
        .disabled(painting)
      }
      if let progress = progress {
        ProgressView(value: Float(progress.step), total: Float(progress.stepCount))
      }
      if let image = image {
        Image(decorative: image, scale: 1)
      }
    }
    .padding()
  }

  func updateProgress(_ p: StableDiffusionPipeline.Progress) {
    // Run on main task
    DispatchQueue.main.async {
      progress = p
      // only every n for speed
      if p.step % 3 == 0 {
        image = p.currentImages.first ?? nil
      }
    }
  }

  func runModel() {
    Task {
      guard let checkpoint = checkpoint else {
        error = RunError.resources("Couldn't find checkpoint")
        return
      }
      painting = true
      if painter == nil {
        status = .compiling
        painter = try? Paint(resourceURL: checkpoint)
      }
      status = .running
      let images = try await painter?.generate(
        prompt: text,
        imageCount: 1,
        stepCount: Int(steps),
        guidanceScale: guidanceScale,
        seed: seed,
        progressHandler: updateProgress
      )
      status = .idle
      image = images?.first ?? nil
      painting = false
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .previewDevice("iPad Pro (12.9-inch) (5th generation)")
  }
}
