## FileLogger

import os
import json
import utils # Import the loading bar
import viewerhtml

type
  J_Thing = object of RootObj
    name: string
    size: BiggestInt
  J_File = object of J_Thing
    ext: string
  J_Folder = object of J_Thing
    folders: seq[J_Folder]
    files: seq[J_File]

var log_thread: Thread[string] # An asyncronus loading bar
var log_chan: Channel[BiggestInt] # Channel to send completed file sizes
const n_steps = 20 # Number of steps in the bar

proc log_loop(dir: string) {.thread.} = # The thread loop
  var total_size, completed: BiggestInt
  var percent: float

  echo "Calculating Size..."
  for file in walkDirRec(dir): # Calculates size asyncronusly so for small folders the main loop isn't bogged down
    try:
      total_size += file.getFileSize()
    except OSError as e:
      echo file
  while completed < total_size:
    let msg = log_chan.recv()
    if msg < 0: break # If it gets a negative number break the loop

    completed += msg
    percent = completed.float() / total_size.float()
    show_loading_bar(percent, n_steps) # Show the loading bar

# Converts the provided dir into a J_Folder
proc get_folder(dir: string): J_Folder =
  result = J_Folder(name:lastPathPart(dir)) # Make a new J_Folder object
  for kind, path in walkDir(dir): # For every file and folder in the dir
    if isHidden(path): continue # Ignore hidden stuff
    case kind:
      of pcDir: # If its a dir
        let subdir = get_folder(path) # Recursively turn it into a J_Folder
        result.folders.add(subdir) # Add it to the folders seq
        result.size += subdir.size # Track its size
        log_chan.send(subdir.size)
      of pcFile: # If its a file
        let (dir, name, ext) = splitFile(path) # Get its name and extension
        var size: BiggestInt
        try:
          size = getFileSize(path) # Get its size
        except OSError as e:
          size = 0
        result.files.add(J_File(name:name, ext:ext, size:size)) # Convert it to a J_File and add it to the seq
        result.size += size # Track its size
        log_chan.send(size)
      else: discard # Don't worry about symblinks and stuff

# Saves the provided J_Folder to JSON. Conversion is done with ``%*``
proc save_as_json(folder: J_Folder; pretty = true) =
  if (pretty): writeFile(folder.name & "_data.json", (%*folder).pretty())
  else: writeFile(folder.name & "_data.json", $(%*folder))
  writeViewer("data_visualizer", $(%*folder))

when isMainModule:
  let current_dir = getCurrentDir() # The directory the compiled binary is in
  try:
    log_chan.open() # Open the channel
    createThread(log_thread, log_loop, current_dir) # Create the loading bar thread
    current_dir.get_folder().save_as_json() # Begin the file logging
  except CatchableError as e:
    echo e.msg
  finally: # When it's done or it errors out
    stdout.flushFile() # Flush all prints to the terminal
    log_chan.send(-1) # close the loading bar thread
    log_chan.close() # Close the channel
  show_loading_bar(1.0, n_steps) # It's done! Show a 100% done loading bar only if it completed with no errors