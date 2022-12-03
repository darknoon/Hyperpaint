//
//  ContentView.swift
//  Hyperpaint
//
//  Created by Andrew Pouliot on 12/3/22.
//

import SwiftUI

struct ContentView: View {
    @State var text: String = "an ios icon of a paintbrush"
    
    @State var painter: Paint? = nil
    
    @State var image: CGImage? = nil

    @State var painting: Bool = false

    @State var progress: StableDiffusionPipeline.Progress? = nil

    
    var body: some View {
        VStack {
            TextField("Prompt", text: $text).onSubmit {
                runModel()
            }
            Button("Sample", action: runModel).disabled(painting)
            if let progress = progress {
                ProgressView(value: Float(progress.step), total: Float(progress.stepCount))
            }
            if let image {
                Image(decorative: image, scale: 1)
            }
        }
        .padding()
    }
    
    func updateProgress(_ p: StableDiffusionPipeline.Progress) {
        // Run on main task
        DispatchQueue.main.async {
            progress = p
        }
    }
    
    func runModel() {
        Task {
            painting = true
            if (painter == nil) {
                painter = try? Paint()
            }
            let images = try await painter?.generate(prompt: text, imageCount: 1, stepCount: 4, seed: 42, progressHandler: updateProgress)
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
