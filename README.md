### Model Downloading and Setup Directions

https://huggingface.co/blog/diffusers-coreml

### Goals

This is a really wip thing but the eventual goal is to create an AI-enabled painting app once the model is working well enough

- [ ] Stable-diffusion-based model
  - [x] CoreML model for running on device
  - [ ] Allow taking an image as input, and encoding it to latents (wip see image2image branch )
  - [ ] Support more recent models (sd 1.5, 2.0)
  - [ ] Support fine-tunes downloaded from the internet
- [ ] freeform infinite canvas
  - [ ] paint on ipad with Pencil (prototype using PencilKit)
  - [ ] automatically run model interactively while painting

### Current Status

- Runs on mac, struggles on iPad Pro w/ M1
- Img2img branch has a working image2image model, but the pipeline needs tweaking to work
- No drawable canvas yet
- Can't pick images on iPad

### Contributing

- If you want to help, happy to chat. @andpoul on twitter
- May accept PRs if I have time, but this is solidly a side project

thanks :)
