This code is adapted from https://github.com/apple/ml-stable-diffusion

### Notes

Hidden state is

```
(lldb) po hiddenStates.shape
▿ 4 elements
  - 0 : 2
  - 1 : 768
  - 2 : 1
  - 3 : 77
```

ie `2*768*1*77` = `118272` hidden states, ie 473KB

Latent state is

```
(lldb) po latents[0].shape
▿ 4 elements
  - 0 : 1
  - 1 : 4
  - 2 : 64
  - 3 : 64
```

ie `1*4*64*64` = `16384` latent states, ie 64KB
