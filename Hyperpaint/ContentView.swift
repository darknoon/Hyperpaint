// Hyperpaint
// Created by Andrew Pouliot on 12/3/22.

import SwiftUI
import UniformTypeIdentifiers

enum Status {
  case idle
  case compiling(start: Date)
  case running
  case displaying
}

let modelName = "coreml-stable-diffusion-v1-4_original_compiled"
//let modelName = "coreml-stable-diffusion-2-base_original_compiled"

struct ContentView: View {
  // Inputs
  @State var textInput: String = "an ios icon of a paintbrush"
  @State var imageInput: CGImage? = nil

  @State var error: Error? = nil
  @State var painter: Paint? = nil
  @State var status: Status = .idle
  @State var image: CGImage? = nil
  @State var painting: Bool = false
  @State var progress: StableDiffusionPipeline.Progress? = nil
  @State var checkpoint: URL? = Bundle.main.url(
    forResource: modelName,
    withExtension: nil
  )

  // Settings
  @State var steps: Float = 10
  @State var guidanceScale: Float = 7
  @State var seed: Int = 42
  @State var displayEvery: Int = 3
  @State var makeVariations: Bool = false

  func randomizeSeed() {
    seed = Int.random(in: 0...100)
  }

  @State private var numberFormatter: NumberFormatter = {
    var nf = NumberFormatter()
    nf.numberStyle = .decimal
    nf.minimumFractionDigits = 1
    nf.maximumFractionDigits = 1
    return nf
  }()

  var appName: String {
    Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Hyperpaint"
  }

  var settings: some View {
    VStack(alignment: .leading) {
      // Labeled sliders
      HStack {
        Text("Steps")
          .frame(width: 100, alignment: .trailing)
        Slider(value: $steps, in: 1...100)
        TextField("", value: $steps, formatter: NumberFormatter()).frame(width: 50)
      }
      HStack {
        Text("Guidance Scale")
          .frame(width: 100, alignment: .trailing)
        Slider(value: $guidanceScale, in: 1.0...20.0)
        TextField("", value: $guidanceScale, formatter: numberFormatter).frame(width: 50)
      }
      // Seed
      HStack {
        Text("Seed")
          .frame(width: 100, alignment: .trailing)
        TextField("Seed", value: $seed, formatter: NumberFormatter()).frame(width: 50)
        Button(action: randomizeSeed) {
          Label("Randomize", systemImage: "dice.fill")
            .labelStyle(IconOnlyLabelStyle())
        }
      }
      HStack {
        Text("Variations")
          .frame(width: 100, alignment: .trailing)
        Toggle("Variations", isOn: $makeVariations)
      }
    }
  }

  var body: some View {

    return VStack {
      HStack {
        TextField("Prompt", text: $textInput).onSubmit {
          runModel()
        }
        // Image input
        Button(action: {
          let picker = NSOpenPanel()
          // 'allowedFileTypes' was deprecated in macOS 12.0
          // picker.allowedFileTypes = ["png", "jpg", "jpeg"]
          picker.allowedContentTypes = [UTType.png, UTType.jpeg]
          picker.allowsMultipleSelection = false
          picker.begin { result in
            if result == .OK, let url = picker.url {
              imageInput = NSImage(contentsOf: url)?.cgImage(
                forProposedRect: nil,
                context: nil,
                hints: nil
              )
            }
          }
        }) {
          Label("Image", systemImage: "photo")
        }
        Button("Sample", action: runModel).disabled(painting)
      }
      DisclosureGroup("Settings") {
        settings
          .padding()
          .disabled(painting)
      }
      HStack {
        // Show progress
        if let progress = progress {
          ProgressView(value: Float(progress.step), total: Float(progress.stepCount))
        }
        // Show error
        if let error = error {
          Text(error.localizedDescription)
        }
        // Show status
        Group {
          switch status {
          case .idle:
            Text("Idle")
          case .compiling(let start):
            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
              // If it's been a long time
              let t = timeline.date.timeIntervalSince(start)
              if t > 2.0 {
                Text("Compiling…")
                Text("This may take up to a few minutes the first time you run \(appName)")
                Text("Waited \(t.formatted(.number.precision(.fractionLength(0))))s")
              }
              else {
                // Make sure that we re-render periodically to make sure that we can show the "this may take a few minutes" message
                Text("Compiling…")
              }
            }
          case .running:
            Text("Running")
          case .displaying:
            Text("Displaying")
          }
        }
        .frame(width: 90)
      }
      if let image = image {
        Image(decorative: image, scale: 1)
      } else if let image = imageInput {
        Image(decorative: image, scale: 1)
      } else {
        Color.black.frame(width: 512, height: 512)
      }

    }
    .padding()
  }

  func updateProgress(_ p: StableDiffusionPipeline.Progress) {
    // Run on main task
    DispatchQueue.main.async {
      progress = p
      // only every n for speed
      if p.step % displayEvery == 0 {
        status = .displaying
        Task(priority: .medium) {
          image = p.currentImages.first ?? nil
          DispatchQueue.main.async {
            status = .running
          }
        }
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
        status = .compiling(start: Date.now)
        painter = try? Paint(resourceURL: checkpoint)
      }
      status = .running
      let images = try await painter?.generate(
        prompt: textInput,
        image: imageInput,
        makeVariations: makeVariations,
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
