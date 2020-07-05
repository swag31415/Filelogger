## Utils

import strformat

## Shows a loading bar in the format
## Loading [##########] XX.XXX%
proc show_loading_bar*(percent: float; n_steps: int) =
  let bars = int(percent * float(n_steps)) # Calculate the number of bars
  stdout.write("\rLogging [")
  for i in 0..<n_steps:
    stdout.write(if i < bars: '#' else: ' ')
  stdout.write(&"] {100 * percent:.3f}%")